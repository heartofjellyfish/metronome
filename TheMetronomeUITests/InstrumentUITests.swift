import XCTest

final class InstrumentUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reference", "--light"]
        app.launch()
    }
    func button(_ name: String) -> XCUIElement {
        // UIKit retains the presenting screen in the query tree beneath a full-screen cover.
        // Scope duplicated shortcuts to the visible surface instead of matching their label alone.
        if ["Time signature", "Subdivision", "presets"].contains(name) {
            let settings = app.buttons["Close settings"]
            let inSettings = settings.exists && settings.isHittable
            switch name {
            case "Time signature": return app.buttons[inSettings ? "settings-meter" : "home-meter"]
            case "Subdivision": return app.buttons[inSettings ? "settings-division" : "home-division"]
            default: return app.buttons[inSettings ? "settings-presets" : "presets"]
            }
        }
        return app.buttons[name]
    }
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
    func openMeter() { button("settings").tap(); button("Time signature").tap() }
    func closeMeterToHome() { button("Close meter").tap(); button("Close settings").tap() }
    func testMetricHierarchyInEvenModeAndGrouping() {
        let labels = (1...4).map { button("beat-\($0)").label }
        proof("Ivory typography hierarchy and recessed lamps")
        button("settings").tap(); button("dynamics-even").tap(); button("Close settings").tap()
        XCTAssertEqual((1...4).map { button("beat-\($0)").label }, labels)
        XCTAssertEqual(button("beat-3").value as? String, "Even sound")
        proof("Even preserves natural hierarchy")
        openTempo(); type("20"); button("panelApply").tap()
        button("transport").tap(); proof("Strong lamp illuminated")
        Thread.sleep(forTimeInterval: 3)
        proof("Weak lamp illuminated")
        Thread.sleep(forTimeInterval: 3)
        proof("Secondary lamp illuminated")
        button("transport").tap()
        openMeter(); button("More meters").tap(); button("5").tap()
        reveal(button("Note value /8")); button("Note value /8").tap()
        reveal(button("2+3")); button("2+3").tap(); proof("Five eight grouping")
        closeMeterToHome()
        XCTAssertTrue(button("beat-3").label.contains("secondary"))
        XCTAssertTrue(button("beat-4").label.contains("weak"))
        openMeter(); button("More meters").tap(); button("2").tap()
        reveal(button("Note value /2")); button("Note value /2").tap(); closeMeterToHome()
        XCTAssertTrue(button("beat-2").exists); XCTAssertFalse(button("beat-3").exists)
        proof("Cut time")
        openMeter(); button("meter-4-4").tap(); button("DARK").tap(); button("Close settings").tap()
        XCTAssertTrue(button("beat-3").label.contains("secondary"))
        proof("Graphite simple home")
    }
    func testCompoundMeterAndStrengthMarks() {
        XCTAssertTrue(button("beat-1").label.contains("strong"))
        XCTAssertTrue(button("beat-3").label.contains("secondary"))
        openMeter(); proof("Common meter one tap choices"); button("meter-6-8").tap()
        XCTAssertFalse(button("Close meter").exists)
        button("Close settings").tap()
        XCTAssertTrue(button("beat-2").label.contains("secondary")); XCTAssertFalse(button("beat-3").exists)
        proof("Six eight two dotted quarter pulses")
        button("settings").tap(); button("Subdivision").tap()
        XCTAssertTrue(button("3 clicks per beat").isSelected)
        proof("Compound subdivision choices")
        button("6 clicks per beat").tap()
        XCTAssertFalse(button("Close division").exists)
        button("Time signature").tap(); button("NOTE UNITS").tap(); button("Close settings").tap()
        XCTAssertTrue(button("beat-4").label.contains("secondary"))
        for n in [2,3,5,6] { XCTAssertTrue(button("beat-\(n)").label.contains("weak")) }
        proof("Six eight strong first secondary fourth")
        button("settings").tap(); button("dynamics-even").tap(); button("Close settings").tap()
        XCTAssertTrue(button("beat-4").label.contains("secondary"))
        button("transport").tap(); XCTAssertEqual(button("transport").label, "Stop metronome"); button("transport").tap()
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(button("beat-6").exists); XCTAssertTrue(button("beat-4").label.contains("secondary"))
        openMeter(); button("meter-12-8").tap(); button("Close settings").tap()
        XCTAssertTrue(button("beat-3").label.contains("secondary"))
        XCTAssertTrue(button("beat-4").exists); XCTAssertFalse(button("beat-5").exists)
    }
    func testSimpleHomeAndImmediateSelections() {
        proof("Simple ivory home")
        XCTAssertTrue(button("Time signature").isHittable)
        button("Time signature").tap(); button("meter-3-4").tap()
        XCTAssertFalse(button("Close meter").exists)
        XCTAssertEqual(button("Time signature").value as? String, "3/4")
        XCTAssertTrue(button("beat-3").exists); XCTAssertFalse(button("beat-4").exists)
        button("Time signature").tap(); button("meter-4-4").tap()
        XCTAssertTrue(button("Subdivision").isHittable)
        XCTAssertTrue(button("presets").isHittable)
        button("transport").tap(); XCTAssertEqual(button("transport").label, "Stop metronome")
        proof("Bright active beat lamp")
        button("transport").tap()
        button("increase").tap(); assertTempo(97)
        button("decrease").tap(); assertTempo(96)
        button("tap").tap()
        button("settings").tap(); proof("Essential settings")
        button("Subdivision").tap(); proof("Immediate subdivision choices")
        XCTAssertFalse(button("panelApply").exists)
        button("3 clicks per beat").tap(); XCTAssertFalse(button("Close division").exists)
        button("Subdivision").tap(); XCTAssertTrue(button("3 clicks per beat").isSelected); button("Close division").tap()
        button("practice").tap(); proof("Progressive practice settings")
        XCTAssertFalse(button("START, 60 BPM").exists)
        button("COUNT IN, OFF").tap(); button("2").tap()
        XCTAssertTrue(button("COUNT IN, 2 BAR").exists)
        XCTAssertFalse(button("Back to practice").exists)
        button("Close practice").tap(); button("Close settings").tap()
        app.terminate(); app.launchArguments = []; app.launch()
        button("settings").tap(); button("practice").tap(); XCTAssertTrue(button("COUNT IN, 2 BAR").exists)
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
        openMeter(); button("More meters").tap(); button("7").tap()
        reveal(button("Note value /8")); button("Note value /8").tap(); proof("Custom meter immediate edits")
        XCTAssertFalse(button("panelApply").exists)
        closeMeterToHome(); XCTAssertTrue(button("beat-7").exists)
        button("settings").tap(); button("Subdivision").tap()
        button("3 clicks per beat").tap()
        button("Subdivision").tap(); XCTAssertTrue(button("3 clicks per beat").isSelected)
        button("Close division").tap()
    }
    func testSettingsPanelsAndDarkPlayback() {
        button("transport").tap(); button("settings").tap(); button("practice").tap()
        button("COUNT IN, OFF").tap(); proof("Count in choices"); button("2").tap()
        XCTAssertTrue(button("COUNT IN, 2 BAR").exists)
        button("RAMP-on").tap()
        reveal(button("EVERY, 8 BARS")); button("EVERY, 8 BARS").tap(); proof("Ramp interval"); button("4").tap()
        reveal(button("INCREASE BY, +2")); button("INCREASE BY, +2").tap(); button("5").tap()
        XCTAssertTrue(button("INCREASE BY, +5").exists)
        button("START, 60 BPM").tap(); type("72"); button("panelApply").tap()
        XCTAssertTrue(button("START, 72 BPM").exists)
        proof("Expanded ramp controls")
        button("Close practice").tap(); button("DARK").tap(); proof("Graphite settings")
        button("Close settings").tap(); XCTAssertEqual(button("transport").label, "Stop metronome")
        openTempo(); proof("Graphite keypad"); button("Close set tempo").tap()
        button("transport").tap(); proof("Graphite main")
    }
    func testRotaryGestureAndPresetPanel() {
        openTempo(); type("300"); button("panelApply").tap()
        let dial = app.otherElements["tempoDial"]
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertFalse(button("tempoDisplay").label.contains("300 BPM"), "Reverse dragging from the upper stop must respond")
        button("settings").tap(); button("presets").tap(); proof("Presets panel")
        let name = app.textFields["NAME THIS RHYTHM"]
        name.tap(); name.typeText("UI RHYTHM")
        button("Save current rhythm").tap()
        XCTAssertTrue(button("Delete UI RHYTHM").waitForExistence(timeout: 3))
        button("Delete UI RHYTHM").tap(); button("DELETE").tap()
        XCTAssertFalse(button("Delete UI RHYTHM").exists)
    }
}
