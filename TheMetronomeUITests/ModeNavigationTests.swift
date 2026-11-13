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
        assertMenuAnchor(app)
        proof(app, "Practice menu anchor")
        app.buttons["mode-live"].tap()
        XCTAssertEqual(app.buttons["settings-transport"].label, playingLabel)
        XCTAssertEqual(app.buttons["mode-menu"].label, "Live")
        proof(app, "Live mode")
        app.buttons["mode-menu"].tap()
        assertMenuAnchor(app)
        proof(app, "Live menu anchor")
        app.buttons["mode-metronome"].tap()
        XCTAssertEqual(app.buttons["transport"].label, playingLabel)
        app.buttons["transport"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        XCTAssertFalse(app.buttons["mode-live"].exists)
        XCTAssertTrue(app.buttons["tempoDisplay"].exists)
        XCTAssertEqual(app.buttons["mode-menu"].label, "Metronome")
    }
    private func assertMenuAnchor(_ app: XCUIApplication) {
        let header = app.buttons["mode-menu"].frame
        let item = app.buttons["mode-metronome"].frame
        XCTAssertLessThan(item.minY - header.maxY, 35)
        XCTAssertGreaterThanOrEqual(item.minY, header.maxY - 1)
        XCTAssertLessThan(abs(item.minX - header.minX), 20)
    }
    private func proof(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
