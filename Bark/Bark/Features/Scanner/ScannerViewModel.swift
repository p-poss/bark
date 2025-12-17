import SwiftUI
import Combine
import ARKit
import CoreLocation

/// View model coordinating the bark scanning and music generation process
@MainActor
final class ScannerViewModel: ObservableObject {
    // MARK: - Published State

    @Published var state: ScannerState = .initializing
    @Published var treeProfile: TreeProfile?
    @Published var activeNotes: [NoteEvent] = []
    @Published var textureMetrics: TextureMetrics = TextureMetrics()
    @Published var scanProgress: Double = 0
    @Published var tempo: Double = 80
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var isLiDARActive = false

    // MARK: - Services

    let arCameraService = ARCameraService()
    let locationService = LocationService()

    private let barkAnalyzer = BarkAnalyzer()
    private let noteGenerator = NoteGenerator()
    private let audioEngine = AudioEngine()
    private let speciesClassifier = SpeciesClassifier()
    private let ageEstimator = AgeEstimator()
    private let ageModulator = AgeModulator()

    // MARK: - Private State

    private var dbhMeasurements: [Double] = []
    private var classificationTask: Task<Void, Never>?
    private var analysisTimer: Timer?
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Public Methods

    func startScanning() async {
        state = .initializing

        // Check if we're in simulator (no camera/AR)
        #if targetEnvironment(simulator)
        state = .error(.cameraUnavailable)
        // Early return for simulator
        #else
        // Configure AR camera
        do {
            try await arCameraService.configure()
        } catch {
            print("AR Camera configuration failed: \(error)")
            state = .error(.cameraUnavailable)
            return
        }

        // Start AR session (includes LiDAR if available)
        arCameraService.start()
        isLiDARActive = arCameraService.isLiDARAvailable

        // Request location (non-fatal)
        locationService.requestPermission()
        locationService.requestCurrentLocation()

        // Start audio engine (non-fatal - app can work without sound)
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            // Continue without audio rather than failing entirely
        }

