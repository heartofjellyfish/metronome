import UIKit
import XCTest

final class TunerUITests: XCTestCase {
    func testTunerJourneyAndRealAudioSession() {
        let app = XCUIApplication()
        app.launchArguments = ["--light","-AppleLanguages","(en)"]
        app.launch()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-tuner"].tap()
        let allowMicrophone = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .alerts["kTCCServiceMicrophone-alert"].buttons["kTCCServiceMicrophone-allow-button"].firstMatch
        if allowMicrophone.exists { allowMicrophone.tap() }
        XCTAssertTrue(inputReady(app).waitForExistence(timeout: 10))
        app.buttons["tuner-instruments"].tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        XCTAssertTrue(app.buttons["tuner-string-2"].waitForExistence(timeout: 5))
        proof(app, "Guitar before plucking")
        app.buttons["tuner-string-2"].tap()
        XCTAssertTrue(app.buttons["tuner-string-2"].isSelected)
        app.buttons["tuner-string-4"].tap()
        XCTAssertTrue(app.buttons["tuner-string-4"].isSelected)
        proof(app, "Guitar strings")
        app.buttons["tuner-string-4"].tap()
        app.buttons["tuner-instruments"].tap()
        XCTAssertFalse(app.textFields["Search instruments"].exists)
        let woodwinds = app.scrollViews["tuner-lane-Woodwinds"]
        XCTAssertTrue(woodwinds.isHittable)
        let windNames = ["B♭ clarinet", "Flute", "Piccolo", "Oboe", "English horn", "Bassoon", "Recorder",
                         "A clarinet", "Bass clarinet", "Soprano sax", "Alto sax", "Tenor sax", "Baritone sax"]
        func fullyVisible(_ button: XCUIElement) -> Bool {
            let lane = woodwinds.frame.insetBy(dx: -2, dy: 0)
            return button.isHittable && lane.minX <= button.frame.minX && button.frame.maxX <= lane.maxX
        }
        for _ in 0..<6 where !fullyVisible(app.buttons["tuner-profile-Alto sax"]) {
            woodwinds.swipeLeft(velocity: .slow)
            let visible = windNames.map { app.buttons["tuner-profile-" + $0] }.filter(fullyVisible)
            XCTAssertEqual(visible.count, 4)
            if let first = visible.first {
                XCTAssertEqual(first.frame.minX, woodwinds.frame.minX, accuracy: 2)
            }
        }
        XCTAssertTrue(fullyVisible(app.buttons["tuner-profile-Alto sax"]))
        proof(app, "Woodwinds scrolled")
        let lastWind = app.buttons["tuner-profile-Baritone sax"]
        for _ in 0..<3 where !fullyVisible(lastWind) {
            woodwinds.swipeLeft(velocity: .slow)
        }
        XCTAssertTrue(fullyVisible(lastWind))
        XCTAssertTrue(fullyVisible(app.buttons["tuner-profile-Alto sax"]))
        proof(app, "Woodwinds at end")
        app.buttons["tuner-profile-Alto sax"].tap()
        XCTAssertTrue(app.buttons["tuner-profile-Alto sax"].waitForNonExistence(timeout: 4))
        app.buttons["tuner-instruments"].tap()
        XCTAssertTrue(app.buttons["tuner-profile-Alto sax"].isSelected)
        XCTAssertTrue(app.buttons["tuner-profile-Alto sax"].isHittable)
        app.buttons["Close"].tap()
        let settings = app.buttons["settings"]
        XCTAssertTrue(waitUntilHittable(settings))
        settings.tap()
        let concert = app.buttons["tuner-pitch-concert"]
        XCTAssertTrue(waitUntilHittable(concert))
        concert.tap()
        XCTAssertTrue(concert.isSelected)
        app.buttons["tuner-pitch-written"].tap()
        XCTAssertTrue(app.buttons["tuner-pitch-written"].isSelected)
        app.buttons["tuner-reference-up"].tap()
        app.buttons["tuner-reference-down"].tap()
        app.buttons["tuner-response-steady"].tap()
        XCTAssertTrue(app.buttons["tuner-response-steady"].isSelected)
        app.buttons["tuner-response-balanced"].tap()
        XCTAssertTrue(app.buttons["tuner-response-balanced"].isSelected)
        XCTAssertFalse(app.buttons["all-sounds"].exists)
        proof(app, "Tuner settings")
        app.buttons["close-settings"].tap()
        XCTAssertTrue(app.buttons["close-settings"].waitForNonExistence(timeout: 4))
        XCTAssertFalse(app.buttons["tuner-reference-notes"].exists)
        XCTAssertFalse(app.buttons["Reference tone"].exists)
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["all-sounds"].exists)
        XCTAssertFalse(app.buttons["tuner-response-steady"].exists)
        app.buttons["close-settings"].tap()
        app.buttons["transport"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-tuner"].tap()
        XCTAssertTrue(app.buttons["Pause click to tune"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["tuner-instruments"].label.contains("Chromatic"))
        app.buttons["tuner-instruments"].tap()
        pickInstrument("Bass", layout: "bass", in: app)
        XCTAssertTrue(app.buttons["Pause click to tune"].exists)
        app.buttons["Pause click to tune"].tap()
        XCTAssertTrue(app.buttons["tuner-string-3"].waitForExistence(timeout: 4))
    }
    func testWoodwindFaceMatchesGuitarAlignmentWithoutExtraControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Flute", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()

        let title = app.buttons["tuner-note-options"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Flute")
        let instrumentButton = app.buttons["tuner-instruments"]
        XCTAssertEqual(instrumentButton.label, "Flute")
        XCTAssertEqual(instrumentButton.frame.midY, app.buttons["settings"].frame.midY, accuracy: 1)
        let needle = app.descendants(matching: .any)["tuner-needle-meter"].firstMatch
        let note = app.descendants(matching: .any)["tuner-note-readout"].firstMatch
        XCTAssertTrue(note.exists)
        XCTAssertEqual(note.label, "A4")
        XCTAssertFalse(app.staticTexts["tuner-secondary-note-readout"].exists)
        XCTAssertLessThan(needle.frame.minY, note.frame.minY)
        XCTAssertLessThan(note.frame.maxY, title.frame.minY)
        let windMeter = needle.frame
        let windNote = note.frame
        let windFooter = title.frame
        for control in ["tuner-tuning", "Auto", "Hold", "tuner-reference-notes", "Reference tone"] {
            XCTAssertFalse(app.buttons[control].exists)
        }
        proof(app, "Flute without extra controls")

        app.buttons["tuner-instruments"].tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        XCTAssertTrue(app.buttons["tuner-string-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(instrumentButton.label, "Guitar")
        XCTAssertEqual(instrumentButton.value as? String, "3 + 3")
        proof(app, "Guitar header icon")
        XCTAssertEqual(windMeter.midX, needle.frame.midX, accuracy: 1)
        XCTAssertEqual(windMeter.midY, needle.frame.midY, accuracy: 1)
        XCTAssertEqual(windMeter.width, needle.frame.width, accuracy: 1)
        XCTAssertEqual(windNote.midY, note.frame.midY, accuracy: 1)
        XCTAssertEqual(windFooter.midY, app.buttons["tuner-tuning"].frame.midY, accuracy: 2)
    }

    func testInstrumentCheckNotesFollowNotationAndCanBeCleared() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=B♭ clarinet", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let footer = app.buttons["tuner-note-options"]
        XCTAssertTrue(footer.waitForExistence(timeout: 4))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        let first = app.buttons["tuner-check-70"]
        XCTAssertTrue(first.waitForExistence(timeout: 4))
        XCTAssertTrue(first.label.contains("C5"))
        XCTAssertTrue(first.label.contains("B♭4"))
        proof(app, "Clarinet written and concert targets")
        first.tap()
        XCTAssertTrue(footer.label.contains("C5"))
        let readout = app.descendants(matching: .any)["tuner-note-readout"].firstMatch
        let secondary = app.staticTexts["tuner-secondary-note-readout"]
        XCTAssertEqual(readout.label, "Written pitch, C5")
        XCTAssertEqual(secondary.label, "Concert pitch, B♭4")

        app.buttons["settings"].tap()
        let concert = app.buttons["tuner-pitch-concert"]
        XCTAssertTrue(concert.waitForExistence(timeout: 4))
        XCTAssertEqual(concert.label, "Concert first")
        XCTAssertEqual(app.buttons["tuner-pitch-written"].label, "Written first")
        let explanation = app.staticTexts["tuner-pitch-explanation"]
        XCTAssertTrue(explanation.label.contains("B♭ clarinet, alto sax, piccolo"))
        XCTAssertTrue(explanation.label.contains("appears in large type"))
        proof(app, "Transposing instruments settings")
        concert.tap()
        XCTAssertTrue(concert.isSelected)
        app.buttons["close-settings"].tap()
        XCTAssertTrue(footer.waitForExistence(timeout: 4))
        XCTAssertTrue(footer.label.contains("B♭4"))
        XCTAssertEqual(readout.label, "Concert pitch, B♭4")
        XCTAssertEqual(secondary.label, "Written pitch, C5")
        footer.tap()
        XCTAssertTrue(first.isSelected)
        XCTAssertTrue(first.label.hasPrefix("B♭4"))
        app.buttons["tuner-close-options"].tap()

        app.buttons["settings"].tap()
        let written = app.buttons["tuner-pitch-written"]
        XCTAssertTrue(written.waitForExistence(timeout: 4))
        written.tap()
        app.buttons["close-settings"].tap()
        XCTAssertTrue(footer.waitForExistence(timeout: 4))
        XCTAssertEqual(readout.label, "Written pitch, C5")

        footer.tap()
        XCTAssertTrue(first.isSelected)
        app.buttons["tuner-check-other"].tap()
        let input = app.textFields["tuner-check-input"]
        input.tap()
        input.typeText("E4")
        app.buttons["tuner-check-apply"].tap()
        XCTAssertTrue(footer.label.contains("E4"))
        XCTAssertEqual(readout.label, "Written pitch, E4")
        XCTAssertEqual(secondary.label, "Concert pitch, D4")
        footer.tap()
        XCTAssertTrue(app.buttons["tuner-check-other"].isSelected)
        app.buttons["tuner-check-auto"].tap()
        XCTAssertEqual(footer.label, "B♭ clarinet")
    }

    func testBothPitchOrdersAcrossTransposingInstruments() {
        let instruments = [
            ("Piccolo", 81, "A4", "A5"),
            ("English horn", 69, "E5", "A4"),
            ("B♭ clarinet", 70, "C5", "B♭4"),
            ("A clarinet", 69, "C5", "A4"),
            ("Bass clarinet", 58, "C5", "B♭3"),
            ("Soprano sax", 70, "C5", "B♭4"),
            ("Alto sax", 58, "G4", "B♭3"),
            ("Tenor sax", 58, "C5", "B♭3"),
            ("Baritone sax", 46, "G4", "B♭2"),
            ("B♭ trumpet", 70, "C5", "B♭4"),
            ("Flugelhorn", 70, "C5", "B♭4"),
            ("Horn in F", 53, "C4", "F3"),
            ("Cornet in B♭", 70, "C5", "B♭4"),
            ("Xylophone", 72, "C4", "C5"),
            ("Glockenspiel", 84, "C4", "C6")
        ]
        let app = XCUIApplication()
        let primary = app.staticTexts["tuner-note-readout"]
        let secondary = app.staticTexts["tuner-secondary-note-readout"]
        for (instrument, concertMIDI, writtenNote, concertNote) in instruments {
            for writtenFirst in [true, false] {
                let centsFromA4 = (concertMIDI - 69) * 100
                app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=\(instrument)",
                                       "--tuner-test-cents=\(centsFromA4)", "-AppleLanguages", "(en)",
                                       "-tuner.written", writtenFirst ? "YES" : "NO"]
                app.launch()
                XCTAssertTrue(secondary.waitForExistence(timeout: 4), instrument)
                let written = "Written pitch, " + writtenNote
                let concert = "Concert pitch, " + concertNote
                XCTAssertEqual(primary.label, writtenFirst ? written : concert, instrument)
                XCTAssertEqual(secondary.label, writtenFirst ? concert : written, instrument)
                XCTAssertLessThan(primary.frame.midY, secondary.frame.midY, instrument)
                XCTAssertGreaterThan(primary.frame.height, secondary.frame.height, instrument)
                if ["Piccolo", "B♭ clarinet", "Alto sax", "Glockenspiel"].contains(instrument) {
                    proof(app, instrument + (writtenFirst ? " written first" : " concert first"))
                }
                app.terminate()
            }
        }
    }

    func testTimpaniCanChooseKettleRangeAndLowTarget() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Timpani", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let footer = app.buttons["tuner-note-options"]
        XCTAssertTrue(footer.waitForExistence(timeout: 4))
        footer.tap()
        XCTAssertTrue(app.buttons["tuner-check-38"].exists)
        app.buttons["tuner-note-set"].tap()
        app.buttons["26″"].tap()
        XCTAssertFalse(app.buttons["tuner-check-38"].exists)
        let a = app.buttons["tuner-check-45"]
        XCTAssertTrue(a.waitForExistence(timeout: 4))
        proof(app, "Timpani 26-inch targets")
        a.tap()
        XCTAssertTrue(footer.label.contains("A2"))
        footer.tap()
        XCTAssertTrue(a.isSelected)
    }

