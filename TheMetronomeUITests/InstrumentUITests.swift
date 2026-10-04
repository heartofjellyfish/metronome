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
        XCTAssertTrue(button("acoustic-sound-11").isSelected)
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
        reveal(button("STEP, 2 BPM")); button("STEP, 2 BPM").tap(); button("5").tap()
        XCTAssertTrue(button("STEP, 5 BPM").exists)
        button("START, 60 BPM").tap(); type("72"); button("panelApply").tap()
        XCTAssertTrue(button("START, 72 BPM").exists)
        proof("Expanded ramp controls")
        button("Close practice").tap(); button("DARK").tap(); proof("Graphite settings")
        button("Close settings").tap(); XCTAssertEqual(button("transport").label, "Stop metronome")
        openTempo(); proof("Graphite keypad"); button("Close set tempo").tap()
        button("transport").tap(); proof("Graphite main")
    }
    func testRotaryGestureAndPresetPanel() {
        XCTAssertTrue(button("tempoDisplay").waitForExistence(timeout: 3))
        proof("Ivory dial position at 96")
        openTempo(); type("20"); button("panelApply").tap()
        proof("Dial position at minimum")
        openTempo(); type("300"); button("panelApply").tap()
        proof("Dial position at maximum")
        let dial = app.otherElements["tempoDial"]
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertFalse(button("tempoDisplay").label.contains("300 BPM"), "Reverse dragging from the upper stop must respond")
        proof("Dial position after reverse drag")
        let beforeForward = button("tempoDisplay").label
        button("transport").tap()
        end.press(forDuration: 0.1, thenDragTo: start)
        XCTAssertNotEqual(button("tempoDisplay").label, beforeForward)
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(button("transport").label, "Stop metronome")
        proof("Dial position during repeated live adjustment")
        button("settings").tap(); button("DARK").tap(); button("Close settings").tap()
        proof("Graphite dial position during playback")
        button("transport").tap()
        button("settings").tap(); button("presets").tap(); proof("Presets panel")
        let name = app.textFields["NAME THIS RHYTHM"]
        name.tap(); name.typeText("UI RHYTHM")
        button("Save current rhythm").tap()
        XCTAssertTrue(button("Delete UI RHYTHM").waitForExistence(timeout: 3))
        button("Delete UI RHYTHM").tap(); button("DELETE").tap()
        XCTAssertFalse(button("Delete UI RHYTHM").exists)
    }
    func testPresetNamePersistenceLoadEditAndDelete() {
        button("presets").tap()
        let name = app.textFields["NAME THIS RHYTHM"]
        name.tap(); name.typeText("AUDIT PRESET")
        button("Save current rhythm").tap(); button("Close presets").tap()
        XCTAssertTrue((button("presets").value as? String ?? "").contains("AUDIT PRESET"))
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue((button("presets").value as? String ?? "").contains("AUDIT PRESET"))
        button("increase").tap()
        XCTAssertEqual(button("presets").value as? String, "CUSTOM RHYTHM / SAVE")
        button("presets").tap(); button("load-preset-AUDIT PRESET").tap()
        assertTempo(96)
        button("presets").tap(); button("Delete AUDIT PRESET").tap(); button("KEEP").tap()
        XCTAssertTrue(button("Delete AUDIT PRESET").exists)
        button("Delete AUDIT PRESET").tap(); button("DELETE").tap(); button("Close presets").tap()
        XCTAssertEqual(button("presets").value as? String, "PRESETS / SAVE A RHYTHM")
    }
    func testGapControlsHapticsAndTupletNotation() {
        button("Subdivision").tap(); proof("Simple triplet numeral")
        button("3 clicks per beat").tap(); proof("Home triplet numeral")
        button("Time signature").tap(); button("meter-6-8").tap()
        button("Subdivision").tap(); proof("Compound duplet numeral")
        button("2 clicks per beat").tap()
        button("settings").tap(); button("practice").tap()
        button("SOUND / SILENCE-on").tap()
        reveal(button("Increase SOUND BARS")); button("Increase SOUND BARS").tap()
        button("Decrease SILENT BARS").tap()
        button("Decrease SILENT BARS").tap() // lower limit holds at one
        reveal(button("TOUCH FEEDBACK-off")); button("TOUCH FEEDBACK-off").tap()
        XCTAssertTrue(button("TOUCH FEEDBACK-off").isSelected)
        proof("Gap training and touch feedback")
        button("Close practice").tap(); button("Close settings").tap()
        app.terminate(); app.launchArguments = []; app.launch()
        button("settings").tap(); button("practice").tap()
        XCTAssertTrue(button("SOUND / SILENCE-on").isSelected)
        reveal(button("TOUCH FEEDBACK-off")); XCTAssertTrue(button("TOUCH FEEDBACK-off").isSelected)
        button("TOUCH FEEDBACK-on").tap()
    }

    func testLiveDivisionAndMeterComparisonKeepsContext() {
        button("transport").tap()
        button("Subdivision").tap()
        for division in [2,3,4,1] {
            button("\(division) clicks per beat").tap()
            XCTAssertTrue(button("Close division").isHittable)
            XCTAssertTrue(button("\(division) clicks per beat").isSelected)
            for other in [1,2,3,4] where other != division {
                XCTAssertFalse(button("\(other) clicks per beat").isSelected)
            }
        }
        for duplicate in ["01","02","03","04","1 / BEAT","2 / BEAT","3 / BEAT","4 / BEAT"] {
            XCTAssertFalse(app.staticTexts[duplicate].exists)
        }
        proof("Live division clean labels and current selection")
        button("Close division").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("Time signature").tap()
        for meter in ["meter-3-4","meter-6-8"] {
            button(meter).tap(); XCTAssertTrue(button("Close meter").isHittable)
            XCTAssertTrue(button(meter).isSelected)
        }
        button("NOTE UNITS").tap(); XCTAssertTrue(button("NOTE UNITS").isSelected)
        button("BIG BEATS").tap(); XCTAssertTrue(button("BIG BEATS").isSelected)
        button("Close meter").tap()
        button("settings").tap(); button("DARK").tap(); button("Subdivision").tap()
        for division in [2,6,3,1] {
            button("\(division) clicks per beat").tap()
            XCTAssertTrue(button("Close division").isHittable)
            XCTAssertTrue(button("\(division) clicks per beat").isSelected)
        }
        proof("Live compound division graphite")
        button("Close division").tap(); button("Close settings").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("Subdivision").tap(); XCTAssertTrue(button("1 clicks per beat").isSelected)
        button("Close division").tap(); button("transport").tap()
        // Stopped setup keeps the existing one-tap return to the instrument.
        button("Subdivision").tap(); button("3 clicks per beat").tap()
        XCTAssertFalse(button("Close division").exists)
    }
    func testLivePresetComparisonAndUniqueSoundLibrary() {
        for (name, bpm) in [("LIVE A",96),("LIVE B",120)] {
            openTempo(); type(String(bpm)); button("panelApply").tap()
            button("presets").tap()
            let field = app.textFields["NAME THIS RHYTHM"]
            field.tap(); field.typeText(name); button("Save current rhythm").tap()
            button("Close presets").tap()
        }
        button("transport").tap(); button("presets").tap()
        for name in ["LIVE A","LIVE B","LIVE A"] {
            button("load-preset-\(name)").tap()
            XCTAssertTrue(button("Close presets").isHittable)
            XCTAssertTrue(button("load-preset-\(name)").isSelected)
            let other = name == "LIVE A" ? "LIVE B" : "LIVE A"
            XCTAssertFalse(button("load-preset-\(other)").isSelected)
        }
        proof("Live preset comparison with selection lamp")
        button("Close presets").tap(); assertTempo(96)
        XCTAssertEqual(button("transport").label,"Stop metronome")
        button("transport").tap(); button("presets").tap()
        for name in ["LIVE A","LIVE B"] {
            button("Delete \(name)").tap(); button("DELETE").tap()
        }
        button("Close presets").tap()
        button("settings").tap()
        for sound in [11,0,1] { XCTAssertTrue(button("recommended-sound-\(sound)").exists) }
        button("All sounds").tap()
        XCTAssertFalse(button("picks-sound-11").exists)
        for (family,sounds) in [("acoustic",[11,8,5,9,10,12,13,14,15]),("classic",[0,1,2])] {
            for sound in sounds { XCTAssertEqual(app.buttons.matching(identifier:"\(family)-sound-\(sound)").count,1) }
        }
        proof("Full sound library without duplicate recommendations")
    }

    func testDivisionNotationProportions() {
        for division in [1,2,3,4] {
            button("Subdivision").tap(); proof("Simple division choices")
            button("\(division) clicks per beat").tap()
            XCTAssertFalse(button("Close division").exists)
            proof("Simple home division \(division)")
        }
        button("Time signature").tap(); button("meter-6-8").tap()
        button("settings").tap(); button("DARK").tap(); button("Close settings").tap()
        button("transport").tap()
        for division in [1,2,3,6] {
            button("Subdivision").tap(); button("\(division) clicks per beat").tap()
            XCTAssertTrue(button("\(division) clicks per beat").isSelected)
            proof("Compound division choices")
            button("Close division").tap()
            XCTAssertEqual(button("transport").label, "Stop metronome")
            proof("Compound home division \(division)")
        }
        button("Time signature").tap(); button("NOTE UNITS").tap(); button("Close meter").tap()
        for division in [1,2,3,4] {
            button("Subdivision").tap(); button("\(division) clicks per beat").tap()
            proof("Note units choices \(division)")
            button("Close division").tap(); proof("Note units home \(division)")
        }
        button("transport").tap()
    }

    func testDarkTransportHierarchy() {
        button("settings").tap(); button("DARK").tap(); button("Close settings").tap()
        proof("Graphite primary play key")
        for _ in 0..<3 {
            button("transport").tap()
            XCTAssertEqual(button("transport").label, "Stop metronome")
            proof("Graphite primary stop key")
            button("transport").tap()
            XCTAssertEqual(button("transport").label, "Start metronome")
        }
        for _ in 0..<3 { button("tap").tap() }
        XCTAssertEqual(button("transport").label, "Start metronome")
        button("settings").tap(); button("LIGHT").tap(); button("Close settings").tap()
        proof("Ivory original transport hierarchy")
    }

    func testCurrentSoundRemainsVisibleInSettings() {
        button("settings").tap()
        button("recommended-sound-11").tap()
        XCTAssertEqual(button("All sounds").value as? String, "HI-HAT")
        for playing in [false, true] {
            if playing {
                button("Close settings").tap(); button("transport").tap(); button("settings").tap()
            }
            button("All sounds").tap()
            for id in [12,13,15] {
                let sound = button("acoustic-sound-\(id)")
                reveal(sound); sound.tap()
                XCTAssertTrue(sound.isSelected)
                XCTAssertTrue(button("Close sound library").isHittable)
            }
            button("Close sound library").tap()
            XCTAssertEqual(button("All sounds").value as? String, "CROSS-STICK")
            proof(playing ? "Current sound during playback" : "Current sound ivory")
            button("All sounds").tap()
            reveal(button("acoustic-sound-15")); XCTAssertTrue(button("acoustic-sound-15").isSelected)
            button("Close sound library").tap()
            button("Close settings").tap()
            XCTAssertEqual(button("transport").label, playing ? "Stop metronome" : "Start metronome")
            button("settings").tap()
            XCTAssertEqual(button("All sounds").value as? String, "CROSS-STICK")
            button("recommended-sound-0").tap()
            XCTAssertEqual(button("All sounds").value as? String, "WOOD")
        }
        button("DARK").tap(); proof("Current sound graphite")
        button("Close settings").tap(); button("transport").tap()
    }

    func testNewPercussionLiveSelection() {
        button("transport").tap()
        button("settings").tap()
        reveal(button("All sounds")); button("All sounds").tap()
        for id in [15,14,12,13,12] {
            let sound = button("acoustic-sound-\(id)")
            reveal(sound); sound.tap()
            XCTAssertTrue(sound.isSelected)
            XCTAssertTrue(button("Close sound library").exists)
        }
        proof("Expanded percussion library")
        button("Close sound library").tap()
        button("Close settings").tap()
        XCTAssertEqual(button("transport").label, "Stop metronome")
        button("transport").tap()
    }

}
