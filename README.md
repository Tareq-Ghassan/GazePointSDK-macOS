# GazePoint SDK for macOS

Native macOS eye tracking using AVFoundation and Apple Vision. Preview, white face boxes, and multi-face status live in the SDK — not in the example app.

**Repository:** [Tareq-Ghassan/GazePointSDK-macOS](https://github.com/Tareq-Ghassan/GazePointSDK-macOS)  
**Umbrella monorepo:** [FaceDetection-GazePoint](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint)

## Features

- ✅ **Live camera preview** — Opt-in `GazePreviewView` (disable for metrics-only apps)
- ✅ **Face bounding boxes** — White outline on every detected face (aligned to the preview)
- ✅ **Multi-face status** — `GazeFrame.statusText` is `"Multiple faces detected"` when more than one face is in frame; `frame.gaze` is `nil` until only one face remains
- ✅ **Real-time Gaze Tracking** — Track the user's gaze point on screen in real time (single face only)
- ✅ **Head Pose Compensation** — Accurate tracking regardless of head position
- ✅ **Blink Detection** — Detect blinks using Eye Aspect Ratio (EAR)
- ✅ **Kalman Filtering** — Smooth gaze point tracking
- ✅ **Calibration Support** — Multi-point calibration for improved accuracy
- ✅ **Performance Monitoring** — Built-in FPS and processing time tracking

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Camera access (System Settings → Privacy & Security → Camera)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Tareq-Ghassan/GazePointSDK-macOS.git", from: "2.2.1")
]
```

### CocoaPods

```ruby
pod 'GazePointSDK-macOS', :git => 'https://github.com/Tareq-Ghassan/GazePointSDK-macOS.git', :tag => '2.2.1'
```

## Quick Start

### Camera + preview (recommended)

```swift
import GazePointSDK
import AppKit

let camera = GazeCamera()
camera.options = GazeCameraOptions(previewEnabled: true, showFaceBoxes: true)
camera.onFrame = { frame in
    // frame.statusText — "No face detected" | "Multiple faces detected" | "Blink detected" | "Tracking"
    // frame.gaze is nil unless exactly one face is in frame
    // White boxes are drawn on camera.previewView
}
view.addSubview(camera.previewView)
camera.start()

// Metrics only: GazeCameraOptions(previewEnabled: false) and skip adding previewView
```

### Gaze math only (you already have a camera frame)

```swift
import GazePointSDK

let gazeTracker = GazeTracker()
if let result = gazeTracker.calculateGazePoint(from: pixelBuffer, orientation: .up) {
    print("Gaze: \(result.gazePoint)")
    print("Confidence: \(result.confidence)")
}
```

## Example

```bash
cd example
swift build && swift run
```

Allow Camera for Terminal or Xcode in System Settings. See [TESTING.md](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint/blob/main/TESTING.md).

The Flutter plugin (`gazepoint_sdk`) ships a **source snapshot** of this SDK under `macos/gazepoint_sdk`. Releasing this repo does not update pub.dev until that snapshot is copied. `flutter run -d macos` from `flutter/example` is the Flutter macOS test.

## License

MIT License

## Links

- [Main Repository](https://github.com/Tareq-Ghassan/FaceDetection-GazePoint)
- [Documentation](https://github.com/Tareq-Ghassan/GazePointSDK-macOS)
