import XCTest

/// Real iPhone checks. No artificial calls, alarms or claims about audible continuity.
final class PhysicalLiveModeTests: XCTestCase {
    func testBackgroundPlaybackAndLiveSettings() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let transport = app.buttons["transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 8))
        let stoppedLabel = transport.label
        transport.tap()
        let started = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", stoppedLabel), object: transport)
        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 5), .completed, app.debugDescription)
        let runningLabel = transport.label
        XCTAssertNotEqual(stoppedLabel, runningLabel)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 30)
        app.activate()
        // SpringBoard's return animation can outlive the app's idle report on a physical phone.
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(transport.label, runningLabel)
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Returned from background"; before.lifetime = .keepAlways; add(before)
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["settings-pedal"].waitForExistence(timeout: 5))
        app.buttons["settings-pedal"].tap()
        for action in ["next", "previous", "faster", "slower", "toggle", "tap"] {
            XCTAssertTrue(app.buttons["pedal-\(action)"].exists)
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Physical iPhone Live Mode 1.0.2 (3)"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        transport.tap(); XCTAssertEqual(transport.label, stoppedLabel)
    }
}
