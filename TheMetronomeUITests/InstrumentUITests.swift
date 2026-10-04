import XCTest

final class InstrumentUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reference", "--light"]
        app.launch()
    }
    func button(_ name: String) -> XCUIElement { app.buttons[name] }
    func openTempo() { button("tempoDisplay").tap(); XCTAssertTrue(button("key-1").waitForExistence(timeout: 3)) }
    func type(_ value: String) { for character in value { button("key-\(character)").tap() } }
    func assertTempo(_ value: Int) { XCTAssertTrue(button("tempoDisplay").label.contains("\(value) BPM"), button("tempoDisplay").label) }
    func proof(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    func testCompoundMeterAndStrengthMarks() {
        XCTAssertTrue(button("beat-1").label.contains("strong"))
        XCTAssertTrue(button("beat-3").label.contains("secondary"))
        proof("Four beats with subtle strength marks")
        button("Time signature").tap()
        button("6").tap(); button("♪  /8").tap()
        proof("Compound meter selector")
        let commit = button("SET METER"); reveal(commit); commit.tap()
        XCTAssertTrue(button("beat-2").exists); XCTAssertFalse(button("beat-3").exists)
        proof("Six eight two dotted quarter pulses")
        button("Subdivision").tap()
        XCTAssertTrue(button("3 clicks per beat").isSelected)
        proof("Compound subdivision choices")
        button("6 clicks per beat").tap(); button("SET DIVISION").tap()
        button("transport").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("transport").tap()
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertFalse(button("beat-3").exists)
        button("Time signature").tap(); button("12").tap(); reveal(button("SET METER")); button("SET METER").tap()
        XCTAssertTrue(button("beat-3").label.contains("secondary"))
        XCTAssertTrue(button("beat-4").exists); XCTAssertFalse(button("beat-5").exists)
        proof("Twelve eight grouped accents")
    }
    func testDynamicsControlAndPersistence() {
        button("settings").tap()
        XCTAssertTrue(button("dynamics-meter").isSelected)
        button("dynamics-even").tap()
        XCTAssertTrue(button("dynamics-even").isSelected)
        button("recommended-sound-11").tap()
        XCTAssertTrue(button("dynamics-even").isSelected)
        proof("Even dynamics settings")
        button("All sounds").tap()
        XCTAssertTrue(button("library-dynamics-even").isSelected)
        button("library-dynamics-meter").tap(); proof("Meter dynamics library")
        button("Close sound library").tap()
        XCTAssertTrue(button("dynamics-meter").isSelected)
        button("dynamics-even").tap(); button("Close settings").tap()
        app.terminate(); app.launchArguments = []; app.launch()
        button("settings").tap(); XCTAssertTrue(button("dynamics-even").isSelected)
        button("Close settings").tap(); button("transport").tap()
        button("settings").tap(); button("dynamics-meter").tap(); button("DARK").tap()
        proof("Graphite dynamics settings")
        button("Close settings").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("transport").tap()
    }
    func testAcousticLibraryAndPersistence() {
        button("settings").tap()
        for index in [11, 0, 1] { XCTAssertTrue(button("recommended-sound-\(index)").isHittable) }
        XCTAssertFalse(button("Next sound bank").exists)
        button("recommended-sound-11").tap()
        XCTAssertTrue(button("recommended-sound-11").isSelected)
        proof("Recommended sounds")
        button("All sounds").tap()
        XCTAssertTrue(button("picks-sound-11").isSelected)
        proof("Expanded sound library")
        for index in [11,8,5,9,10] {
            let sound = button("acoustic-sound-\(index)")
            reveal(sound); sound.tap(); XCTAssertTrue(sound.isSelected)
            XCTAssertFalse(button("Close audio output").exists)
        }
        proof("Expanded acoustic family")
        button("Close sound library").tap()
        button("DARK").tap()
        button("All sounds").tap(); proof("Graphite sound library")
        let shaker = button("acoustic-sound-10"); reveal(shaker)
        XCTAssertTrue(shaker.isSelected)
        button("Close sound library").tap(); button("Close settings").tap()
        app.terminate(); app.launchArguments = []; app.launch()
        button("settings").tap(); button("All sounds").tap()
        reveal(button("acoustic-sound-10")); XCTAssertTrue(button("acoustic-sound-10").isSelected)
        button("Close sound library").tap()
        button("recommended-sound-11").tap()
        button("Close settings").tap(); button("transport").tap()
        button("settings").tap(); button("recommended-sound-0").tap()
        button("recommended-sound-11").tap(); button("Close settings").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("transport").tap()
    }
    func testPercussionLibrarySelectionAndPlayback() {
        button("settings").tap(); button("All sounds").tap()
        XCTAssertFalse(button("acoustic-sound-6").exists)
        XCTAssertFalse(button("electronic-sound-3").exists)
        for index in [11,8,5,9,10] {
            let sound = button("acoustic-sound-\(index)")
            reveal(sound); sound.tap(); XCTAssertTrue(sound.isSelected)
        }
        proof("Curated acoustic library")
        for index in [0,1,2] {
            let sound = button("classic-sound-\(index)")
            reveal(sound); sound.tap(); XCTAssertTrue(sound.isSelected)
        }
        button("Close sound library").tap(); button("Close settings").tap()
        button("transport").tap(); button("settings").tap(); button("All sounds").tap()
        button("acoustic-sound-5").tap()
        button("Close sound library").tap(); button("Close settings").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("transport").tap()
    }
    func testNumericEntryValidationCancelAndEndpoints() {
        proof("Ivory main")
        openTempo(); proof("Tempo keypad")
        type("9"); XCTAssertFalse(button("panelApply").isEnabled)
        button("key-CLR").tap(); type("301"); XCTAssertFalse(button("panelApply").isEnabled)
        button("key-⌫").tap(); type("0"); button("panelApply").tap(); assertTempo(300)
        openTempo(); type("20"); button("Close set tempo").tap(); assertTempo(300)
        openTempo(); type("20"); button("panelApply").tap(); assertTempo(20)
        button("decrease").tap(); assertTempo(20)
        button("increase").tap(); assertTempo(21)
    }
    func testMeterAndSubdivisionAreCustomAndApply() {
        button("Time signature").tap()
        XCTAssertTrue(button("SET METER").waitForExistence(timeout: 3))
        button("7").tap(); button("♪  /8").tap(); proof("Meter panel")
        button("panelApply").tap()
        XCTAssertTrue(button("beat-7").exists)
        button("Subdivision").tap()
        button("3 clicks per beat").tap(); proof("Division panel"); button("panelApply").tap()
        button("Subdivision").tap()
        XCTAssertTrue(button("3 clicks per beat").isSelected)
        button("Close division").tap()
    }
    func testSettingsPanelsAndDarkPlayback() {
        button("transport").tap()
        button("settings").tap()
        button("COUNT IN, 1 BAR").tap(); button("2").tap(); proof("Count in panel"); button("panelApply").tap()
        XCTAssertTrue(button("COUNT IN, 2 BAR").exists)
        button("EVERY, 8 BARS").tap(); button("4").tap(); proof("Ramp interval"); button("panelApply").tap()
        button("INCREASE BY, +2").tap(); button("5").tap(); proof("Ramp increment"); button("panelApply").tap()
        button("Edit ramp start and end").tap(); proof("Practice panel")
        button("START, 60 BPM").tap(); type("72"); button("panelApply").tap()
        XCTAssertTrue(button("START, 72 BPM").exists)
        button("DONE").tap()
        button("DARK").tap(); proof("Graphite settings")
        button("Close settings").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        openTempo(); proof("Graphite keypad"); button("Close set tempo").tap()
        button("transport").tap()
        proof("Graphite main")
    }
    func testRotaryGestureAndPresetPanel() {
        openTempo(); type("300"); button("panelApply").tap()
        let dial = app.otherElements["tempoDial"]
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertFalse(button("tempoDisplay").label.contains("300 BPM"), "Reverse dragging from the upper stop must respond")
        button("presets").tap(); proof("Presets panel")
        let name = app.textFields["NAME THIS RHYTHM"]
        name.tap(); name.typeText("UI RHYTHM")
        button("Save current rhythm").tap()
        XCTAssertTrue(button("Delete UI RHYTHM").waitForExistence(timeout: 3))
        button("Delete UI RHYTHM").tap(); button("DELETE").tap()
        XCTAssertFalse(button("Delete UI RHYTHM").exists)
    }
}
