import XCTest

final class LiveModeUITests: XCTestCase {
    func testSixActionsLearningCancellationAndPlaybackRemainAccessible() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light"]
        app.launch()
        let transport = app.buttons["transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 8))
        transport.tap()
        app.buttons["settings"].tap()
        app.buttons["settings-pedal"].tap()
        for action in ["next", "previous", "faster", "slower", "toggle", "tap"] {
            XCTAssertTrue(app.buttons["pedal-\(action)"].waitForExistence(timeout: 2))
        }
        for action in ["toggle", "next", "tap"] {
            app.buttons["pedal-\(action)"].tap()
            XCTAssertTrue(app.staticTexts["Press now…"].exists)
            app.buttons["Cancel"].tap()
            XCTAssertFalse(app.staticTexts["Press now…"].exists)
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Live Mode — six actions"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["close-panel"].tap()
        app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Stop metronome")
        transport.tap()
        app.buttons["settings"].tap(); app.buttons["settings-pedal"].tap()
        app.buttons["pedal-toggle"].tap()
        app.buttons["close-panel"].tap()
        app.buttons["settings-pedal"].tap()
        XCTAssertFalse(app.staticTexts["Press now…"].exists)
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Start metronome")
    }
    func testChineseAndGermanLiveModeLayout() {
        for language in ["zh-Hans", "de"] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "--light", "--panel=pedal"]
            app.launch()
            XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["pedal-tap"].isHittable)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Live Mode — \(language)"; shot.lifetime = .keepAlways; add(shot)
            app.terminate()
        }
    }
}
