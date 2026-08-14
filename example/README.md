# GazePoint SDK — macOS Example

AppKit demo that lives in this repository and compiles against the local `GazePointSDK` package.

```
GazePointSDK-macOS/
├── Sources/GazePointSDK/   # library
└── example/                # this app
```

## What it shows

- Live camera preview from the SDK (`GazePreviewView`)
- White outline on every detected face, aligned to the face
- Green gaze indicator on the preview when exactly one face is in frame
- **Flip Camera** button (cycles Mac cameras)
- Bottom status card with gaze, confidence, head pose, and blink
- Window title also shows `statusText` (`Multiple faces detected` when two faces are in frame; gaze is not calculated then)

Metrics-only apps can use `GazeCamera` with `previewEnabled = false` and never add `previewView`.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ / Swift 6
- Camera permission (System Settings → Privacy & Security → Camera → Terminal or Xcode)

## Run

```bash
cd example
swift build
swift run
```

Or open `Package.swift` in Xcode and run the `GazePointExample` scheme.

## Usage

```swift
import GazePointSDK

let camera = GazeCamera()
camera.options = GazeCameraOptions(previewEnabled: true, showFaceBoxes: true)
camera.onFrame = { frame in
    print(frame.statusText)
}
window.contentView = camera.previewView
camera.start()
```

## Troubleshooting

### Camera permission denied
1. System Settings → Privacy & Security → Camera
2. Enable access for Terminal (if you used `swift run`) or Xcode
3. Run the example again

### Camera not detected
- Close other apps using the camera
- Try `sudo killall VDCAssistant` then relaunch

## License

MIT License — see [LICENSE](../LICENSE) for details