    func testTuningPresetComparisonKeepsPlaybackAndPickerActive() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--tuner-instrument=Guitar", "-AppleLanguages", "(en)"]
        app.launch()
        app.buttons["transport"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-tuner"].tap()
        let footer = app.buttons["tuner-tuning"]
        XCTAssertTrue(footer.waitForExistence(timeout: 4))
        footer.tap()
        let standard = app.buttons["tuning-Guitar"]
        let dropD = app.buttons["tuning-Guitar · Drop D"]
        let halfStep = app.buttons["tuning-Guitar · Half step down"]
        XCTAssertTrue(standard.waitForExistence(timeout: 4))
        XCTAssertTrue(standard.isSelected)
        dropD.tap()
        XCTAssertTrue(dropD.isSelected)
        XCTAssertFalse(standard.isSelected)
        halfStep.tap()
        XCTAssertTrue(halfStep.isSelected)
        XCTAssertFalse(dropD.isSelected)
        app.buttons["tuner-close-options"].tap()
        XCTAssertTrue(app.buttons["Pause click to tune"].exists)
        XCTAssertEqual(footer.label, "Half step down")
        footer.tap()
        XCTAssertTrue(halfStep.isSelected)
    }

    func testNewBassAndBaritoneUkuleleHeadstocks() {
        for (instrument, count) in [("6-string bass", 6), ("Baritone ukulele", 4)] {
            let app = XCUIApplication()
            app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=\(instrument)",
                                   "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
            app.launch()
            let second = app.buttons["tuner-string-1"]
            let third = app.buttons["tuner-string-2"]
            XCTAssertTrue(second.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["tuner-string-\(count - 1)"].exists)
            second.tap()
            third.tap()
            XCTAssertEqual(second.value as? String, "In tune")
            XCTAssertEqual(third.value as? String, "In tune")
            XCTAssertTrue(app.buttons["tuner-tuning"].isHittable)
            proof(app, instrument + " interactive face")
            app.terminate()
        }
    }

    func testPipaNotesFollowTheirPegsAndKeepTunedStrings() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Pipa", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let strings = (0..<4).map { app.buttons["tuner-string-\($0)"] }
        XCTAssertTrue(strings[0].waitForExistence(timeout: 5))
        XCTAssertEqual(strings.map(\.label), ["4, A2", "3, D3", "2, E3", "1, A3"])
        XCTAssertLessThan(strings[0].frame.midX, strings[1].frame.midX)
        XCTAssertLessThan(strings[2].frame.midX, strings[3].frame.midX)
        XCTAssertLessThan(strings[0].frame.midY, strings[2].frame.midY)
        XCTAssertLessThan(strings[1].frame.midY, strings[3].frame.midY)

