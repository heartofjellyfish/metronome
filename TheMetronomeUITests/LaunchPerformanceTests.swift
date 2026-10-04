import XCTest

/// Launches only: keeps the phone's saved rhythm, sounds and preferences intact.
final class LaunchPerformanceTests: XCTestCase {
    func testLaunchToResponsive() {
        let app = XCUIApplication()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
        }
        XCTAssertTrue(app.buttons["transport"].waitForExistence(timeout: 1))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Responsive launch"; shot.lifetime = .keepAlways
        add(shot)
    }
}
