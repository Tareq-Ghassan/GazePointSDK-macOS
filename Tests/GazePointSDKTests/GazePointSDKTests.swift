import XCTest
@testable import GazePointSDK

@available(macOS 13.0, *)
final class GazePointSDKTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(GazePointSDK.version, "2.2.0")
    }

    func testCameraOptionsDefaultToPreview() {
        let options = GazeCameraOptions()
        XCTAssertTrue(options.previewEnabled)
        XCTAssertTrue(options.showFaceBoxes)
    }
}
