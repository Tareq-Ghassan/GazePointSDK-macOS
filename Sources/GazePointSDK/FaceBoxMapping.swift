import CoreGraphics
import ImageIO

/// Maps Vision face boxes onto a `resizeAspectFill` preview.
enum FaceBoxMapping {
    static func orientedSize(
        bufferWidth: Int,
        bufferHeight: Int,
        orientation: CGImagePropertyOrientation
    ) -> CGSize {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: bufferHeight, height: bufferWidth)
        default:
            return CGSize(width: bufferWidth, height: bufferHeight)
        }
    }

    /// Vision box is normalized with origin at the bottom-left of the oriented image.
    /// Result is in preview-view coordinates (origin top-left), inset so the stroke
    /// sits on the face rather than around hair / background.
    static func mapVisionBox(
        _ box: CGRect,
        imageSize: CGSize,
        viewSize: CGSize,
        flipX: Bool
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }

        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawnW = imageSize.width * scale
        let drawnH = imageSize.height * scale
        let ox = (viewSize.width - drawnW) / 2
        let oy = (viewSize.height - drawnH) / 2

        var rect = CGRect(
            x: box.origin.x * drawnW + ox,
            y: (1 - box.origin.y - box.height) * drawnH + oy,
            width: box.width * drawnW,
            height: box.height * drawnH
        )

        if flipX {
            rect.origin.x = viewSize.width - rect.origin.x - rect.width
        }

        let insetX = rect.width * 0.08
        let insetY = rect.height * 0.06
        return rect.insetBy(dx: insetX, dy: insetY)
    }
}
