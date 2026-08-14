import Foundation
import Vision
import CoreGraphics
import AppKit

/// Enhanced Gaze Tracker for macOS with Vision
@available(macOS 13.0, *)
public class GazeTracker {
    
    // MARK: - Types
    
    public struct GazeResult: Sendable {
        public let gazePoint: CGPoint
        public let confidence: Float
        public let isBlinking: Bool
        public let headPose: HeadPose
        public let timestamp: TimeInterval
        
        public init(gazePoint: CGPoint, confidence: Float, isBlinking: Bool, headPose: HeadPose, timestamp: TimeInterval) {
            self.gazePoint = gazePoint
            self.confidence = confidence
            self.isBlinking = isBlinking
            self.headPose = headPose
            self.timestamp = timestamp
        }
    }
    
    public struct HeadPose: Sendable {
        public let pitch: Float // Nodding up/down
        public let yaw: Float   // Turning left/right
        public let roll: Float  // Tilting left/right
        
        public init(pitch: Float, yaw: Float, roll: Float) {
            self.pitch = pitch
            self.yaw = yaw
            self.roll = roll
        }
    }

    /// All faces in a frame. Gaze is set only when exactly one face is present.
    public struct FrameAnalysis: Sendable {
        public let gaze: GazeResult?
        public let faceBoundingBoxes: [CGRect]

        public init(gaze: GazeResult?, faceBoundingBoxes: [CGRect]) {
            self.gaze = gaze
            self.faceBoundingBoxes = faceBoundingBoxes
        }

        public var faceCount: Int { faceBoundingBoxes.count }
    }
    
    public struct CalibrationData: Codable {
        public var offsetX: Float
        public var offsetY: Float
        public var scaleX: Float
        public var scaleY: Float
        public var rotationCompensation: Float
        
        public init(offsetX: Float = 0, offsetY: Float = 0, scaleX: Float = 1, scaleY: Float = 1, rotationCompensation: Float = 0) {
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.scaleX = scaleX
            self.scaleY = scaleY
            self.rotationCompensation = rotationCompensation
        }
    }
    
    // MARK: - Properties
    
    private let smoothingFactor: Float = 0.3
    private let minConfidenceThreshold: Float = 0.5
    private let blinkThreshold: Float = 0.18
    private let velocityThreshold: Float = 100.0
    
    private var lastGazePoint: CGPoint?
    private var calibrationData: CalibrationData?
    private var isCalibrated: Bool = false
    private var kalmanFilter: KalmanFilter
    private let performanceMonitor: PerformanceMonitor
    
    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()
    
    // MARK: - Initialization
    
    public init() {
        self.kalmanFilter = KalmanFilter()
        self.performanceMonitor = PerformanceMonitor()
    }
    
    // MARK: - Public Methods
    
    /// Calculate gaze point from a CVPixelBuffer. Returns nil when zero or multiple faces are in frame.
    public func calculateGazePoint(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        screenSize: CGSize = .zero
    ) -> GazeResult? {
        return analyze(from: pixelBuffer, orientation: orientation, screenSize: screenSize).gaze
    }

    /// Detect every face. Gaze is estimated only when `faceCount == 1`.
    public func analyze(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        screenSize: CGSize = .zero
    ) -> FrameAnalysis {
        let startTime = performanceMonitor.startFrame()
        defer {
            performanceMonitor.endFrame(startTime: startTime)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        let outputSize = screenSize.width > 1 && screenSize.height > 1
            ? screenSize
            : (NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080))

        do {
            try handler.perform([faceDetectionRequest])
            let observations = faceDetectionRequest.results ?? []
            let gaze: GazeResult?
            if observations.count == 1, let face = observations.first {
                gaze = processGaze(from: face, screenSize: outputSize)
            } else {
                lastGazePoint = nil
                gaze = nil
            }
            return FrameAnalysis(
                gaze: gaze,
                faceBoundingBoxes: observations.map(\.boundingBox)
            )
        } catch {
            print("Error performing face detection: \(error)")
            return FrameAnalysis(gaze: nil, faceBoundingBoxes: [])
        }
    }
    
    /// Calibrate the gaze tracker with known screen points
    public func calibrate(calibrationPoints: [(expected: CGPoint, actual: CGPoint)]) {
        guard calibrationPoints.count >= 3 else {
            print("Need at least 3 calibration points")
            return
        }
        
        var sumOffsetX: Float = 0
        var sumOffsetY: Float = 0
        var sumScaleX: Float = 0
        var sumScaleY: Float = 0
        
        for (expected, actual) in calibrationPoints {
            sumOffsetX += Float(expected.x - actual.x)
            sumOffsetY += Float(expected.y - actual.y)
            
            if actual.x != 0 {
                sumScaleX += Float(expected.x / actual.x)
            }
            if actual.y != 0 {
                sumScaleY += Float(expected.y / actual.y)
            }
        }
        
        let count = Float(calibrationPoints.count)
        calibrationData = CalibrationData(
            offsetX: sumOffsetX / count,
            offsetY: sumOffsetY / count,
            scaleX: sumScaleX / count,
            scaleY: sumScaleY / count
        )
        
        isCalibrated = true
        print("Calibration completed: \(String(describing: calibrationData))")
    }
    
    /// Reset calibration
    public func resetCalibration() {
        calibrationData = nil
        isCalibrated = false
        lastGazePoint = nil
        kalmanFilter.reset()
    }
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> PerformanceMonitor.PerformanceMetrics {
        return performanceMonitor.getMetrics()
    }
    
    // MARK: - Private Methods
    
    private func processGaze(from faceObservation: VNFaceObservation, screenSize: CGSize) -> GazeResult? {
        guard let landmarks = faceObservation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return nil
        }

