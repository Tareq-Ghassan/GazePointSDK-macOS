import Foundation

/// GazePoint SDK for macOS — eye tracking and gaze point detection.
///
/// Use ``GazeCamera`` for a live session (preview, white face boxes, status text).
/// Use ``GazeTracker`` when you already have a `CVPixelBuffer`.
@available(macOS 13.0, *)
public struct GazePointSDK {
    public static let version = "2.2.1"
    public static let build = "1"

    public static var fullVersion: String {
        "\(version) (\(build))"
    }
}
