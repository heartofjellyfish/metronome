import XCTest

final class LiveModeUITests: XCTestCase {
    func testSettingsTilesAndBluetoothDisplay() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "--light", "--pedal-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["pedal-display-status"].exists)
        capture(app, "Home disconnected")
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["settings-pedal"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        capture(app, "Settings physical tiles")
        for identifier in ["practice", "settings-presets", "settings-pedal", "settings-pedal"] {
            app.buttons[identifier].tap()
            XCTAssertTrue(app.buttons["close-panel"].waitForExistence(timeout: 3))
            app.buttons["close-panel"].tap()
        }
        app.buttons["theme-dark"].tap()
        capture(app, "Settings physical tiles dark")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--pedal-ui-test", "--pedal-fixture-bluetooth"]
        app.launch()
        let status = app.buttons["pedal-display-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        capture(app, "Home Bluetooth fixture")
        status.tap()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 3))
        app.buttons["close-panel"].tap()
        app.buttons["transport"].tap()
        status.tap()
        app.buttons["close-panel"].tap()
        XCTAssertEqual(app.buttons["transport"].label, "Stop metronome")
        app.buttons["transport"].tap()
    }
    func testLearningAvailableWithoutConnectionAndBackgroundCancels() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--panel=pedal", "--pedal-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["pedal-tab-connect"].exists)
        for action in ["toggle", "tap", "next", "previous", "faster", "slower"] {
            XCTAssertTrue(app.buttons["pedal-\(action)"].isEnabled)
        }
        capture(app, "Direct assignment without device")
        app.buttons["pedal-toggle"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learning")
        capture(app, "Direct learning")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["pedal-toggle"].tap()
        app.buttons["pedal-tap"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        XCTAssertEqual(app.buttons["pedal-tap"].value as? String, "Learning")
        app.buttons["pedal-tap"].tap()
        XCTAssertEqual(app.buttons["pedal-tap"].value as? String, "Learn")
    }
    func testSixActionsLearningCancellationAndPlaybackRemainAccessible() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--pedal-ui-test", "--pedal-fixture-input"]
        app.launch()
        let transport = app.buttons["transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 8))
        transport.tap()
        app.buttons["settings"].tap()
        app.buttons["settings-pedal"].tap()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 5))
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
        app.buttons["pedal-toggle"].tap()
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
        app.buttons["pedal-toggle"].tap()
        app.buttons["close-panel"].tap(); app.buttons["settings-pedal"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Start metronome")
    }
    func testLocalizedStatesAndRebindCancellationPreserveAssignment() {
        for language in ["zh-Hans", "de", "en"] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "--light", "--panel=pedal", "--pedal-ui-test", "--pedal-fixture-bound", "--pedal-fixture-input"]
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
            XCTAssertFalse(app.images["checkmark"].exists)
            XCTAssertTrue(app.buttons["pedal-midi"].exists)
            capture(app, "Assignments — \(language)")
            app.terminate()
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
