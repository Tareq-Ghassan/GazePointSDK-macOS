import AVFoundation
import AppKit
import QuartzCore

/// Live camera preview plus white face-box overlay, owned by the macOS SDK.
@available(macOS 13.0, *)
public final class GazePreviewView: NSView {
    public override var isFlipped: Bool { true }

    public let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    private let boxesLayer = CAShapeLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        videoPreviewLayer.videoGravity = .resizeAspectFill
        boxesLayer.fillColor = NSColor.clear.cgColor
        boxesLayer.strokeColor = NSColor.white.cgColor
        boxesLayer.lineWidth = 3
        layer?.addSublayer(videoPreviewLayer)
        layer?.addSublayer(boxesLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        videoPreviewLayer.videoGravity = .resizeAspectFill
        boxesLayer.fillColor = NSColor.clear.cgColor
        boxesLayer.strokeColor = NSColor.white.cgColor
        boxesLayer.lineWidth = 3
        layer?.addSublayer(videoPreviewLayer)
        layer?.addSublayer(boxesLayer)
    }

    public override func layout() {
        super.layout()
        videoPreviewLayer.frame = bounds
        boxesLayer.frame = bounds
    }

    /// Vision boxes are normalized, origin at the bottom-left of the oriented image.
    public func setFaceBoxes(
        _ visionBoxes: [CGRect],
        imageSize: CGSize,
        flipX: Bool
    ) {
        let path = CGMutablePath()
        for box in visionBoxes {
            var rect = FaceBoxMapping.mapVisionBox(
                box,
                imageSize: imageSize,
                viewSize: bounds.size,
                flipX: flipX
            )
            // CALayer is bottom-left; mapping is top-left (same as iOS UIView).
            rect.origin.y = bounds.height - rect.origin.y - rect.height
            path.addRect(rect)
        }
        boxesLayer.path = path
    }

    public func clearFaceBoxes() {
        boxesLayer.path = nil
    }
}
