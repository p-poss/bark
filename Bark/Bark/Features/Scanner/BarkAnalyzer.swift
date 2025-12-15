import CoreVideo
import AVFoundation
import Combine

/// Analyzes bark texture from camera frames and generates musical note events
final class BarkAnalyzer: ObservableObject {
    @Published var currentFrame: BarkFrame?
    @Published var textureMetrics: TextureMetrics = TextureMetrics()

    private let imageProcessor = ImageProcessor()
    private var currentScale: MusicalScale = .dorian
    private var octaveRange: ClosedRange<Int> = 3...5
    private var rootNote: Int = 62 // D

    // Processing parameters
    private let sliceHeight = 10
    private let maxNotesPerFrame = 8
    private let minNoteVelocity = 30
    private let noteSpacing: TimeInterval = 0.05 // Minimum time between notes

    private var lastNoteTime: TimeInterval = 0

    // MARK: - Public Methods

    func setScale(_ scale: MusicalScale) {
        currentScale = scale
    }

    func setOctaveRange(_ range: ClosedRange<Int>) {
        octaveRange = range
    }

    func setRootNote(_ note: Int) {
        rootNote = note
    }

    /// Analyzes a pixel buffer and returns a BarkFrame with note events
    func analyze(
        pixelBuffer: CVPixelBuffer,
        depthData: AVDepthData? = nil
    ) -> BarkFrame {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Apply adaptive thresholding
        guard let thresholded = imageProcessor.adaptiveThreshold(pixelBuffer) else {
            return BarkFrame()
        }

        var notes: [NoteEvent] = []
        let currentTime = CACurrentMediaTime()

        // Analyze horizontal slices
        let sliceCount = height / sliceHeight
        let slicesToAnalyze = min(sliceCount, 20) // Limit processing

        for sliceIndex in 0..<slicesToAnalyze {
            let y = sliceIndex * (height / slicesToAnalyze)

            let slice = imageProcessor.extractHorizontalSlice(
                thresholded,
                width: width,
                y: y,
                height: sliceHeight
            )

            let darkRegions = imageProcessor.findDarkRegions(
                in: slice,
                yPosition: Double(y),
                minWidth: 5,
                threshold: 0.4
            )

            for region in darkRegions {
                guard notes.count < maxNotesPerFrame else { break }

                let note = createNoteEvent(
                    from: region,
                    imageWidth: width,
                    imageHeight: height,
                    timestamp: currentTime,
                    depthData: depthData
                )

                if note.velocity >= minNoteVelocity {
                    notes.append(note)
                }
            }
        }

        // Calculate texture metrics
        let metrics = imageProcessor.calculateTextureMetrics(
            thresholded,
            width: width,
            height: height
        )

        let frame = BarkFrame(
            timestamp: currentTime,
            notes: notes,
            textureMetrics: metrics
        )

        DispatchQueue.main.async {
            self.currentFrame = frame
            self.textureMetrics = metrics
        }

        return frame
    }

    /// Analyzes texture complexity for age estimation
    func analyzeTextureComplexity(pixelBuffer: CVPixelBuffer) -> Double {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let thresholded = imageProcessor.adaptiveThreshold(pixelBuffer) else {
            return 0.5
        }

        let metrics = imageProcessor.calculateTextureMetrics(
            thresholded,
            width: width,
            height: height
        )

        return metrics.complexity
    }

    // MARK: - Private Methods

    private func createNoteEvent(
        from region: DarkRegion,
        imageWidth: Int,
        imageHeight: Int,
        timestamp: TimeInterval,
        depthData: AVDepthData?
    ) -> NoteEvent {
        // Map horizontal position to pitch
        let normalizedX = region.centerX / Double(imageWidth)
        let pitch = mapToScale(normalizedX)

        // Add depth-based pitch modification if available
        let depthBoost = getDepthBoost(at: region.center, depthData: depthData)

        // Map region width to duration (wider = longer)
        let normalizedWidth = region.width / Double(imageWidth)
        let duration = mapToDuration(normalizedWidth)

        // Map darkness intensity to velocity (darker = louder)
        let velocity = mapToVelocity(region.averageIntensity)

        // Normalize position for screen coordinates
        let screenPosition = CGPoint(
            x: region.centerX / Double(imageWidth),
            y: region.center.y / Double(imageHeight)
        )

        return NoteEvent(
            pitch: pitch + depthBoost,
            velocity: velocity,
            duration: duration,
            position: screenPosition,
            timestamp: timestamp
        )
    }

    private func mapToScale(_ normalizedX: Double) -> Int {
        return currentScale.noteFromNormalized(
            normalizedX,
            root: rootNote,
            octaveRange: octaveRange
        )
    }

    private func mapToDuration(_ normalizedWidth: Double) -> TimeInterval {
        // Map width to duration: 0.05s to 0.5s
        let minDuration = 0.05
        let maxDuration = 0.5
        return minDuration + normalizedWidth * (maxDuration - minDuration)
    }

    private func mapToVelocity(_ intensity: Double) -> Int {
        // Darker regions (lower intensity) = higher velocity
        let invertedIntensity = 1.0 - intensity
        let velocity = Int(invertedIntensity * 100) + 27 // Range: 27-127
        return min(127, max(0, velocity))
    }

    private func getDepthBoost(at position: CGPoint, depthData: AVDepthData?) -> Int {
        guard let depthData = depthData else { return 0 }

        // Get the depth map from AVDepthData
        let depthMap = depthData.depthDataMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let x = Int(position.x * Double(width))
        let y = Int(position.y * Double(height))

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return 0 }

        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size

        let depth = floatBuffer[y * bytesPerRow + x]

        // Map depth to pitch boost: closer = higher pitch
        // Typical bark scanning distance: 0.3-1.0 meters
        if depth > 0.2 && depth < 1.5 {
            let normalizedDepth = 1.0 - Double((depth - 0.2) / 1.3)
            return Int(normalizedDepth * 12) // Up to one octave boost
        }

        return 0
    }
}

// MARK: - BarkAnalyzing Protocol

protocol BarkAnalyzing {
    func analyze(pixelBuffer: CVPixelBuffer, depthData: AVDepthData?) -> BarkFrame
    func setScale(_ scale: MusicalScale)
    func setOctaveRange(_ range: ClosedRange<Int>)
}

extension BarkAnalyzer: BarkAnalyzing {}