        // Tap the enlarged handle near the inner side of the right-hand target.
        strings[3].coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.5)).tap()
        XCTAssertEqual(strings[3].value as? String, "In tune")
        XCTAssertNotEqual(strings[1].value as? String, "In tune")
        proof(app, "Pipa lowest external peg tuned with the roller covered")

        for string in strings.prefix(3) {
            XCTAssertTrue(string.isHittable)
            string.tap()
            XCTAssertEqual(string.value as? String, "In tune")
        }
        XCTAssertTrue(strings.allSatisfy { $0.value as? String == "In tune" })
        XCTAssertTrue(app.buttons["tuner-tuning"].isHittable)
        proof(app, "Pipa note labels at the pegs and retained marks")
    }

    func testRegionalHeadstocksKeepTunedStrings() {
        let app = XCUIApplication()
        for (instrument, lastIndex) in [("Erhu", 1), ("Shamisen", 2), ("Oud · Arabic", 5)] {
            app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=\(instrument)",
                                   "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
            app.launch()
            let first = app.buttons["tuner-string-0"]
            let last = app.buttons["tuner-string-\(lastIndex)"]
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            // Tap the peg side of the region before using the note label for the next string.
            if instrument == "Oud · Arabic" {
                app.buttons["tuner-course-5-wire-0"].tap()
                XCTAssertNotEqual(last.value as? String, "In tune")
                app.buttons["tuner-course-5-wire-1"].tap()
            } else {
                last.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.5)).tap()
            }
            XCTAssertEqual(last.value as? String, "In tune", instrument)
            first.tap()
            XCTAssertEqual(first.value as? String, "In tune", instrument)
            XCTAssertEqual(last.value as? String, "In tune", instrument)
            proof(app, instrument + " headstock and retained marks")
            if instrument == "Oud · Arabic" {
                let paired = app.buttons["tuner-string-3"]
                let leftPeg = app.buttons["tuner-course-3-wire-0"]
                let rightPeg = app.buttons["tuner-course-3-wire-1"]
                XCTAssertLessThan(leftPeg.frame.midX, rightPeg.frame.midX)
                leftPeg.tap()
                XCTAssertEqual(leftPeg.value as? String, "In tune")
                XCTAssertNotEqual(rightPeg.value as? String, "In tune")
                XCTAssertNotEqual(paired.value as? String, "In tune")
                proof(app, "Oud left member only")
                rightPeg.tap()
                XCTAssertEqual(paired.value as? String, "In tune")
                XCTAssertEqual(first.value as? String, "In tune")
                proof(app, "Oud split course selected from the opposite peg")
            }
            app.terminate()
        }
    }

    func testGuzhengCanReachAllThreeRowsWithoutScrolling() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Guzheng", "--tuner-test-cents=0",
                               "--tuner-test-silent", "-AppleLanguages", "(en)"]
        app.launch()
        let high = app.buttons["tuner-strings-group-high"]
        let middle = app.buttons["tuner-strings-group-middle"]
        let low = app.buttons["tuner-strings-group-low"]
        let all = app.buttons["tuner-strings-layout-all"]
        XCTAssertTrue(high.waitForExistence(timeout: 5))
        XCTAssertEqual(high.label, "Near, Strings 1–7")
        XCTAssertEqual(middle.label, "Middle, Strings 8–14")
        XCTAssertEqual(low.label, "Far, Strings 15–21")
        XCTAssertTrue(low.isSelected)
        XCTAssertLessThan(low.frame.midX, middle.frame.midX)
        XCTAssertLessThan(middle.frame.midX, high.frame.midX)
        high.tap()
        XCTAssertTrue(high.isSelected)
        XCTAssertFalse(app.staticTexts["Player side"].exists)
        let first = app.buttons["tuner-string-0"]
        let second = app.buttons["tuner-string-1"]
        let last = app.buttons["tuner-string-20"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertFalse(last.exists)
        // The wire itself is tappable, alongside the note at the left.
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)).tap()
        XCTAssertEqual(first.value as? String, "Reference tone")
        second.tap()
        XCTAssertEqual(second.value as? String, "Reference tone")
        XCTAssertNotEqual(first.value as? String, "Reference tone")
        first.tap()
        XCTAssertEqual(first.value as? String, "Reference tone")
        first.tap()
        XCTAssertEqual(first.value as? String, "In tune")
        proof(app, "Guzheng High group and confirmed string")
        middle.tap()
        XCTAssertTrue(middle.isSelected)
        let middleString = app.buttons["tuner-string-10"]
        XCTAssertTrue(middleString.isHittable)
        middleString.tap()
        XCTAssertEqual(middleString.value as? String, "Reference tone")
        proof(app, "Guzheng Middle group audition")
        middleString.tap()
        XCTAssertEqual(middleString.value as? String, "In tune")
        proof(app, "Guzheng Middle group and confirmed string")
        low.tap()
        XCTAssertFalse(app.staticTexts["Far side"].exists)
        XCTAssertTrue(last.isHittable)
        XCTAssertEqual(last.label, "21, D2")
        XCTAssertFalse(middleString.exists)
        XCTAssertNotEqual(last.value as? String, "Reference tone")
        last.tap()
        XCTAssertEqual(last.value as? String, "Reference tone")
        last.tap()
        XCTAssertEqual(last.value as? String, "In tune")
        proof(app, "Guzheng grouped with string 21 confirmed")

        let controlFrame = high.frame
        all.tap()
        XCTAssertTrue(all.isSelected)
        all.tap()
        XCTAssertTrue(all.isSelected)
        XCTAssertEqual(high.frame, controlFrame)
        let targets = (0..<21).map { app.buttons["tuner-string-\($0)"] }
        XCTAssertTrue(targets.allSatisfy(\.isHittable))
        XCTAssertFalse(app.staticTexts["Far side"].exists)
        XCTAssertFalse(app.staticTexts["Player side"].exists)
        XCTAssertLessThan(last.frame.midY, first.frame.midY)
        XCTAssertEqual(first.value as? String, "In tune")
        XCTAssertEqual(last.value as? String, "In tune")
        XCTAssertEqual(middleString.value as? String, "In tune")
        first.tap()
        XCTAssertNotEqual(first.value as? String, "Reference tone")
        proof(app, "All 21 guzheng strings and retained marks")
        low.tap()
        XCTAssertTrue(low.isSelected)
        XCTAssertEqual(last.value as? String, "In tune")
        all.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertTrue(all.isSelected)
        high.tap()
        app.buttons["tuner-tuning"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["tuning-Guzheng · C major pentatonic"].tap()
        let seventh = app.buttons["tuner-string-6"]
        XCTAssertTrue(seventh.waitForExistence(timeout: 5))
        XCTAssertEqual(seventh.label, "7, C5")
    }

    func testKotoUnisonStringsAreIndependentTargets() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Koto", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let first = app.buttons["tuner-string-0"]
        let fifth = app.buttons["tuner-string-4"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.label, "1, D4")
        XCTAssertEqual(fifth.label, "5, D4")
        XCTAssertNotEqual(first.value as? String, "In tune")
        XCTAssertNotEqual(fifth.value as? String, "In tune")
        first.tap()
        XCTAssertEqual(first.value as? String, "In tune")
        XCTAssertNotEqual(fifth.value as? String, "In tune")
        fifth.tap()
        XCTAssertEqual(first.value as? String, "In tune")
        XCTAssertEqual(fifth.value as? String, "In tune")
        proof(app, "Koto numbered unisons")
    }

    func testStringArtworkStaysGreenAndOutlineFinishesLast() throws {
        let app = XCUIApplication()
        let cases: [(String, Int, CGRect)] = [
            ("Violin", 4, CGRect(x: 0.40, y: 0.50, width: 0.20, height: 0.10)),
            ("Erhu", 2, CGRect(x: 0.33, y: 0.50, width: 0.27, height: 0.11)),
            ("Shamisen", 3, CGRect(x: 0.39, y: 0.50, width: 0.24, height: 0.08)),
            ("Oud · Arabic", 6, CGRect(x: 0.40, y: 0.50, width: 0.20, height: 0.08)),
            ("Guzheng", 21, CGRect(x: 0.04, y: 0.53, width: 0.095, height: 0.18)),
            ("Guqin", 7, CGRect(x: 0.04, y: 0.59, width: 0.065, height: 0.19)),
            ("Koto", 13, CGRect(x: 0.04, y: 0.54, width: 0.075, height: 0.20))
        ]
        for (instrument, count, outline) in cases {
            app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=\(instrument)",
                                   "--tuner-test-cents=0", "--tuner-test-silent", "-AppleLanguages", "(en)"]
            app.launch()
            if instrument == "Guzheng" { app.buttons["tuner-strings-layout-all"].tap() }
            let first = app.buttons["tuner-string-0"]
            XCTAssertTrue(first.waitForExistence(timeout: 5), instrument)
            first.tap()
            XCTAssertEqual(first.value as? String, "In tune", instrument)
            let partial = try greenPixels(in: outline, of: app)
            if count > 2 {
                app.buttons["tuner-string-1"].tap()
                if instrument == "Oud · Arabic" { app.buttons["tuner-course-1-wire-1"].tap() }
                XCTAssertEqual(first.value as? String, "In tune", instrument)
                proof(app, instrument + " strings one and two confirmed")
            }
            for index in (count > 2 ? 2 : 1)..<count {
                let string = app.buttons["tuner-string-\(index)"]
                string.tap()
                if instrument == "Oud · Arabic" { app.buttons["tuner-course-\(index)-wire-1"].tap() }
                XCTAssertEqual(string.value as? String, "In tune", instrument + " string \(index + 1)")
            }
            XCTAssertGreaterThan(try greenPixels(in: outline, of: app), partial + 25, instrument)
            XCTAssertEqual(first.value as? String, "In tune", instrument)
            proof(app, instrument + " full outline in tune")
            if instrument == "Violin" {
                app.buttons["tuner-tuning"].tap()
                let differentTuning = app.buttons["tuning-Violin · Cross tuning"]
                XCTAssertTrue(differentTuning.waitForExistence(timeout: 5))
                differentTuning.tap()
                XCTAssertNotEqual(app.buttons["tuner-string-3"].value as? String, "In tune")
                XCTAssertLessThan(try greenPixels(in: outline, of: app), partial + 25)
            }
            app.terminate()
        }
    }

    private func greenPixels(in region: CGRect, of app: XCUIApplication) throws -> Int {
        let screenshot = try XCTUnwrap(app.screenshot().image.cgImage)
        let frame = CGRect(x: region.minX * CGFloat(screenshot.width), y: region.minY * CGFloat(screenshot.height),
                           width: region.width * CGFloat(screenshot.width), height: region.height * CGFloat(screenshot.height))
        let crop = try XCTUnwrap(screenshot.cropping(to: frame.integral))
        let context = try XCTUnwrap(CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                             bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        let pixels = try XCTUnwrap(context.data?.assumingMemoryBound(to: UInt8.self))
        return stride(from: 0, to: crop.width * crop.height * 4, by: 4).reduce(into: 0) { count, offset in
            let green = Int(pixels[offset + 1])
            if green >= Int(pixels[offset]) + 18 && green >= Int(pixels[offset + 2]) + 9 { count += 1 }
        }
    }

    func testOnlyStableReplayRemovesStringAndInstrumentGreen() throws {
        let app = XCUIApplication()
        let outline = CGRect(x: 0.33, y: 0.50, width: 0.27, height: 0.11)
        for scenario in ["tail", "jitter", "flat", "sharp"] {
            app.launchArguments = ["--mode-tuner", "--light", "--tuner-instrument=Erhu", "--tuner-test-cents=0",
                                   "--tuner-test-replay=\(scenario)", "-AppleLanguages", "(en)"]
            app.launch()
            let first = app.buttons["tuner-string-0"]
            let second = app.buttons["tuner-string-1"]
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            first.tap()
            second.tap()
            XCTAssertEqual(first.value as? String, "In tune")
            XCTAssertEqual(second.value as? String, "In tune")
            let greenOutline = try greenPixels(in: outline, of: app)
            XCTAssertGreaterThan(greenOutline, 25)

            first.tap()
            XCTAssertEqual(second.value as? String, "In tune", scenario)
            let updatedOutline = try greenPixels(in: outline, of: app)
            if scenario == "flat" || scenario == "sharp" {
                XCTAssertNotEqual(first.value as? String, "In tune", scenario)
                XCTAssertLessThan(updatedOutline, greenOutline - 25, scenario)
                proof(app, "Outline clears after stable " + scenario + " replay")
                first.tap()
                XCTAssertEqual(first.value as? String, "In tune")
                XCTAssertGreaterThan(try greenPixels(in: outline, of: app), updatedOutline + 25)
            } else {
                XCTAssertEqual(first.value as? String, "In tune", scenario)
                XCTAssertGreaterThan(updatedOutline, 25, scenario)
                proof(app, "Complete outline holds through " + scenario)
            }
            app.terminate()
        }
    }

    func testSitarAndYangqinKeepIndividualStringChains() {
        let app = XCUIApplication()
        app.launchArguments = ["--mode-tuner", "--light", "--tuner-instrument=Sitar", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let main = app.buttons["tuner-string-0"]
        let taraf = app.buttons["tuner-string-19"]
        XCTAssertTrue(main.waitForExistence(timeout: 5))
        app.buttons["tuner-strings-layout-grouped"].tap()
        let sympathetic = app.buttons["tuner-strings-group-sympathetic"]
        sympathetic.tap()
        XCTAssertTrue(taraf.isHittable)
        taraf.tap()
        XCTAssertEqual(taraf.value as? String, "In tune")
        XCTAssertNotEqual(app.buttons["tuner-string-18"].value as? String, "In tune")
        let unison = app.buttons["tuner-string-7"]
        unison.tap()
        XCTAssertEqual(unison.value as? String, "In tune")
        XCTAssertTrue(unison.isSelected)
        XCTAssertNotEqual(app.buttons["tuner-string-8"].value as? String, "In tune")
        app.buttons["tuner-strings-layout-all"].tap()
        XCTAssertEqual(main.value as? String, "In tune")
        XCTAssertTrue(unison.isSelected)
        XCTAssertEqual(taraf.value as? String, "In tune")
        proof(app, "Sitar melody and sympathetic wires")
        app.buttons["tuner-strings-layout-grouped"].tap()
        XCTAssertTrue(sympathetic.isSelected)
        XCTAssertTrue(unison.isSelected)
        proof(app, "Sitar focused on the selected sympathetic wire")
        app.terminate()

        app.launchArguments = ["--mode-tuner", "--light", "--tuner-instrument=Yangqin", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let course = app.buttons["tuner-yangqin-course"]
        let first = app.buttons["tuner-yangqin-wire-0"]
        let second = app.buttons["tuner-yangqin-wire-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertEqual(first.value as? String, "In tune")
        XCTAssertNotEqual(second.value as? String, "In tune")
        proof(app, "Yangqin first wire only")
        second.tap()
        XCTAssertEqual(first.value as? String, "In tune")
        XCTAssertEqual(second.value as? String, "In tune")
        course.tap()
        let other = app.buttons["tuner-yangqin-course-0"]
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        other.tap()
        XCTAssertNotEqual(first.value as? String, "In tune")
        XCTAssertTrue(app.buttons["tuner-yangqin-wire-3"].exists)
    }

    func testChineseInstrumentsShareTheirOwnPickerRow() {
        let app = XCUIApplication()
        app.launchArguments = ["--mode-tuner", "--light", "--tuner-instrument=Erhu",
                               "--tuner-test-cents=0", "--tuner-test-silent", "-AppleLanguages", "(en)"]
        app.launch()
        let picker = app.buttons["tuner-instruments"]
        picker.tap()
        let lane = app.scrollViews["tuner-lane-Chinese instruments"]
        XCTAssertTrue(lane.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chinese instruments"].exists)
        for instrument in ["Erhu", "Yangqin", "Pipa", "Guzheng"] {
            XCTAssertTrue(lane.buttons["tuner-profile-" + instrument].isHittable, instrument)
            let world = app.scrollViews["tuner-lane-World instruments"]
            XCTAssertFalse(world.buttons["tuner-profile-" + instrument].exists, instrument)
        }
        proof(app, "Chinese instruments")

        lane.buttons["tuner-profile-Yangqin"].tap()
        XCTAssertTrue(app.buttons["tuner-yangqin-wire-0"].waitForExistence(timeout: 5))
        picker.tap()
        XCTAssertTrue(lane.buttons["tuner-profile-Pipa"].isHittable)
        lane.buttons["tuner-profile-Pipa"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tuner-string-'")).count, 4)
        picker.tap()
        lane.swipeLeft()
        let guqin = lane.buttons["tuner-profile-Guqin"]
        XCTAssertTrue(guqin.isHittable)
        guqin.tap()
        XCTAssertTrue(app.buttons["tuner-string-6"].waitForExistence(timeout: 5))
    }

    func testInstrumentSetupSurvivesSwitchingAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let arguments = ["--light", "--tuner-test-cents=0", "--tuner-test-silent", "-AppleLanguages", "(en)"]
        app.launchArguments = arguments + ["--mode-metronome"]
        app.launch()
        let mode = app.buttons["mode-menu"]
        let memory = app.switches["remember-last-setup"]
        let instrument = app.buttons["tuner-instruments"]
        let tuning = app.buttons["tuner-tuning"]
        func openMemorySettings() {
            app.buttons["settings"].tap()
            for _ in 0..<3 where !memory.isHittable { app.scrollViews["settings-scroll"].swipeUp() }
            XCTAssertTrue(memory.isHittable)
        }
        func switchMode(to name: String) {
            mode.tap()
            app.buttons["mode-" + name].tap()
        }
        func relaunch() {
            app.terminate()
            app.launchArguments = arguments
            app.launch()
            XCTAssertTrue(mode.waitForExistence(timeout: 5))
        }

        openMemorySettings()
        if memory.value as? String == "1" { memory.tap() }
        XCTAssertEqual(memory.value as? String, "0")
        memory.tap()
        XCTAssertEqual(memory.value as? String, "1")
        proof(app, "Remember last setup in general settings")
        app.buttons["close-settings"].tap()
        relaunch()
        XCTAssertEqual(mode.label, "Metronome")
        switchMode(to: "tuner")
        XCTAssertEqual(instrument.label, "Chromatic")

        instrument.tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        tuning.tap()
        app.buttons["tuning-Guitar · Drop D"].tap()
        XCTAssertTrue(tuning.label.contains("Drop D"))
        instrument.tap()
        pickInstrument("Ukulele", in: app)
        tuning.tap()
        app.buttons["tuning-Ukulele · low G"].tap()
        XCTAssertTrue(tuning.label.contains("Low G"))

        instrument.tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        XCTAssertTrue(tuning.label.contains("Drop D"))
        XCTAssertTrue(app.buttons["tuner-string-0"].label.contains("D2"))
        relaunch()
        XCTAssertEqual(mode.label, "Tuner")
        XCTAssertTrue(tuning.waitForExistence(timeout: 5))
        XCTAssertEqual(instrument.label, "Guitar")
        XCTAssertTrue(tuning.label.contains("Drop D"))

        instrument.tap()
        pickInstrument("Ukulele", in: app)
        XCTAssertTrue(tuning.label.contains("Low G"))
        XCTAssertTrue(app.buttons["tuner-string-0"].label.contains("G3"))

        openMemorySettings()
        XCTAssertEqual(memory.value as? String, "1")
        memory.tap()
        XCTAssertEqual(memory.value as? String, "0")
        proof(app, "Memory off in tuner settings")
        app.buttons["close-settings"].tap()
        XCTAssertEqual(instrument.label, "Ukulele")
        XCTAssertTrue(tuning.label.contains("Low G"))
        instrument.tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        XCTAssertTrue(tuning.label.contains("Standard"))
        tuning.tap()
        app.buttons["tuning-Guitar · Drop D"].tap()
        relaunch()
        XCTAssertEqual(mode.label, "Metronome")
        switchMode(to: "tuner")
        XCTAssertEqual(instrument.label, "Chromatic")
        instrument.tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        XCTAssertTrue(tuning.label.contains("Standard"))

        openMemorySettings()
        XCTAssertEqual(memory.value as? String, "0")
        memory.tap()
        app.buttons["close-settings"].tap()
        relaunch()
        XCTAssertEqual(mode.label, "Tuner")
        XCTAssertEqual(instrument.label, "Guitar")
        XCTAssertTrue(tuning.label.contains("Standard"))

        switchMode(to: "practice")
        relaunch()
        XCTAssertEqual(mode.label, "Practice")
        switchMode(to: "metronome")
        openMemorySettings()
        memory.tap()
        memory.tap()
        app.buttons["close-settings"].tap()
    }

    func testPreviewFinishAcrossModes() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "-AppleLanguages", "(en)", "--tuner-test-cents=0"]
        app.launch()
        func showFinishes() {
            app.buttons["settings"].tap()
            for _ in 0..<4 where !app.buttons["skin-flat"].isHittable {
                app.scrollViews.firstMatch.swipeUp()
            }
        }
        app.buttons["transport"].tap()
        showFinishes()
        for finish in ["flat", "sculpted", "flat"] {
            let key = app.buttons["skin-" + finish]
            key.tap()
            XCTAssertTrue(key.isSelected)
            XCTAssertEqual(app.buttons["settings-transport"].label, "Stop metronome")
        }
        app.buttons["close-settings"].tap()
        app.buttons["transport"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-tuner"].tap()
        XCTAssertTrue(app.staticTexts["In tune"].waitForExistence(timeout: 5))
        proof(app, "Flat finish")
        app.terminate()
        app.launchArguments.append("--mode-tuner")
        app.launch()
        showFinishes()
        XCTAssertTrue(app.buttons["skin-flat"].isSelected)
        app.buttons["skin-sculpted"].tap()
        app.buttons["close-settings"].tap()
        XCTAssertTrue(app.staticTexts["In tune"].waitForExistence(timeout: 5))
        proof(app, "Raised finish")
    }

    func testInstrumentDiagramAndTuningProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)", "-tuner.reference", "440"]
        app.launch()
        app.buttons["tuner-instruments"].tap()
        pickInstrument("Guitar", layout: "guitar", in: app)
        app.buttons["tuner-string-1"].tap()
        XCTAssertEqual(app.buttons["tuner-string-1"].value as? String, "In tune")
        proof(app, "Standard fifth string")
        app.buttons["tuner-tuning"].tap()
        app.buttons["tuning-Guitar · Drop D"].tap()
        XCTAssertTrue(app.buttons["tuner-instruments"].label.contains("Guitar"))
        XCTAssertTrue(app.buttons["tuner-tuning"].label.contains("Drop D"))
        XCTAssertTrue(app.buttons["tuner-string-0"].label.contains("D2"))
        for i in [0, 1, 2] {
            let key = app.buttons["tuner-string-" + String(i)]
            key.tap()
            XCTAssertEqual(key.value as? String, "In tune")
        }
        XCTAssertEqual(app.buttons["tuner-string-0"].value as? String, "In tune")
        app.buttons["tuner-string-0"].tap()
        XCTAssertEqual(app.buttons["tuner-string-0"].value as? String, "In tune")
        XCTAssertEqual(app.buttons["tuner-string-1"].value as? String, "In tune")
        XCTAssertEqual(app.buttons["tuner-string-2"].value as? String, "In tune")
        proof(app, "Guitar diagram")
        app.buttons["tuner-tuning"].tap()
        app.buttons["tuning-Guitar"].tap()
        XCTAssertFalse(app.buttons["tuner-string-2"].value as? String == "In tune")
        app.buttons["tuner-instruments"].tap()
        app.buttons["tuner-profile-Cello"].tap()
        app.buttons["tuner-string-3"].tap()
        XCTAssertEqual(app.buttons["tuner-string-3"].value as? String, "In tune")
        proof(app, "Cello diagram")
    }

    func testHeadstocksAndPersistentLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)", "-tuner.reference", "440"]
        app.launch()
        for (instrument, first, alternative, count) in [
            ("Guitar", "guitar", "inlineGuitar", 6),
            ("Bass", "bass", "pairedBass", 4),
            ("Ukulele", "", "", 4),
            ("Violin", "", "", 4),
            ("Viola", "", "", 4),
            ("Cello", "", "", 4)
        ] {
            app.buttons["tuner-instruments"].tap()
            pickInstrument(instrument, layout: first.isEmpty ? nil : first, in: app)
            for index in [0, 1, 2, 0] {
                let string = app.buttons["tuner-string-\(index)"]
                XCTAssertTrue(string.waitForExistence(timeout: 5))
                string.tap()
                XCTAssertTrue(string.isSelected)
                XCTAssertEqual(string.value as? String, "In tune")
            }
            app.buttons["tuner-string-\(count - 1)"].tap()
            let bowedTuning = [
                "Violin": ["G3", "D4", "A4", "E5"],
                "Viola": ["C3", "G3", "D4", "A4"],
                "Cello": ["C2", "G2", "D3", "A3"]
            ]
            if let pitches = bowedTuning[instrument] {
                for (index, pitch) in pitches.enumerated() {
                    let string = app.buttons["tuner-string-\(index)"]
                    XCTAssertEqual(string.label, "\(4 - index), " + pitch)
                    XCTAssertEqual(string.value as? String, "In tune")
                }
            }
            if instrument == "Bass" {
                for (index, pitch) in ["E1", "A1", "D2", "G2"].enumerated() {
                    let string = app.buttons["tuner-string-\(index)"]
                    XCTAssertEqual(string.label, "\(4 - index), " + pitch)
                    XCTAssertEqual(string.value as? String, "In tune")
                }
                app.buttons["tuner-string-1"].tap()
                proof(app, "Precision Bass A1")
            }
            proof(app, instrument + " headstock")
            if !first.isEmpty {
                app.buttons["tuner-instruments"].tap()
                pickInstrument(instrument, layout: alternative, in: app)
                let alternateKey = app.buttons["tuner-layout-" + alternative]
                XCTAssertEqual(app.buttons["tuner-string-2"].value as? String, "In tune")
                for index in [count - 1, 1, count / 2] {
                    let string = app.buttons["tuner-string-\(index)"]
                    let left = instrument == "Guitar" || index < count / 2
                    string.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.68 : 0.32, dy: 0.5)).tap()
                    XCTAssertTrue(string.isSelected)
                    XCTAssertEqual(string.value as? String, "In tune")
                }
                proof(app, instrument + " alternate")
                app.buttons["tuner-instruments"].tap()
                app.buttons["tuner-profile-" + instrument].tap()
                XCTAssertTrue(alternateKey.isSelected)
                app.buttons["tuner-layout-" + first].tap()
            }
        }
    }

    func testThreePlusOneBassLayoutPreservesProgressAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Bass", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        let instrument = app.buttons["tuner-instruments"]
        let bass = app.buttons["tuner-profile-Bass"]
        let inline = app.buttons["tuner-layout-bass"]
        let threePlusOne = app.buttons["tuner-layout-threePlusOneBass"]
        let paired = app.buttons["tuner-layout-pairedBass"]
        let lowE = app.buttons["tuner-string-0"]
        XCTAssertTrue(instrument.waitForExistence(timeout: 4))
        instrument.tap()
        bass.tap()
        inline.tap()
        XCTAssertTrue(lowE.waitForExistence(timeout: 4))
        lowE.tap()
        XCTAssertEqual(lowE.value as? String, "In tune")

        instrument.tap()
        bass.tap()
        XCTAssertTrue(threePlusOne.isHittable)
        XCTAssertEqual(threePlusOne.label, "Bass, 3 + 1")
        XCTAssertTrue(paired.exists)
        XCTAssertEqual(bass.frame.midX, threePlusOne.frame.midX, accuracy: 2)
        proof(app, "Four string bass styles")
        threePlusOne.tap()
        XCTAssertEqual(instrument.value as? String, "3 + 1")
        XCTAssertEqual(lowE.value as? String, "In tune")
        let notes = ["E1", "A1", "D2", "G2"]
        for (index, note) in notes.enumerated() {
            let string = app.buttons["tuner-string-\(index)"]
            XCTAssertEqual(string.label, "\(notes.count - index), " + note)
            string.tap()
            XCTAssertEqual(string.value as? String, "In tune")
        }
        let highG = app.buttons["tuner-string-3"]
        XCTAssertGreaterThan(highG.frame.midX, lowE.frame.midX + 80)
        proof(app, "3 plus 1 bass tuning face")

        instrument.tap()
        bass.tap()
        XCTAssertTrue(threePlusOne.isSelected)
        paired.tap()
        XCTAssertEqual(instrument.value as? String, "2 + 2")
        XCTAssertEqual(lowE.value as? String, "In tune")
        let a = app.buttons["tuner-string-1"]
        let d = app.buttons["tuner-string-2"]
        XCTAssertEqual(a.frame.midY, d.frame.midY, accuracy: 1)
        XCTAssertEqual(lowE.frame.midY, highG.frame.midY, accuracy: 1)
        XCTAssertLessThan(a.frame.midY, lowE.frame.midY)
        highG.tap()
        XCTAssertTrue(highG.isSelected)
        proof(app, "Hofner 2 plus 2 bass tuning face")
        instrument.tap()
        bass.tap()
        XCTAssertTrue(paired.isSelected)
        threePlusOne.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(instrument.waitForExistence(timeout: 4))
        XCTAssertEqual(instrument.value as? String, "3 + 1")
        instrument.tap()
        bass.tap()
        XCTAssertTrue(threePlusOne.isSelected)
        inline.tap()

        app.terminate()
        app.launchArguments += ["-tuner.bassHeadstock", "stingRayBass"]
        app.launch()
        XCTAssertTrue(instrument.waitForExistence(timeout: 4))
        XCTAssertEqual(instrument.value as? String, "3 + 1")
        instrument.tap()
        bass.tap()
        XCTAssertTrue(threePlusOne.isSelected)
    }

    func testHeadlessGuitarLayoutsKeepStringProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
        app.launch()

        for (instrument, standardID, headlessID, notes) in [
            ("Guitar", "guitar", "headlessGuitar", ["E2", "A2", "D3", "G3", "B3", "E4"]),
            ("7-string guitar", "guitarSeven", "headlessGuitarSeven", ["B1", "E2", "A2", "D3", "G3", "B3", "E4"])
        ] {
            app.buttons["tuner-instruments"].tap()
            pickInstrument(instrument, layout: standardID, in: app)
            let low = app.buttons["tuner-string-0"]
            XCTAssertTrue(low.waitForExistence(timeout: 5))
            XCTAssertEqual(low.value as? String, "In tune")
            let headless = app.buttons["tuner-layout-" + headlessID]
            let standard = app.buttons["tuner-layout-" + standardID]
            app.buttons["tuner-instruments"].tap()
            pickInstrument(instrument, layout: headlessID, in: app)
            XCTAssertEqual(app.buttons["tuner-instruments"].value as? String, "Headless")
            XCTAssertEqual(low.value as? String, "In tune")
            for (index, note) in notes.enumerated() {
                let string = app.buttons["tuner-string-\(index)"]
                XCTAssertEqual(string.label, "\(notes.count - index), " + note)
                string.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33)).tap()
                XCTAssertEqual(string.value as? String, "In tune")
            }
            proof(app, instrument + " headless")
            app.buttons["tuner-instruments"].tap()
            app.buttons["tuner-profile-" + instrument].tap()
            XCTAssertTrue(headless.isSelected)
            standard.tap()
        }
    }

    func testInstrumentFamiliesQuickSelectionAndInlineDetails() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
        app.launch()
        app.buttons["tuner-instruments"].tap()
        let guitarTile = app.buttons["tuner-profile-Guitar"]
        let sevenTile = app.buttons["tuner-profile-7-string guitar"]
        let twelveTile = app.buttons["tuner-profile-12-string guitar"]
        let sixHeadless = app.buttons["tuner-layout-headlessGuitar"]
        let sevenHeadless = app.buttons["tuner-layout-headlessGuitarSeven"]
        let ukuleleTile = app.buttons["tuner-profile-Ukulele"]
        let bassTile = app.buttons["tuner-profile-Bass"]
        XCTAssertTrue(ukuleleTile.isHittable)
        XCTAssertTrue(bassTile.isHittable)
        XCTAssertLessThan(guitarTile.frame.midY, ukuleleTile.frame.midY)
        XCTAssertLessThan(ukuleleTile.frame.midY, bassTile.frame.midY)
        XCTAssertTrue(app.buttons["tuner-profile-12-string guitar"].isHittable)
        for instrument in ["Violin", "Viola", "Cello", "Double bass", "5-string banjo", "Mandolin"] {
            XCTAssertTrue(app.buttons["tuner-profile-" + instrument].isHittable)
        }
        XCTAssertFalse(app.buttons["tuner-family-Plucked strings"].exists)
        XCTAssertTrue(app.buttons["tuner-profile-Baritone ukulele"].isHittable)
        XCTAssertFalse(app.buttons["tuner-family-Ukulele"].exists)
        XCTAssertFalse(app.buttons["tuner-profile-Ukulele · low G"].exists)
        let bassLane = app.scrollViews["tuner-lane-Bass"]
        let sixBass = app.buttons["tuner-profile-6-string bass"]
        XCTAssertTrue(sixBass.isHittable)
        XCTAssertLessThanOrEqual(sixBass.frame.maxX, bassLane.frame.maxX + 1)
        XCTAssertEqual(guitarTile.frame.midX, ukuleleTile.frame.midX, accuracy: 1)
        XCTAssertEqual(guitarTile.frame.midX, bassTile.frame.midX, accuracy: 1)
        XCTAssertEqual(guitarTile.frame.midX, app.buttons["tuner-profile-Violin"].frame.midX, accuracy: 1)
        XCTAssertEqual(sixBass.frame.width, guitarTile.frame.width, accuracy: 1)
        XCTAssertFalse(sevenHeadless.exists)
        let list = app.scrollViews["tuner-instrument-list"]
        XCTAssertLessThan(list.frame.maxY, app.frame.maxY - 10)
        XCTAssertGreaterThan(list.frame.minX, app.frame.minX + 10)
        XCTAssertLessThan(list.frame.maxX, app.frame.maxX - 10)
        proof(app, "Instrument families collapsed")

        guitarTile.tap()
        XCTAssertTrue(sixHeadless.isHittable)
        XCTAssertFalse(sevenHeadless.exists)
        XCTAssertFalse(app.buttons["tuner-profile-8-string guitar"].exists)
        XCTAssertFalse(app.buttons["tuner-profile-Baritone guitar"].exists)
        XCTAssertEqual(guitarTile.value as? String, "Expanded")
        XCTAssertEqual(guitarTile.frame.midX, sixHeadless.frame.midX, accuracy: 2)
        XCTAssertEqual(guitarTile.frame.height, sixHeadless.frame.height, accuracy: 1)
        XCTAssertFalse(app.buttons["tuner-layout-guitarTwelve"].exists)
        let sixInline = app.buttons["tuner-layout-inlineGuitar"]
        XCTAssertEqual(app.buttons["tuner-layout-guitar"].label, "Guitar, 3 + 3")
        XCTAssertEqual(sixInline.label, "Guitar, 6 in line")
        XCTAssertEqual(sixHeadless.label, "Guitar, Headless")
        proof(app, "6-string guitar expanded")
        guitarTile.tap()
        XCTAssertFalse(sixHeadless.exists)
        XCTAssertEqual(guitarTile.value as? String, "Collapsed")

        guitarTile.tap()
        sixInline.tap()
        let instrumentButton = app.buttons["tuner-instruments"]
        XCTAssertEqual(instrumentButton.value as? String, "6 in line")
        instrumentButton.tap()
        guitarTile.tap()
        XCTAssertTrue(sixInline.isSelected)

        sevenTile.tap()
        XCTAssertTrue(sevenHeadless.isHittable)
        XCTAssertEqual(sevenTile.frame.midX, sevenHeadless.frame.midX, accuracy: 2)
        XCTAssertEqual(app.buttons["tuner-layout-guitarSeven"].label, "7-string guitar, 3 + 4")
        XCTAssertEqual(app.buttons["tuner-layout-inlineGuitarSeven"].label, "7-string guitar, 7 in line")
        XCTAssertEqual(sevenHeadless.label, "7-string guitar, Headless")
        proof(app, "7-string guitar expanded")
        bassTile.tap()
        XCTAssertFalse(sevenHeadless.exists)
        XCTAssertTrue(app.buttons["tuner-layout-pairedBass"].isHittable)
        XCTAssertEqual(app.buttons["tuner-layout-bass"].label, "Bass, 4 in line")
        XCTAssertEqual(app.buttons["tuner-layout-threePlusOneBass"].label, "Bass, 3 + 1")
        XCTAssertEqual(app.buttons["tuner-layout-pairedBass"].label, "Bass, 2 + 2")
        XCTAssertEqual(bassTile.value as? String, "Expanded")
        XCTAssertTrue(sixBass.isHittable)
        XCTAssertEqual(sixBass.frame.midY, bassTile.frame.midY, accuracy: 2)
        proof(app, "4-string bass expanded")
        sevenTile.tap()
        sevenHeadless.tap()
        XCTAssertTrue(app.buttons["tuner-string-6"].waitForExistence(timeout: 4))
        XCTAssertFalse(guitarTile.exists)

        app.buttons["tuner-instruments"].tap()
        XCTAssertTrue(sevenTile.isSelected)
        sevenTile.tap()
        XCTAssertTrue(sevenHeadless.isSelected)
        app.buttons["tuner-layout-guitarSeven"].tap()
        XCTAssertTrue(app.buttons["tuner-string-6"].isHittable)

        app.buttons["tuner-instruments"].tap()
        twelveTile.tap()
        XCTAssertTrue(app.buttons["tuner-string-11"].waitForExistence(timeout: 4))
        XCTAssertFalse(twelveTile.exists)
        app.buttons["tuner-instruments"].tap()
        XCTAssertFalse(app.buttons["tuner-more-instruments"].exists)
        let piano = app.buttons["tuner-profile-Piano"]
        for _ in 0..<4 where !piano.isHittable { list.swipeUp(velocity: .slow) }
        XCTAssertTrue(piano.isHittable)
        piano.tap()
        XCTAssertTrue(app.buttons["tuner-instruments"].waitForExistence(timeout: 4))
        app.buttons["tuner-instruments"].firstMatch.tap()
        XCTAssertTrue(piano.isSelected)
        XCTAssertTrue(piano.isHittable)
        let create = app.buttons["Create tuning"]
        for _ in 0..<4 where !create.isHittable { list.swipeUp(velocity: .slow) }
        XCTAssertTrue(create.isHittable)
        proof(app, "Full instrument list")
        create.tap()
        XCTAssertTrue(app.textFields["Name"].isHittable || app.textFields["Name"].exists)
    }

    func testSevenAndTwelveStringGuitarHeadstocks() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
        app.launch()

        app.buttons["tuner-instruments"].tap()
        pickInstrument("7-string guitar", layout: "guitarSeven", in: app)
        let sevenNotes = ["B1", "E2", "A2", "D3", "G3", "B3", "E4"]
        for (index, note) in sevenNotes.enumerated() {
            XCTAssertEqual(app.buttons["tuner-string-\(index)"].label, "\(7 - index), " + note)
        }
        app.buttons["tuner-string-1"].tap()
        XCTAssertEqual(app.buttons["tuner-string-1"].value as? String, "In tune")
        proof(app, "7-string guitar headstock")

        app.buttons["tuner-instruments"].tap()
        pickInstrument("7-string guitar", layout: "inlineGuitarSeven", in: app)
        XCTAssertEqual(app.buttons["tuner-string-1"].value as? String, "In tune")
        for index in [6, 5, 4] {
            app.buttons["tuner-string-\(index)"].tap()
            XCTAssertEqual(app.buttons["tuner-string-\(index)"].value as? String, "In tune")
        }
        proof(app, "7-string inline headstock")
        app.buttons["tuner-instruments"].tap()
        app.buttons["tuner-profile-7-string guitar"].tap()
        XCTAssertTrue(app.buttons["tuner-layout-inlineGuitarSeven"].isSelected)
        app.buttons["tuner-layout-guitarSeven"].tap()

        app.buttons["tuner-instruments"].tap()
        app.buttons["tuner-profile-12-string guitar"].tap()
        let twelveNotes = ["E3", "E2", "A3", "A2", "D4", "D3", "G4", "G3", "B3", "B3", "E4", "E4"]
        for (index, note) in twelveNotes.enumerated() {
            XCTAssertEqual(app.buttons["tuner-string-\(index)"].label, "\(12 - index), " + note)
        }
        for index in [8, 10] {
            let first = app.buttons["tuner-string-\(index)"]
            let second = app.buttons["tuner-string-\(index + 1)"]
            first.tap()
            XCTAssertEqual(first.value as? String, "In tune")
            XCTAssertNotEqual(second.value as? String, "In tune")
            second.tap()
            XCTAssertEqual(second.value as? String, "In tune")
            XCTAssertEqual(first.value as? String, "In tune")
        }
        app.buttons["tuner-string-7"].tap()
        XCTAssertEqual(app.buttons["tuner-string-7"].value as? String, "In tune")
        proof(app, "12-string guitar headstock")
        app.buttons["tuner-tuning"].tap()
        XCTAssertTrue(app.buttons["tuning-12-string guitar"].exists)
        app.buttons["Close"].tap()
        XCTAssertEqual(app.buttons["tuner-string-11"].value as? String, "In tune")
    }

    func testFiveStringBassMapsAndKeepsTunedStrings() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
        app.launch()
        app.buttons["tuner-instruments"].tap()
        app.buttons["tuner-profile-5-string bass"].tap()

        for (index, note) in ["B0", "E1", "A1", "D2", "G2"].enumerated() {
            let string = app.buttons["tuner-string-\(index)"]
            XCTAssertTrue(string.waitForExistence(timeout: 5))
            XCTAssertEqual(string.label, "\(5 - index), " + note)
            string.coordinate(withNormalizedOffset: CGVector(dx: index == 4 ? 0.32 : 0.68, dy: 0.5)).tap()
            XCTAssertTrue(string.isSelected)
            XCTAssertEqual(string.value as? String, "In tune")
        }
        XCTAssertFalse(app.buttons["tuner-string-5"].exists)
        XCTAssertEqual(app.buttons["tuner-string-0"].value as? String, "In tune")
        XCTAssertEqual(app.buttons["tuner-string-2"].value as? String, "In tune")
        proof(app, "Jazz Bass V")
        app.buttons["tuner-instruments"].tap()
        app.buttons["tuner-profile-5-string bass"].tap()
        XCTAssertEqual(app.buttons["tuner-string-0"].value as? String, "In tune")
    }

    func testExpandedPresetsAndCustomTuningCanBeReopened() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Guitar", "--tuner-test-cents=0",
                               "-AppleLanguages", "(en)"]
        app.launch()
        app.buttons["tuner-tuning"].tap()
        proof(app, "Guitar common tuning presets")
        let openD = app.buttons["tuning-Guitar · Open D"]
        let presets = app.scrollViews.firstMatch
        for _ in 0..<5 where !openD.isHittable { presets.swipeUp(velocity: .slow) }
        openD.tap()
        XCTAssertTrue(app.buttons["tuner-tuning"].label.contains("Open D"))
        XCTAssertEqual(app.buttons["tuner-string-0"].label, "6, D2")

        app.buttons["tuner-tuning"].tap()
        app.buttons["tuner-edit-custom"].tap()
        let notes = app.textFields["tuner-custom-notes"]
        let current = notes.value as? String ?? ""
        notes.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        notes.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "C2 G2 C3 G3 C4 E4")
        app.buttons["Save"].tap()
        XCTAssertEqual(app.buttons["tuner-string-0"].label, "6, C2")
        app.buttons["tuner-tuning"].tap()
        XCTAssertEqual(notes.value as? String, "C2 G2 C3 G3 C4 E4")
        app.buttons["tuning-Guitar"].tap()
        XCTAssertEqual(app.buttons["tuner-string-0"].label, "6, E2")
    }

    func testGuitarNeedleFeedback() {
        for cents in [-26, -6, 24] {
            let app = XCUIApplication()
            app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=\(cents)", "-AppleLanguages", "(en)"]
            app.launch()
            app.buttons["tuner-instruments"].tap()
            pickInstrument("Guitar", layout: "guitar", in: app)
            let fifthString = app.buttons["tuner-string-1"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: fifthString)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            app.buttons["tuner-string-1"].tap()
            XCTAssertTrue(app.buttons["tuner-string-1"].isSelected)
            XCTAssertNotEqual(app.buttons["tuner-string-1"].value as? String, "In tune")
            proof(app, "Guitar needle \(cents)")
            app.terminate()
        }
    }

    func testDialStates() {
        for (cents, label) in [("-32","Flat"),("-8","Almost · flat"),("0","In tune"),("8","Almost · sharp"),("32","Sharp")] {
            let app = XCUIApplication()
            app.launchArguments = ["--light","--mode-tuner","--tuner-test-cents=" + cents,"-AppleLanguages","(en)","-tuner.profile","Chromatic","-tuner.reference","440"]
            app.launch()
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
            proof(app, "Dial " + cents)
            app.terminate()
        }
    }
    func testChromaticLibraryTile() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Chromatic",
                               "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
        app.launch()
        proof(app, "Chromatic header icon")
        app.buttons["tuner-instruments"].tap()
        let chromatic = app.buttons["tuner-profile-Chromatic"]
        let guitar = app.buttons["tuner-profile-Guitar"]
        XCTAssertTrue(chromatic.isSelected)
        XCTAssertEqual(chromatic.frame.width, guitar.frame.width, accuracy: 1)
        XCTAssertEqual(chromatic.frame.midX, guitar.frame.midX, accuracy: 1)
        XCTAssertFalse(app.buttons["tuner-family-Chromatic"].exists)
        proof(app, "Chromatic in instrument list")
        pickInstrument("Guitar", layout: "guitar", in: app)
        XCTAssertTrue(app.buttons["tuner-string-0"].waitForExistence(timeout: 5))
        app.buttons["tuner-instruments"].tap()
        XCTAssertFalse(chromatic.isSelected)
        chromatic.tap()
        XCTAssertTrue(app.staticTexts["In tune"].waitForExistence(timeout: 5))
    }

    func testChromaticSustainFeedback() {
        let app = XCUIApplication()
        for (duration, expected) in [("0", "4%"), ("1.2", "52%"), ("2.7", "100%")] {
            app.launchArguments = ["--light", "--mode-tuner", "--tuner-instrument=Chromatic",
                                   "--tuner-test-cents=0", "--tuner-test-sustain=" + duration,
                                   "-tuner.response", "balanced", "-AppleLanguages", "(en)"]
            app.launch()
            let centered = app.staticTexts["In tune"]
            XCTAssertTrue(centered.waitForExistence(timeout: 5))
            XCTAssertEqual(centered.value as? String, expected)
            proof(app, "Centered sustain " + duration)
            app.terminate()
        }
    }

    func testChromaticTargetAndReferenceToneStayTogether() {
        let app = XCUIApplication()
        app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=8", "--tuner-test-silent",
                               "-AppleLanguages", "(en)"]
        app.launch()

        let target = app.buttons["tuner-reference-target"]
        let play = app.buttons["tuner-reference-play"]
        let done = app.buttons["tuner-reference-done"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Reference tone")
        proof(app, "Reference tone stopped")
        openReferenceOctaveFour(app)
        app.buttons["tuner-reference-note-70"].tap()
        XCTAssertTrue(app.buttons["tuner-reference-note-70"].isSelected)
        app.buttons["tuner-reference-note-71"].tap()
        XCTAssertTrue(app.buttons["tuner-reference-note-71"].isSelected)
        proof(app, "Reference note picker")
        done.tap()
        XCTAssertEqual(target.value as? String, "B4")
        XCTAssertEqual(play.label, "Reference tone")
        XCTAssertTrue(app.buttons["tuner-dial-note-11"].isSelected)

        play.tap()
        XCTAssertEqual(play.label, "Stop tone")
        XCTAssertTrue(app.staticTexts["—"].exists)
        proof(app, "Reference tone playing")
        target.tap()
        XCTAssertTrue(app.buttons["tuner-reference-note-71"].isSelected)
        for note in [69, 70] {
            let pitch = app.buttons["tuner-reference-note-\(note)"]
            pitch.tap()
            XCTAssertTrue(pitch.isSelected)
            XCTAssertTrue(done.exists)
        }
        done.tap()
        XCTAssertEqual(target.value as? String, "A♯4")
        XCTAssertEqual(play.label, "Stop tone")

        play.tap()
        XCTAssertEqual(play.label, "Reference tone")
        XCTAssertTrue(app.staticTexts["tuner-chromatic-intonation"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["tuner-chromatic-intonation"].value as? String, "+8¢")
        target.tap()
        app.buttons["tuner-reference-auto"].tap()
        XCTAssertTrue(app.buttons["tuner-reference-auto"].isSelected)
        done.tap()
        XCTAssertTrue(app.buttons["tuner-dial-note-9"].isSelected)
        XCTAssertEqual(target.value as? String, "A♯4")
    }

    func testTunerSilentBackgroundStopsReferenceAndRestoresListening() {
        let app = XCUIApplication()
        app.launchArguments = ["--mode-tuner", "--tuner-test-silent", "-AppleLanguages", "(en)"]
        app.launch()
        let play = app.buttons["tuner-reference-play"]
        XCTAssertTrue(app.staticTexts["Play a note"].waitForExistence(timeout: 5))
        play.tap()
        XCTAssertEqual(play.label, "Stop tone")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.staticTexts["Play a note"].waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Reference tone")
    }

    func testTunerInputStatesAreDistinct() {
        let app = XCUIApplication()
        for (input, expected, action) in [
            ("waiting", "Microphone access", nil),
            ("denied", "Microphone off", "Open Settings"),
            ("unavailable", "Input unavailable", "Retry microphone"),
            ("silent", "Play a note", nil)
        ] {
            app.launchArguments = ["--mode-tuner", "--tuner-test-silent", "--tuner-test-input=" + input,
                                   "-AppleLanguages", "(en)"]
            app.launch()
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5))
            if let action { XCTAssertTrue(app.buttons[action].isHittable) }
            proof(app, expected)
            app.terminate()
        }
    }

    func testMicrophoneCanBeAllowedOnFirstUse() {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .microphone)
        app.launchArguments = ["--mode-tuner", "-AppleLanguages", "(en)"]
        app.launch()
        let allow = microphonePermissionAlert().buttons["kTCCServiceMicrophone-allow-button"].firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 8))
        allow.tap()
        #if targetEnvironment(simulator)
        XCTAssertTrue(inputReady(app).waitForExistence(timeout: 8))
        #else
        XCTAssertTrue(inputReady(app, allowUnavailable: false).waitForExistence(timeout: 8))
        #endif
    }

    func testMicrophonePermissionResumesAfterSettings() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The simulator may open Settings at its root. This test covers the iPhone app-settings handoff.")
        #else
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .microphone)
        app.launchArguments = ["--mode-tuner", "-AppleLanguages", "(en)"]
        app.launch()

        let permission = microphonePermissionAlert()
        XCTAssertTrue(permission.waitForExistence(timeout: 8))
        let deny = permission.buttons["kTCCServiceMicrophone-deny-button"].firstMatch
        XCTAssertTrue(deny.isHittable)
        deny.tap()
        XCTAssertTrue(app.staticTexts["Microphone off"].waitForExistence(timeout: 5))
        app.buttons["Open Settings"].tap()

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let toggle = settings.switches["Microphone"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        let allowed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [allowed], timeout: 4), .completed)

        app.activate()
        XCTAssertTrue(inputReady(app, allowUnavailable: false).waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Microphone off"].exists)
        XCTAssertEqual(app.buttons["tuner-reference-play"].label, "Reference tone")
        proof(app, "Microphone restored from Settings")
        #endif
    }

    func testReadoutDirectionIsAccessibleInBothFinishes() {
        let app = XCUIApplication()
        for (profile, identifier, finish, detune, spoken, value) in [
            ("Chromatic", "tuner-chromatic-intonation", "--light", "-28", "Flat", "−28¢"),
            ("Chromatic", "tuner-chromatic-intonation", "--dark", "28", "Sharp", "+28¢"),
            ("Chromatic", "tuner-chromatic-intonation", "--dark", "0", "In tune", nil),
            ("Guitar", "tuner-needle-meter", "--dark", "-28", "Flat", "−28¢"),
            ("Guitar", "tuner-needle-meter", "--light", "0", "In tune", "+0¢"),
            ("Guitar", "tuner-needle-meter", "--light", "28", "Sharp", "+28¢")
        ] {
            app.launchArguments = [finish, "--mode-tuner", "--tuner-instrument=" + profile,
                                   "--tuner-test-silent", "--tuner-test-cents=" + detune,
                                   "-AppleLanguages", "(en)"]
            app.launch()
            let meter = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(meter.waitForExistence(timeout: 5))
            XCTAssertEqual(meter.label, spoken)
            if let value { XCTAssertEqual(meter.value as? String, value) }
            if profile == "Chromatic" {
                let target = app.buttons["tuner-reference-target"]
                let play = app.buttons["tuner-reference-play"]
                XCTAssertTrue(target.isHittable && play.isHittable)
                XCTAssertGreaterThanOrEqual(target.frame.height, 44)
                XCTAssertLessThanOrEqual(play.frame.maxX, app.frame.maxX - 10)
                if finish == "--dark", detune == "28" {
                    openReferenceOctaveFour(app)
                    let note = app.buttons["tuner-reference-note-69"]
                    XCTAssertTrue(note.isHittable)
                    note.tap()
                    XCTAssertTrue(note.isSelected)
                    proof(app, "Target picker at the current type size")
                    app.buttons["tuner-reference-done"].tap()
                }
            }
            proof(app, profile + " " + finish.dropFirst(2) + " " + spoken)
            app.terminate()
        }
    }

    func testBanjoMandolinAndUprightBassHeadstocks() {
        let instruments = [
            ("5-string banjo", ["G4", "D3", "G3", "B3", "D4"]),
            ("Mandolin", ["G3", "D4", "A4", "E5"]),
            ("Double bass", ["E1", "A1", "D2", "G2"])
        ]
        for (instrument, notes) in instruments {
            let app = XCUIApplication()
            app.launchArguments = ["--light", "--mode-tuner", "--tuner-test-cents=0", "-AppleLanguages", "(en)"]
            app.launch()
            app.buttons["tuner-instruments"].tap()
            let profile = app.buttons["tuner-profile-" + instrument]
            XCTAssertTrue(profile.waitForExistence(timeout: 4))
            let library = app.scrollViews.firstMatch
            if !profile.isHittable { library.swipeUp(velocity: .slow) }
            profile.tap()
            for (index, note) in notes.enumerated() {
                let key = app.buttons["tuner-string-\(index)"]
                XCTAssertTrue(key.waitForExistence(timeout: 5))
                XCTAssertEqual(key.label, "\(notes.count - index), " + note)
                key.tap()
                if instrument == "Mandolin" {
                    let first = app.buttons["tuner-course-\(index)-wire-0"]
                    let second = app.buttons["tuner-course-\(index)-wire-1"]
                    XCTAssertEqual(first.value as? String, "In tune")
                    XCTAssertNotEqual(second.value as? String, "In tune")
                    XCTAssertNotEqual(key.value as? String, "In tune")
                    if index == 0 { proof(app, "Mandolin first wire only") }
                    second.tap()
                }
                let tuned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "In tune"), object: key)
                XCTAssertEqual(XCTWaiter.wait(for: [tuned], timeout: 4), .completed)
            }
            XCTAssertFalse(app.buttons["tuner-string-\(notes.count)"].exists)
            let firstKey = app.buttons["tuner-string-0"]
            XCTAssertEqual(firstKey.value as? String, "In tune")
            if instrument != "Mandolin" {
                firstKey.tap()
                let active = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: firstKey)
                XCTAssertEqual(XCTWaiter.wait(for: [active], timeout: 4), .completed)
            }
            proof(app, instrument)
            app.terminate()
        }
    }

    private func pickInstrument(_ id: String, layout: String? = nil, in app: XCUIApplication) {
        app.buttons["tuner-profile-" + id].tap()
        if let layout { app.buttons["tuner-layout-" + layout].tap() }
    }

    private func openReferenceOctaveFour(_ app: XCUIApplication) {
        let target = app.buttons["tuner-reference-target"]
        let octave = Int((target.value as? String)?.suffix(1) ?? "") ?? 4
        target.tap()
        let step = app.buttons[octave > 4 ? "Lower octave" : "Higher octave"]
        for _ in 0..<abs(octave - 4) { step.tap() }
    }

    private func microphonePermissionAlert() -> XCUIElement {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts["kTCCServiceMicrophone-alert"].firstMatch
    }

    private func inputReady(_ app: XCUIApplication, allowUnavailable: Bool = true) -> XCUIElement {
        var states = ["Play a note", "Flat", "Sharp", "In tune", "Almost · flat", "Almost · sharp", "Settling"]
        if allowUnavailable { states.append("Input unavailable") }
        return app.staticTexts.matching(NSPredicate(format: "label IN %@", states)).firstMatch
    }
    private func waitUntilHittable(_ element: XCUIElement) -> Bool {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: element)
        return XCTWaiter.wait(for: [ready], timeout: 4) == .completed
    }
    private func proof(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
