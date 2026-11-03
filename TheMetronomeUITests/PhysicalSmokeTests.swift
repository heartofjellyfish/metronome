import XCTest

/// A small real-device journey that preserves the owner's tempo, sounds and presets.
final class PhysicalSmokeTests: XCTestCase {
    func testLaunchPlaybackAndSettings() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let transport = app.buttons["transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tempoDisplay"].isHittable)
        let stoppedLabel = transport.label
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Physical iPhone home — 1.0.1 (2)"; home.lifetime = .keepAlways; add(home)
        transport.tap()
        let changed = NSPredicate(format: "label != %@", stoppedLabel)
        expectation(for: changed, evaluatedWith: transport)
        waitForExpectations(timeout: 5)
        transport.tap()
        XCTAssertEqual(transport.label, stoppedLabel)
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["all-sounds"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["close-settings"].isHittable)
        app.buttons["close-settings"].tap()
        XCTAssertTrue(app.buttons["tempoDisplay"].isHittable)
        app.terminate()
    }
}
