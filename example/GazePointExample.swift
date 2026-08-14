import AppKit
import AVFoundation
import GazePointSDK

/// AppKit demo matching Android/iOS: full-window SDK preview, white face boxes,
/// overlay card with status, gaze dot from `GazeCamera`.
@main
enum GazePointExample {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var camera: GazeCamera?
    private var window: NSWindow?
    private var overlay: OverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let camera = GazeCamera()
        self.camera = camera

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 900),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GazePoint SDK Demo"
        window.center()

        let root = NSView(frame: window.contentView?.bounds ?? .zero)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        root.autoresizingMask = [.width, .height]

        camera.previewView.frame = root.bounds
        camera.previewView.autoresizingMask = [.width, .height]
        root.addSubview(camera.previewView)

        let flip = NSButton(title: "Flip Camera", target: nil, action: nil)
        flip.bezelStyle = .rounded
        flip.translatesAutoresizingMaskIntoConstraints = false
        flip.target = camera
        flip.action = #selector(GazeCamera.switchCamera)
        root.addSubview(flip)

        let overlay = OverlayPanel()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(overlay)
        NSLayoutConstraint.activate([
            flip.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            flip.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            overlay.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            overlay.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            overlay.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        self.overlay = overlay

        camera.options = GazeCameraOptions(previewEnabled: true, showFaceBoxes: true)
        camera.onFrame = { [weak overlay, weak window] frame in
            overlay?.apply(frame)
            window?.title = "GazePoint — \(frame.statusText)"
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        camera.start()
                    } else {
                        overlay.status.stringValue = "Camera permission denied"
                    }
                }
            }
        default:
            overlay.status.stringValue = "Camera permission denied"
        }

        window.contentView = root
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        camera?.stop()
        return true
    }
}

private final class OverlayPanel: NSView {
    let status = NSTextField(labelWithString: "Starting camera…")
    private let gaze = NSTextField(labelWithString: "Point the camera at your face.")
    private let head = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        layer?.cornerRadius = 16

        let title = NSTextField(labelWithString: "GazePoint SDK Demo")
        title.font = .boldSystemFont(ofSize: 16)
        title.textColor = .white

        status.font = .systemFont(ofSize: 14)
        status.textColor = .systemYellow
        gaze.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        gaze.textColor = .white
        head.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        head.textColor = .white

        let stack = NSStackView(views: [title, status, gaze, head])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ frame: GazeFrame) {
        status.stringValue = frame.statusText
        status.textColor = frame.faceDetected && !frame.hasMultipleFaces
            ? .systemGreen
            : .systemYellow
        if let result = frame.gaze, frame.faceDetected {
            gaze.stringValue = String(
                format: "Gaze: (%.0f, %.0f)  Confidence: %.0f%%",
                result.gazePoint.x,
                result.gazePoint.y,
                result.confidence * 100
            )
            head.stringValue = String(
                format: "Head  pitch: %.1f  yaw: %.1f  roll: %.1f  %@",
                result.headPose.pitch,
                result.headPose.yaw,
                result.headPose.roll,
                result.isBlinking ? "Eyes: blinking" : "Eyes: open"
            )
        } else if frame.faceDetected {
            gaze.stringValue = "Gaze is only calculated when one face is in frame."
            head.stringValue = ""
        } else {
            gaze.stringValue = "Point the camera at your face."
            head.stringValue = ""
        }
    }
}