        let isBlinking = detectBlink(leftEye: leftEye, rightEye: rightEye)
        let headPose = calculateHeadPose(from: faceObservation)
        let look = lookDirection(
            leftEye: leftEye,
            rightEye: rightEye,
            leftPupil: landmarks.leftPupil,
            rightPupil: landmarks.rightPupil,
            headPose: headPose
        )
        let calibrated = applyCalibration(to: look)
        let screenPoint = CGPoint(
            x: max(0, min(screenSize.width, calibrated.x * screenSize.width)),
            y: max(0, min(screenSize.height, (1 - calibrated.y) * screenSize.height))
        )
        let filteredPoint = kalmanFilter.update(measurement: screenPoint)
        let smoothedPoint = applyAdaptiveSmoothing(currentPoint: filteredPoint)
        let confidence = calculateConfidence(faceObservation: faceObservation, isBlinking: isBlinking)

        lastGazePoint = smoothedPoint

        return GazeResult(
            gazePoint: smoothedPoint,
            confidence: confidence,
            isBlinking: isBlinking,
            headPose: headPose,
            timestamp: Date().timeIntervalSince1970
        )
    }

    /// Normalized look direction in 0...1 (origin bottom-left of the screen).
    private func lookDirection(
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D,
        leftPupil: VNFaceLandmarkRegion2D?,
        rightPupil: VNFaceLandmarkRegion2D?,
        headPose: HeadPose
    ) -> CGPoint {
        let left = pupilInEye(eye: leftEye, pupil: leftPupil)
        let right = pupilInEye(eye: rightEye, pupil: rightPupil)
        var x = (left.x + right.x) / 2
        var y = (left.y + right.y) / 2
        x += CGFloat(headPose.yaw) / 55
        y += CGFloat(headPose.pitch) / 45
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }

    private func pupilInEye(eye: VNFaceLandmarkRegion2D, pupil: VNFaceLandmarkRegion2D?) -> CGPoint {
        let pts = eye.normalizedPoints
        guard pts.count >= 2 else { return CGPoint(x: 0.5, y: 0.5) }
        let minX = pts.map(\.x).min() ?? 0
        let maxX = pts.map(\.x).max() ?? 1
        let minY = pts.map(\.y).min() ?? 0
        let maxY = pts.map(\.y).max() ?? 1
        let pupilPts = pupil?.normalizedPoints ?? []
        let focus = pupilPts.isEmpty ? averagePoint(points: pts) : averagePoint(points: pupilPts)
        let spanX = max(maxX - minX, 0.001)
        let spanY = max(maxY - minY, 0.001)
        return CGPoint(
            x: min(1, max(0, (focus.x - minX) / spanX)),
            y: min(1, max(0, (focus.y - minY) / spanY))
        )
    }

    private func calculateHeadPose(from faceObservation: VNFaceObservation) -> HeadPose {
        let toDegrees: (Float) -> Float = { $0 * 180 / .pi }
        return HeadPose(
            pitch: toDegrees(faceObservation.pitch?.floatValue ?? 0),
            yaw: toDegrees(faceObservation.yaw?.floatValue ?? 0),
            roll: toDegrees(faceObservation.roll?.floatValue ?? 0)
        )
    }

    private func detectBlink(leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D) -> Bool {
        let avg = (eyeOpenness(leftEye) + eyeOpenness(rightEye)) / 2
        return avg < blinkThreshold
    }

    private func eyeOpenness(_ eye: VNFaceLandmarkRegion2D) -> Float {
        let points = eye.normalizedPoints
        guard points.count >= 2 else { return 1 }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 1
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 1
        let width = maxX - minX
        guard width > 0 else { return 1 }
        return Float((maxY - minY) / width)
    }
    
    private func applyCalibration(to gazeVector: CGPoint) -> CGPoint {
        guard isCalibrated, let calibration = calibrationData else {
            return gazeVector
        }
        
        return CGPoint(
            x: CGFloat(gazeVector.x * CGFloat(calibration.scaleX) + CGFloat(calibration.offsetX)),
            y: CGFloat(gazeVector.y * CGFloat(calibration.scaleY) + CGFloat(calibration.offsetY))
        )
    }
    
    private func applyAdaptiveSmoothing(currentPoint: CGPoint) -> CGPoint {
        guard let lastPoint = lastGazePoint else {
            return currentPoint
        }
        
        // Calculate velocity
        let dx = currentPoint.x - lastPoint.x
        let dy = currentPoint.y - lastPoint.y
        let velocity = sqrt(dx * dx + dy * dy)
        
        // Adaptive smoothing factor
        let adaptiveFactor: CGFloat
        if velocity > CGFloat(velocityThreshold) {
            adaptiveFactor = CGFloat(smoothingFactor) * 0.5
        } else {
            adaptiveFactor = CGFloat(smoothingFactor)
        }
        
        return CGPoint(
            x: lastPoint.x + (currentPoint.x - lastPoint.x) * adaptiveFactor,
            y: lastPoint.y + (currentPoint.y - lastPoint.y) * adaptiveFactor
        )
    }
    
    private func calculateConfidence(faceObservation: VNFaceObservation, isBlinking: Bool) -> Float {
        var confidence = faceObservation.confidence
        
        // Reduce confidence if blinking
        if isBlinking {
            confidence *= 0.3
        }
        
        // Check face quality
        if let boundingBox = Optional(faceObservation.boundingBox) {
            let faceArea = boundingBox.width * boundingBox.height
            if faceArea < 0.05 { // Face too small
                confidence *= 0.7
            }
        }
        
        return max(0, min(1, confidence))
    }
    
    // MARK: - Helper Methods
    
    private func averagePoint(points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }
}
