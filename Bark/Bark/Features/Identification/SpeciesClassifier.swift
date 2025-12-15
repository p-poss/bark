import CoreML
import Vision
import CoreImage

/// Wrapper for Core ML species classification model
final class SpeciesClassifier {
    private var classificationRequest: VNCoreMLRequest?
    private var isModelLoaded = false

    init() {
        loadModel()
    }

    // MARK: - Public Methods

    /// Classifies tree species from a bark image
    /// - Parameter image: CGImage of bark
    /// - Returns: Classification result with species and confidence
    func classify(image: CGImage) async throws -> ClassificationResult {
        // If no ML model is available, return a mock result for development
        guard isModelLoaded, let request = classificationRequest else {
            return mockClassification()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])

                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: ClassificationError.noResults)
                    return
                }

                let species = speciesFromIdentifier(topResult.identifier)
                let alternatives = results.dropFirst().prefix(3).map { observation in
                    (speciesFromIdentifier(observation.identifier), Double(observation.confidence))
                }

                let result = ClassificationResult(
                    species: species,
                    confidence: Double(topResult.confidence),
                    alternatives: alternatives
                )

                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: ClassificationError.classificationFailed)
            }
        }
    }

    /// Classifies species from a pixel buffer
    func classify(pixelBuffer: CVPixelBuffer) async throws -> ClassificationResult {
        guard isModelLoaded, let request = classificationRequest else {
            return mockClassification()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

            do {
                try handler.perform([request])

                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: ClassificationError.noResults)
                    return
                }

                let species = speciesFromIdentifier(topResult.identifier)
                let alternatives = results.dropFirst().prefix(3).map { observation in
                    (speciesFromIdentifier(observation.identifier), Double(observation.confidence))
                }

                let result = ClassificationResult(
                    species: species,
                    confidence: Double(topResult.confidence),
                    alternatives: alternatives
                )

                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: ClassificationError.classificationFailed)
            }
        }
    }

    // MARK: - Private Methods

    private func loadModel() {
        // Attempt to load the ML model
        // In production, this would load BarkClassifier.mlmodel
        // For now, we'll set up the request structure

        // Try to load a bundled model
        if let modelURL = Bundle.main.url(forResource: "BarkClassifier", withExtension: "mlmodelc") {
            do {
                let model = try MLModel(contentsOf: modelURL)
                let visionModel = try VNCoreMLModel(for: model)

                classificationRequest = VNCoreMLRequest(model: visionModel) { request, error in
                    if let error = error {
                        print("Classification error: \(error)")
                    }
                }

                classificationRequest?.imageCropAndScaleOption = .centerCrop
                isModelLoaded = true
            } catch {
                print("Failed to load ML model: \(error)")
                isModelLoaded = false
            }
        } else {
            print("BarkClassifier model not found - using mock classifications")
            isModelLoaded = false
        }
    }

    private func speciesFromIdentifier(_ identifier: String) -> Species {
        // Map model output identifiers to Species enum
        let mapping: [String: Species] = [
            "oak": .oak,
            "english_oak": .oak,
            "beech": .beech,
            "european_beech": .beech,
            "ash": .ash,
            "common_ash": .ash,
            "sycamore": .sycamore,
            "hornbeam": .hornbeam,
            "sweet_chestnut": .sweetChestnut,
            "horse_chestnut": .horseChestnut,
            "silver_birch": .silverBirch,
            "birch": .silverBirch,
            "alder": .alder,
            "willow": .willow,
            "poplar": .poplar,
            "lime": .lime,
            "field_maple": .fieldMaple,
            "wild_cherry": .wildCherry,
            "cherry": .wildCherry,
            "rowan": .rowan,
            "scots_pine": .scotsPine,
            "pine": .scotsPine,
            "yew": .yew,
            "larch": .larch,
            "douglas_fir": .douglasFir,
            "norway_spruce": .norwaySpruce,
            "spruce": .norwaySpruce
        ]

        let lowercased = identifier.lowercased().replacingOccurrences(of: " ", with: "_")

        if let species = mapping[lowercased] {
            return species
        }

        // Determine if unknown broadleaf or conifer based on identifier
        if lowercased.contains("pine") || lowercased.contains("fir") ||
           lowercased.contains("spruce") || lowercased.contains("cedar") {
            return .unknownConifer
        }

        return .unknownBroadleaf
    }

    /// Returns a mock classification for development/testing
    private func mockClassification() -> ClassificationResult {
        // Rotate through different species for testing
        let allSpecies: [Species] = [.oak, .silverBirch, .scotsPine, .beech, .yew]
        let randomIndex = Int.random(in: 0..<allSpecies.count)
        let primary = allSpecies[randomIndex]

        let alternativeSpecies = allSpecies.filter { $0 != primary }.prefix(2)
        let alternatives = alternativeSpecies.enumerated().map { index, species in
            (species, 0.2 - Double(index) * 0.05)
        }

        return ClassificationResult(
            species: primary,
            confidence: Double.random(in: 0.75...0.95),
            alternatives: alternatives
        )
    }
}

// MARK: - Classification Error

enum ClassificationError: LocalizedError {
    case modelNotLoaded
    case noResults
    case classificationFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Species classification model is not loaded."
        case .noResults:
            return "No classification results were returned."
        case .classificationFailed:
            return "Failed to classify the bark image."
        }
    }
}

// MARK: - Protocol

protocol SpeciesClassifying {
    func classify(image: CGImage) async throws -> ClassificationResult
}

extension SpeciesClassifier: SpeciesClassifying {}
