import ARKit
import Combine

/// Service for extracting depth data from LiDAR sensor
@MainActor
final class LiDARService: NSObject, ObservableObject {
    @Published var isAvailable = false
    @Published var currentDepthMap: CVPixelBuffer?
    @Published var measuredDiameter: Double?

    private var arSession: ARSession?

    override init() {
        super.init()
        // Disabled: checking availability may initialize ARKit which conflicts with AVCaptureSession
        // checkAvailability()
        isAvailable = false
    }

    // MARK: - Public Methods

    func checkAvailability() {
        isAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    func start() {
        guard isAvailable else { return }

        arSession = ARSession()
        arSession?.delegate = self

        let configuration = ARWorldTrackingConfiguration()

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }

        arSession?.run(configuration)
    }

    func stop() {
        arSession?.pause()
        arSession = nil
    }

    /// Measures trunk diameter at the center of the frame
    /// - Parameter frame: AR frame with depth data
    /// - Returns: Estimated diameter in centimeters, or nil if measurement failed
    func measureTrunkDiameter(from frame: ARFrame) -> Double? {
        guard let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth else {
            return nil
        }

        let depthMap = depthData.depthMap

        // Get depth map dimensions
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
            if depth > 0 && depth < 10 { // Valid depth range (0-10 meters)
                depths.append(depth)
            }
        }

        guard depths.count > 10 else { return nil }

        // Find the trunk by looking for a region with consistent depth
        // that's closer than the background
        let sortedDepths = depths.sorted()
        let medianDepth = sortedDepths[sortedDepths.count / 2]

        // Find edges of trunk (where depth increases significantly)
        var leftEdge: Int?
        var rightEdge: Int?
        let depthThreshold: Float = 0.1 // 10cm depth change indicates edge

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

        // Calculate actual width using camera intrinsics and distance
        let pixelWidth = right - left
        let centerDepth = Double(floatBuffer[centerY * bytesPerRow + (left + right) / 2])

        // Approximate field of view calculation
        // iPhone 12 Pro wide camera: ~69° horizontal FOV
        let horizontalFOV = 69.0 * .pi / 180.0
        let pixelToRadian = horizontalFOV / Double(width)

        let angularWidth = Double(pixelWidth) * pixelToRadian
        let diameter = 2 * centerDepth * tan(angularWidth / 2) * 100 // Convert to cm

        return diameter
    }

    /// Estimates DBH (Diameter at Breast Height) from a series of measurements
    /// - Parameter measurements: Array of diameter measurements
    /// - Returns: Estimated DBH in centimeters
    func estimateDBH(from measurements: [Double]) -> Double? {
        guard !measurements.isEmpty else { return nil }

        // Remove outliers using IQR method
        let sorted = measurements.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        let filtered = measurements.filter { $0 >= lowerBound && $0 <= upperBound }

        guard !filtered.isEmpty else {
            return measurements.reduce(0, +) / Double(measurements.count)
        }

        return filtered.reduce(0, +) / Double(filtered.count)
    }
}

// MARK: - ARSessionDelegate

extension LiDARService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            if let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth {
                self.currentDepthMap = depthData.depthMap
            }

            if let diameter = self.measureTrunkDiameter(from: frame) {
                self.measuredDiameter = diameter
            }
        }
    }
}
