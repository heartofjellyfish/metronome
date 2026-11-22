import XCTest

/// Launches only: keeps the phone's saved rhythm, sounds and preferences intact.
final class LaunchPerformanceTests: XCTestCase {
    func testLaunchToResponsive() {
        measureLaunch(arguments: [], ready: "mode-menu", screenshot: "Responsive launch")
    }

    #if DEBUG
    func testTunerLaunchToResponsive() {
        measureLaunch(arguments: ["--mode-tuner", "--tuner-test-silent"],
                      ready: "tuner-reference-target", screenshot: "Responsive tuner launch")
    }
    #endif

    func testTunerModeEntryToResponsive() {
        let app = XCUIApplication()
        app.launchArguments = ["-rememberLastSetup", "NO"]
        app.launch()
        app.buttons["mode-menu"].tap()
        let tuner = app.buttons["mode-tuner"]
        XCTAssertTrue(tuner.isHittable)

        let start = ProcessInfo.processInfo.systemUptime
        tuner.tap()
        let target = app.buttons["tuner-reference-target"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: target)
        XCTAssertTrue(target.isHittable || XCTWaiter.wait(for: [ready], timeout: 2) == .completed)
        print("Tuner mode entry including UI automation: \(ProcessInfo.processInfo.systemUptime - start) s")
    }

    private func measureLaunch(arguments: [String], ready: String, screenshot: String) {
        let app = XCUIApplication()
        app.launchArguments = arguments
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
        }
        XCTAssertTrue(app.buttons[ready].waitForExistence(timeout: 1))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screenshot; shot.lifetime = .keepAlways
        add(shot)
    }
}
