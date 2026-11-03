import XCTest

final class LocalizationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func journey(_ language: String, stop: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "-AppleLanguages", "(\(language))", "-AppleLocale", language.replacingOccurrences(of: "-", with: "_")]
        app.launch()
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(language)__\(name)"; attachment.lifetime = .keepAlways; add(attachment)
        }
        func reveal(_ id: String) {
            for _ in 0..<6 {
                if app.buttons[id].isHittable { return }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(app.buttons[id].isHittable, id)
        }
        XCTAssertTrue(app.buttons["transport"].waitForExistence(timeout: 5))
        capture("01-home")
        app.buttons["transport"].tap()
        XCTAssertEqual(app.buttons["transport"].label, stop)
        app.buttons["home-meter"].tap()
        app.buttons["meter-3-4"].tap(); app.buttons["meter-6-8"].tap(); app.buttons["meter-4-4"].tap()
        XCTAssertTrue(app.buttons["meter-4-4"].isSelected)
        app.buttons["close-panel"].tap()
        XCTAssertEqual(app.buttons["transport"].label, stop)
        app.buttons["transport"].tap()
        app.buttons["settings"].tap(); app.buttons["all-sounds"].tap()
        app.buttons["acoustic-sound-11"].tap()
        capture("02-sounds")
        app.buttons["acoustic-sound-8"].tap(); app.buttons["acoustic-sound-11"].tap()
        XCTAssertTrue(app.buttons["acoustic-sound-11"].isSelected)
        app.buttons["close-panel"].tap()
        capture("03-accents")
        app.buttons["practice"].tap()
        app.buttons["RAMP-on"].tap()
        app.buttons["practice-countIn"].tap()
        app.buttons["2"].tap()
        XCTAssertTrue(app.buttons["practice-countIn"].exists)
        capture("04-ramp")
        reveal("SOUND / SILENCE-on"); app.buttons["SOUND / SILENCE-on"].tap()
        app.buttons["RAMP-off"].tap()
        capture("05-gap")
        app.buttons["close-panel"].tap()
        // The translated theme control is located by stable identity rather than its wording.
        app.buttons["theme-dark"].tap(); app.buttons["close-settings"].tap()
        capture("06-design")
        app.buttons["settings"].tap(); app.buttons["theme-light"].tap(); app.buttons["close-settings"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["transport"].exists)
    }
    func testEnglish() { journey("en", stop: "Stop metronome") }
    func testSimplifiedChinese() { journey("zh-Hans", stop: "停止播放") }
    func testTraditionalChinese() { journey("zh-Hant", stop: "停止播放") }
    func testJapanese() { journey("ja", stop: "メトロノームを停止") }
    func testKorean() { journey("ko", stop: "메트로놈 정지") }
    func testFrench() { journey("fr", stop: "Arrêter le métronome") }
    func testGerman() { journey("de", stop: "Metronom stoppen") }
    func testSpanish() { journey("es", stop: "Detener metrónomo") }
    func testPortuguese() { journey("pt-BR", stop: "Parar metrônomo") }
}