        state = .searching
        startAnalysis()
        #endif
    }

    func stopScanning() {
        stopAnalysis()
        arCameraService.stop()
        audioEngine.stop()
        state = .initializing
    }

    func identifyTree() {
        guard let pixelBuffer = arCameraService.currentPixelBuffer else { return }

        state = .identifying

        classificationTask = Task {
            do {
                let result = try await speciesClassifier.classify(pixelBuffer: pixelBuffer)

                // Get texture complexity
                let textureComplexity = barkAnalyzer.analyzeTextureComplexity(pixelBuffer: pixelBuffer)

                // Estimate age
                let ageRange: AgeRange
                if let dbh = ageEstimator.calculateAverageDBH(from: dbhMeasurements) {
                    ageRange = ageEstimator.estimate(
                        species: result.species,
                        dbhCentimeters: dbh,
                        textureComplexity: textureComplexity
                    )
                } else {
                    ageRange = ageEstimator.estimateFromTextureOnly(
                        species: result.species,
                        textureComplexity: textureComplexity
                    )
                }

                // Create tree profile
                let profile = TreeProfile(
                    species: result.species,
                    confidence: result.confidence,
                    ageRange: ageRange,
                    dbhCentimeters: ageEstimator.calculateAverageDBH(from: dbhMeasurements),
                    textureComplexity: textureComplexity
                )

                await MainActor.run {
                    self.treeProfile = profile
                    self.configureAudioForTree(profile)
                    self.state = .identified(profile)
                }
            } catch {
                await MainActor.run {
                    self.state = .error(.classificationFailed)
                }
            }
        }
    }

    func startPlayback() {
        guard case .identified = state else { return }
        state = .scanning
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func saveCurrentTree() -> TreeScan? {
        guard let profile = treeProfile else { return nil }

        let scan = TreeScan(
            species: profile.species,
            ageRange: profile.ageRange,
            location: locationService.currentLocation?.coordinate,
            locationName: locationService.locationName,
            dbhCentimeters: profile.dbhCentimeters,
            textureComplexity: profile.textureComplexity
        )

        // Capture bark image
        if let pixelBuffer = arCameraService.currentPixelBuffer {
            scan.barkImageData = imageDataFromPixelBuffer(pixelBuffer)
        }

        return scan
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Listen for LiDAR diameter measurements from AR camera service
        arCameraService.$measuredDiameter
            .compactMap { $0 }
            .sink { [weak self] diameter in
                self?.dbhMeasurements.append(diameter)
                // Keep last 10 measurements
                if self?.dbhMeasurements.count ?? 0 > 10 {
                    self?.dbhMeasurements.removeFirst()
                }
            }
            .store(in: &cancellables)

        // Listen for camera frames from AR session
        // Use throttle to prevent overwhelming the system
        arCameraService.$currentPixelBuffer
            .compactMap { $0 }
            .throttle(for: .milliseconds(66), scheduler: DispatchQueue.main, latest: true)  // ~15 fps max
            .sink { [weak self] pixelBuffer in
                self?.processFrame(pixelBuffer)
            }
            .store(in: &cancellables)

        // Listen for texture metrics
        barkAnalyzer.$textureMetrics
            .assign(to: &$textureMetrics)

        // Listen for active notes
        noteGenerator.$activeNotes
            .assign(to: &$activeNotes)
    }

    private func startAnalysis() {
        // Analysis is now handled via Combine bindings in setupBindings()
        // The arCameraService.$currentPixelBuffer subscription handles frame processing
    }

    private func stopAnalysis() {
        classificationTask?.cancel()
        analysisTimer?.invalidate()
        recordingTimer?.invalidate()
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard case .scanning = state else { return }

        // Analyze bark texture
        let frame = barkAnalyzer.analyze(pixelBuffer: pixelBuffer)

        // Generate notes
        let notes = noteGenerator.processFrame(frame)

        // Play notes
        if !notes.isEmpty {
            audioEngine.playNotes(notes)
        }

        // Update UI
        activeNotes = noteGenerator.activeNotes
        textureMetrics = frame.textureMetrics
    }

    private func configureAudioForTree(_ profile: TreeProfile) {
        let voice = SpeciesVoice.voice(for: profile.species)
        let modulatedVoice = ageModulator.modulateVoice(voice, forAge: profile.ageRange)

        audioEngine.setVoice(voice)
        audioEngine.setAgeModulation(modulatedVoice)
        noteGenerator.setVoice(modulatedVoice)
        barkAnalyzer.setScale(voice.scale)
        barkAnalyzer.setOctaveRange(
            (modulatedVoice.effectiveOctave - 1)...(modulatedVoice.effectiveOctave + 1)
        )

        tempo = modulatedVoice.tempo
    }

    private func startRecording() {
        guard let _ = audioEngine.startRecording() else { return }

        isRecording = true
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.recordingDuration += 0.1
            }
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if let url = audioEngine.stopRecording() {
            // Associate recording with current tree if saved
            print("Recording saved to: \(url)")
        }

        isRecording = false
    }

    private func imageDataFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Scanner State

enum ScannerState: Equatable {
    case initializing
    case searching
    case identifying
    case identified(TreeProfile)
    case scanning
    case recording
    case error(ScannerError)

    var isActive: Bool {
        switch self {
        case .scanning, .recording:
            return true
        default:
            return false
        }
    }
}

enum ScannerError: Equatable {
    case cameraUnavailable
    case lidarUnavailable
    case classificationFailed
    case audioEngineError

    var message: String {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available. Please check permissions."
        case .lidarUnavailable:
            return "LiDAR is not available on this device."
        case .classificationFailed:
            return "Failed to identify the tree species."
        case .audioEngineError:
            return "Audio engine encountered an error."
        }
    }
}
