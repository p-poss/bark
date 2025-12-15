import AVFoundation
import UIKit
import Combine

/// Manages camera capture session and provides real-time pixel buffer access
final class CameraService: NSObject, ObservableObject {
    @MainActor @Published var isRunning = false
    @MainActor @Published var error: CameraError?
    @MainActor @Published var currentPixelBuffer: CVPixelBuffer?

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.bark.camera.session")
    private let outputQueue = DispatchQueue(label: "com.bark.camera.output")

    private var videoDeviceInput: AVCaptureDeviceInput?

    @MainActor var frameHandler: ((CVPixelBuffer) -> Void)?

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    func checkPermissions() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private var isConfigured = false

    func configure() async throws {
        // Skip if already configured - just need to start
        if isConfigured {
            return
        }

        guard await checkPermissions() else {
            throw CameraError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.configurationFailed)
                    return
                }

                do {
                    try self.configureSession()
                    self.isConfigured = true
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() {
        let session = captureSession
        sessionQueue.async {
            guard !session.isRunning else { return }
            session.startRunning()
            Task { @MainActor [weak self] in
                self?.isRunning = true
            }
        }
    }

    func stop() {
        let session = captureSession
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    // MARK: - Private Methods

    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Use high preset with fallback
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera available")
            throw CameraError.noCameraAvailable
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                videoDeviceInput = videoInput
            } else {
                print("Cannot add video input to session")
                throw CameraError.configurationFailed
            }
        } catch let error {
            print("Failed to create video input: \(error)")
            throw CameraError.configurationFailed
        }

        // Configure video device (non-fatal if fails)
        do {
            try configureVideoDevice(videoDevice)
        } catch {
            print("Video device configuration failed (non-fatal): \(error)")
        }

        // Add video output
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Cannot add video output to session")
            throw CameraError.configurationFailed
        }

        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }

    private func configureVideoDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Set frame rate to 30fps
        let desiredFrameRate = CMTime(value: 1, timescale: 30)
        device.activeVideoMinFrameDuration = desiredFrameRate
        device.activeVideoMaxFrameDuration = desiredFrameRate

        // Enable continuous auto-focus
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        // Enable continuous auto-exposure
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Use DispatchQueue instead of Task to avoid Sendable issues
        DispatchQueue.main.async { [weak self] in
            self?.currentPixelBuffer = pixelBuffer
            self?.frameHandler?(pixelBuffer)
        }
    }
}

// MARK: - Camera Error

enum CameraError: LocalizedError {
    case permissionDenied
    case noCameraAvailable
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied. Please enable camera access in Settings."
        case .noCameraAvailable:
            return "No camera is available on this device."
        case .configurationFailed:
            return "Failed to configure the camera."
        }
    }
}
