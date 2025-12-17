import ARKit
import Combine
import UIKit

/// Unified camera service using ARSession for both camera frames and LiDAR depth
@MainActor
final class ARCameraService: NSObject, ObservableObject {
    // MARK: - Published State

    @Published var isRunning = false
    @Published var currentPixelBuffer: CVPixelBuffer?
    @Published var currentDepthMap: CVPixelBuffer?
    @Published var measuredDiameter: Double?
    @Published var error: ARCameraError?
    @Published var isLiDARAvailable = false

    // Frame processing - only keep latest, process immediately
    private var lastProcessedTime: TimeInterval = 0
    private let minFrameInterval: TimeInterval = 1.0 / 15.0  // Limit to 15 fps for processing

    // MARK: - AR Session

    let session = ARSession()
    private var isConfigured = false

    // MARK: - Initialization

    override init() {
        super.init()
        checkLiDARAvailability()
    }

    // MARK: - Public Methods

    func checkLiDARAvailability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) ||
                           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    func configure() async throws {
        guard !isConfigured else { return }

        // Check camera authorization
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw ARCameraError.permissionDenied
            }
        case .denied, .restricted:
            throw ARCameraError.permissionDenied
        @unknown default:
            throw ARCameraError.permissionDenied
        }

        // Set up AR session delegate
        session.delegate = self
        isConfigured = true
    }

    func start() {
        guard isConfigured else { return }

        let configuration = ARWorldTrackingConfiguration()

        // Enable LiDAR depth if available
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }

        // Run the session
        session.run(configuration)
        isRunning = true
    }

    func stop() {
        session.pause()
        isRunning = false
    }

    /// Measures trunk diameter at the center of the frame
    func measureTrunkDiameter(from frame: ARFrame) -> Double? {
        guard let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth else {
            return nil
        }

        let depthMap = depthData.depthMap

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }

        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size

        // Sample depth at center horizontal line
        let centerY = height / 2
        var depths: [Float] = []

        for x in 0..<width {
            let depth = floatBuffer[centerY * bytesPerRow + x]
            if depth > 0 && depth < 10 {
                depths.append(depth)
            }
        }

        guard depths.count > 10 else { return nil }

        let sortedDepths = depths.sorted()
        let medianDepth = sortedDepths[sortedDepths.count / 2]

        // Find edges of trunk
        var leftEdge: Int?
        var rightEdge: Int?
        let depthThreshold: Float = 0.1

        for x in (width / 4)..<(width * 3 / 4) {
            let depth = floatBuffer[centerY * bytesPerRow + x]
            let prevDepth = floatBuffer[centerY * bytesPerRow + x - 1]

            if leftEdge == nil && prevDepth - depth > depthThreshold && depth < medianDepth + 0.2 {
                leftEdge = x
            }

            if leftEdge != nil && depth - prevDepth > depthThreshold {
                rightEdge = x
                break
            }
        }

        guard let left = leftEdge, let right = rightEdge, right > left else {
            return nil
        }

        // Calculate actual width
        let pixelWidth = right - left
        let centerDepth = Double(floatBuffer[centerY * bytesPerRow + (left + right) / 2])

        let horizontalFOV = 69.0 * .pi / 180.0
        let pixelToRadian = horizontalFOV / Double(width)

        let angularWidth = Double(pixelWidth) * pixelToRadian
        let diameter = 2 * centerDepth * tan(angularWidth / 2) * 100

        return diameter
    }
}

// MARK: - ARSessionDelegate

extension ARCameraService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Throttle frame processing to avoid retaining too many frames
        let currentTime = frame.timestamp

        Task { @MainActor in
            // Skip if too soon since last processed frame
            guard currentTime - self.lastProcessedTime >= self.minFrameInterval else {
                return
            }
            self.lastProcessedTime = currentTime

            // Copy the pixel buffer data we need, don't retain the frame
            self.currentPixelBuffer = frame.capturedImage

            // Update depth data if available
            if let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth {
                self.currentDepthMap = depthData.depthMap

                // Measure diameter
                if let diameter = self.measureTrunkDiameter(from: frame) {
                    self.measuredDiameter = diameter
                }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = .sessionFailed
            self.isRunning = false
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.isRunning = false
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.start()
        }
    }
}

// MARK: - AR Camera Error

enum ARCameraError: LocalizedError {
    case permissionDenied
    case configurationFailed
    case sessionFailed
    case lidarUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied. Please enable camera access in Settings."
        case .configurationFailed:
            return "Failed to configure the AR session."
        case .sessionFailed:
            return "AR session encountered an error."
        case .lidarUnavailable:
            return "LiDAR is not available on this device."
        }
    }
}
