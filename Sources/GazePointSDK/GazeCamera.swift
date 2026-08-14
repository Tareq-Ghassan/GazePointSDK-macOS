import AVFoundation
import AppKit
import CoreMedia
import CoreVideo
import Foundation

/// One processed camera frame from [GazeCamera].
@available(macOS 13.0, *)
public struct GazeFrame: Sendable {
    public let gaze: GazeTracker.GazeResult?
    public let faceCount: Int
    public let faceDetected: Bool
    public let statusText: String

    public var hasMultipleFaces: Bool { faceCount > 1 }

    public init(
        gaze: GazeTracker.GazeResult?,
        faceCount: Int,
        faceDetected: Bool,
        statusText: String
    ) {
        self.gaze = gaze
        self.faceCount = faceCount
        self.faceDetected = faceDetected
        self.statusText = statusText
    }
}

/// Options for [GazeCamera]. Tracking always runs; preview and boxes are opt-in.
@available(macOS 13.0, *)
public struct GazeCameraOptions: Sendable {
    public var previewEnabled: Bool
    public var showFaceBoxes: Bool

    public init(previewEnabled: Bool = true, showFaceBoxes: Bool = true) {
        self.previewEnabled = previewEnabled
        self.showFaceBoxes = showFaceBoxes
    }
}

/// AVCapture + Vision session owned by the macOS SDK.
@available(macOS 13.0, *)
public final class GazeCamera: NSObject, @unchecked Sendable {
    /// Live preview. Create `GazeCamera` on the main thread (AppKit).
    public let previewView: GazePreviewView
    public var onFrame: ((GazeFrame) -> Void)?
    public var options: GazeCameraOptions {
        didSet { applyPreviewVisibility() }
    }

    public var previewEnabled: Bool {
        get { options.previewEnabled }
        set { options.previewEnabled = newValue }
    }

    public var showFaceBoxes: Bool {
        get { options.showFaceBoxes }
        set {
            options.showFaceBoxes = newValue
            if !newValue {
                DispatchQueue.main.async { self.previewView.clearFaceBoxes() }
            }
        }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.gazepoint.sdk.macos.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let tracker = GazeTracker()
    private var deviceIndex = 0
    private var isMirroredPreview = true
    private var isRunning = false
    private var latestGaze: GazeTracker.GazeResult?

    @MainActor
    public override init() {
        self.previewView = GazePreviewView()
        self.options = GazeCameraOptions()
        super.init()
        previewView.videoPreviewLayer.session = session
        applyPreviewVisibility()
    }

    /// Flutter plugins register off the main actor; hop here so NSView setup is legal.
    nonisolated public static func create() -> GazeCamera {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { GazeCamera() }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { GazeCamera() }
        }
    }

    public func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession()
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.isRunning = true
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isRunning = false
            DispatchQueue.main.async { self.previewView.clearFaceBoxes() }
        }
    }

    @objc public func switchCamera() {
        let devices = Self.videoDevices()
        guard !devices.isEmpty else { return }
        deviceIndex = (deviceIndex + 1) % devices.count
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    public func calibrate(calibrationPoints: [(expected: CGPoint, actual: CGPoint)]) {
        tracker.calibrate(calibrationPoints: calibrationPoints)
    }

    public func resetCalibration() {
        tracker.resetCalibration()
    }

    public func getPerformanceMetrics() -> PerformanceMonitor.PerformanceMetrics {
        tracker.getPerformanceMetrics()
    }

    public func getLatestGaze() -> GazeTracker.GazeResult? { latestGaze }

    private var cachedPreviewSize: CGSize = .zero

    private func applyPreviewVisibility() {
        DispatchQueue.main.async {
            self.previewView.isHidden = !self.options.previewEnabled
            self.cachedPreviewSize = self.previewView.bounds.size
            if !self.options.previewEnabled || !self.options.showFaceBoxes {
                self.previewView.clearFaceBoxes()
            }
        }
    }

    private static func videoDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        let devices = Self.videoDevices()
        let camera = devices.indices.contains(deviceIndex)
            ? devices[deviceIndex]
            : AVCaptureDevice.default(for: .video)

        guard
            let camera,
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            emit(
                GazeFrame(
                    gaze: nil,
                    faceCount: 0,
                    faceDetected: false,
                    statusText: "Camera unavailable"
                )
            )
            return
        }

        session.addInput(input)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(label: "com.gazepoint.sdk.macos.frames")
            )
        }

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }

        isMirroredPreview = camera.position != .back
        session.commitConfiguration()
        DispatchQueue.main.async { [weak self] in
            guard let self, let conn = self.previewView.videoPreviewLayer.connection else { return }
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = self.isMirroredPreview
            }
        }
    }

    private func emit(_ frame: GazeFrame) {
        latestGaze = frame.gaze
        DispatchQueue.main.async { self.onFrame?(frame) }
    }
}

@available(macOS 13.0, *)
extension GazeCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let previewSize = cachedPreviewSize.width > 1
            ? cachedPreviewSize
            : (NSScreen.main?.frame.size ?? .zero)
        let analysis = tracker.analyze(
            from: pixelBuffer,
            orientation: .up,
            screenSize: previewSize
        )
        let imageSize = FaceBoxMapping.orientedSize(
            bufferWidth: CVPixelBufferGetWidth(pixelBuffer),
            bufferHeight: CVPixelBufferGetHeight(pixelBuffer),
            orientation: .up
        )

        if options.previewEnabled && options.showFaceBoxes {
            let boxes = analysis.faceBoundingBoxes
            DispatchQueue.main.async {
                self.cachedPreviewSize = self.previewView.bounds.size
                self.previewView.setFaceBoxes(boxes, imageSize: imageSize, flipX: self.isMirroredPreview)
            }
        }

        let gaze = analysis.gaze
        let count = analysis.faceCount
        let status: String
        if count == 0 {
            status = "No face detected"
        } else if count > 1 {
            status = "Multiple faces detected"
        } else if gaze?.isBlinking == true {
            status = "Blink detected"
        } else if gaze != nil {
            status = "Tracking"
        } else {
            status = "No face detected"
        }

        emit(
            GazeFrame(
                gaze: gaze,
                faceCount: count,
                faceDetected: count > 0,
                statusText: status
            )
        )
    }
}
