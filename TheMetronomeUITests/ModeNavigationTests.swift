import XCTest

final class ModeNavigationTests: XCTestCase {
    func testRepeatedModeSwitchingPreservesTransport() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["mode-menu"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["mode-menu"].label, "Metronome")
        proof(app, "Collapsed text mode trigger")
        app.buttons["mode-menu"].tap()
        app.buttons["mode-menu"].tap()
        XCTAssertFalse(app.buttons["mode-live"].exists)
        app.buttons["mode-menu"].tap()
        let widths = ["metronome", "practice", "live"].map { app.buttons["mode-\($0)"].frame.width }
        XCTAssertEqual(widths[0], widths[1], accuracy: 1)
        XCTAssertEqual(widths[1], widths[2], accuracy: 1)
        proof(app, "Mode chooser — equal widths")
        app.buttons["mode-practice"].tap()
        XCTAssertTrue(app.buttons["practice-ramp"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["mode-menu"].label, "Practice")
        proof(app, "Practice mode")
        app.buttons["settings-transport"].tap()
        let playingLabel = app.buttons["settings-transport"].label
        app.buttons["mode-menu"].tap()
        app.buttons["mode-live"].tap()
        XCTAssertEqual(app.buttons["settings-transport"].label, playingLabel)
        XCTAssertEqual(app.buttons["mode-menu"].label, "Live")
        proof(app, "Live mode")
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        XCTAssertEqual(app.buttons["transport"].label, playingLabel)
        app.buttons["transport"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        XCTAssertFalse(app.buttons["mode-live"].exists)
        XCTAssertTrue(app.buttons["tempoDisplay"].exists)
        XCTAssertEqual(app.buttons["mode-menu"].label, "Metronome")
    }
    private func proof(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
