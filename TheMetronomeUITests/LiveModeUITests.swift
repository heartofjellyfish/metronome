import XCTest

final class LiveModeUITests: XCTestCase {
    func testSixActionsLearningCancellationAndPlaybackRemainAccessible() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--pedal-ui-test"]
        app.launch()
        let transport = app.buttons["transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 8))
        transport.tap()
        app.buttons["settings"].tap()
        app.buttons["settings-pedal"].tap()
        XCTAssertTrue(app.buttons["pedal-tab-connect"].waitForExistence(timeout: 5))
        app.buttons["pedal-tab-connect"].tap()
        XCTAssertTrue(app.buttons["pedal-midi"].waitForExistence(timeout: 5))
        app.buttons["pedal-tab-bind"].tap()
        for action in ["next", "previous", "faster", "slower", "toggle", "tap"] {
            XCTAssertTrue(app.buttons["pedal-\(action)"].waitForExistence(timeout: 2))
        }
        let row = app.buttons["pedal-tap"].frame
        for action in ["toggle", "next", "tap"] {
            let key = app.buttons["pedal-\(action)"]
            key.tap()
            XCTAssertEqual(key.value as? String, "Learning")
            XCTAssertEqual(app.buttons["pedal-tap"].frame.minY, row.minY, accuracy: 1)
            key.tap()
            XCTAssertEqual(key.value as? String, "Learn")
        }
        app.buttons["pedal-toggle"].tap()
        app.buttons["pedal-tab-connect"].tap()
        app.buttons["pedal-tab-bind"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["pedal-preparation"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Avoid call interruptions"].exists)
        app.swipeDown()
        app.buttons["pedal-preparation"].tap()
        XCTAssertFalse(app.staticTexts["Avoid call interruptions"].exists)
        XCTAssertTrue(app.buttons["pedal-toggle"].isHittable)
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Stop metronome")
        transport.tap()
        app.buttons["settings"].tap(); app.buttons["settings-pedal"].tap()
        app.buttons["pedal-tab-bind"].tap(); app.buttons["pedal-toggle"].tap()
        app.buttons["close-panel"].tap(); app.buttons["settings-pedal"].tap()
        app.buttons["pedal-tab-bind"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Start metronome")
    }
    func testLocalizedStatesAndRebindCancellationPreserveAssignment() {
        for language in ["zh-Hans", "de", "en"] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "--light", "--panel=pedal", "--pedal-ui-test", "--pedal-fixture-bound"]
            app.launch()
            let key = app.buttons["pedal-toggle"]
            XCTAssertTrue(key.waitForExistence(timeout: 8))
            let assigned = key.value as? String
            capture(app, "Cassette bound — \(language)")
            key.tap()
            XCTAssertNotEqual(key.value as? String, assigned)
            capture(app, "Cassette learning — \(language)")
            key.tap(); XCTAssertEqual(key.value as? String, assigned)
            app.buttons["pedal-preparation"].tap(); app.swipeUp()
            capture(app, "Preparation — \(language)")
            app.swipeDown(); app.buttons["pedal-preparation"].tap()
            app.buttons["pedal-tab-connect"].tap()
            capture(app, "Connection — \(language)")
            app.terminate()
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
