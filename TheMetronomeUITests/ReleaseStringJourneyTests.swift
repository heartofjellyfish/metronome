import XCTest

final class ReleaseStringJourneyTests: XCTestCase {
    private func tune(_ instrument: String, strings: Int, pairs: Bool = false) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mode-tuner", "--light", "--tuner-instrument=" + instrument,
                               "--tuner-test-silent", "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
        app.launch()
        defer { app.terminate() }
        let first = app.buttons["tuner-string-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), instrument)
        for index in 0..<strings {
            let string = app.buttons["tuner-string-\(index)"]
            XCTAssertTrue(string.isHittable, "\(instrument), string index \(index)")
            if instrument == "12-string guitar" && [9, 11].contains(index) {
                XCTAssertNotEqual(string.value as? String, "In tune", "Its unison partner was tuned independently")
            }
            string.tap()
            if pairs {
                let partner = app.buttons["tuner-course-\(index)-wire-1"]
                XCTAssertNotEqual(partner.value as? String, "In tune")
                XCTAssertNotEqual(string.value as? String, "In tune")
                partner.tap()
            }
            XCTAssertEqual(string.value as? String, "In tune", "\(instrument), index \(index)")
        }
        for index in 0..<strings {
            XCTAssertEqual(app.buttons["tuner-string-\(index)"].value as? String, "In tune", instrument)
        }
        let photo = XCTAttachment(screenshot: app.screenshot())
        photo.name = instrument
        photo.lifetime = .keepAlways
        add(photo)
    }

    func testGuitars() throws {
        try tune("Guitar", strings: 6)
        try tune("7-string guitar", strings: 7)
        try tune("12-string guitar", strings: 12)
    }

    func testBasses() throws {
        try tune("Bass", strings: 4)
        try tune("5-string bass", strings: 5)
        try tune("6-string bass", strings: 6)
    }

    func testUkuleles() throws {
        try tune("Ukulele", strings: 4)
        try tune("Baritone ukulele", strings: 4)
    }

    func testBowedStrings() throws {
        for instrument in ["Violin", "Viola", "Cello", "Double bass"] {
            try tune(instrument, strings: 4)
        }
    }

    func testBanjoAndMandolin() throws {
        try tune("5-string banjo", strings: 5)
        try tune("Mandolin", strings: 4, pairs: true)
    }
}
