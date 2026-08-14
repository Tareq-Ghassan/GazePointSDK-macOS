import AVFoundation
import AppKit
import QuartzCore

/// Live camera preview plus white face-box overlay, owned by the macOS SDK.
@available(macOS 13.0, *)
public final class GazePreviewView: NSView {
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

    /// Vision boxes are normalized with origin at the bottom-left of the image,
    /// matching an unflipped AppKit layer. Map through aspect-fill; flip X when
    /// the preview is mirrored.
    public func setFaceBoxes(
        _ visionBoxes: [CGRect],
        imageSize: CGSize,
        flipX: Bool
    ) {
        let path = CGMutablePath()
        for box in visionBoxes {
            path.addRect(
                FaceBoxMapping.mapVisionBoxToLayer(
                    box,
                    imageSize: imageSize,
                    viewSize: bounds.size,
                    flipX: flipX
                )
            )
        }
        boxesLayer.path = path
    }

    public func clearFaceBoxes() {
        boxesLayer.path = nil
    }
}
