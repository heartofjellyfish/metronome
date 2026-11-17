import XCTest

final class ModeNavigationTests: XCTestCase {
    func testModeChooserReplacesTempoScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["tempoDisplay"].waitForExistence(timeout: 8))
        let screen = app.buttons["tempoDisplay"].frame
        let tempoLabel = app.buttons["tempoDisplay"].label
        let transport = app.buttons["transport"].frame
        app.buttons["mode-menu"].tap()
        XCTAssertFalse(app.buttons["tempoDisplay"].exists)
        for name in ["metronome", "practice", "live"] {
            let frame = app.buttons["mode-\(name)"].frame
            XCTAssertTrue(screen.contains(frame))
        }
        XCTAssertTrue(app.buttons["mode-metronome"].isSelected)
        proof(app, "Mode selection inside original display")
        // First tap outside consumes the gesture, including taps over playback.
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: transport.midX, dy: transport.midY)).tap()
        XCTAssertTrue(app.buttons["tempoDisplay"].exists)
        XCTAssertEqual(app.buttons["tempoDisplay"].label, tempoLabel)
        XCTAssertEqual(app.buttons["transport"].frame, transport)
        let stopped = app.buttons["transport"].label
        app.buttons["transport"].tap()
        let playing = app.buttons["transport"].label
        XCTAssertNotEqual(stopped, playing)
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        XCTAssertEqual(app.buttons["transport"].label, playing)
        app.buttons["mode-menu"].tap()
        app.buttons["mode-practice"].tap()
        XCTAssertTrue(app.buttons["practice-ramp"].waitForExistence(timeout: 3))
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        XCTAssertEqual(app.buttons["transport"].label, playing)
        XCTAssertEqual(app.buttons["tempoDisplay"].label, tempoLabel)
        app.buttons["transport"].tap()
    }
    func testRefinedModeJourneys() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--redesign-ui-test", "--many-setlists", "--mode-live", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["live-all-setlists"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["live-new-setlist"].exists)
        XCTAssertFalse(app.buttons["live-tool-pedal"].exists)
        proof(app, "Live two recessed lists")
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "live-setlist-"))
        let first = rows.firstMatch.identifier
        rows.firstMatch.swipeUp()
        XCTAssertNotEqual(rows.firstMatch.identifier, first)
        let song = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "live-song-")).firstMatch
        song.tap()
        XCTAssertTrue(app.buttons["performance-play"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["performance-next"].exists)
        app.buttons["close-performance"].tap()
        app.buttons["live-all-songs"].tap()
        XCTAssertTrue(app.buttons["library-new-song"].waitForExistence(timeout: 3))
        app.buttons["close-panel"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-practice"].tap()
        XCTAssertFalse(app.buttons["practice-countIn"].exists)
        proof(app, "Three focused practice tools")
    }
    func testRepeatedModeSwitchingPreservesTransport() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["mode-menu"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["mode-menu"].label, "Metronome")
        proof(app, "Collapsed text mode trigger")
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["all-sounds"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["practice"].exists)
        XCTAssertFalse(app.buttons["settings-setlists"].exists)
        XCTAssertFalse(app.buttons["settings-songLibrary"].exists)
        XCTAssertFalse(app.buttons["settings-presets"].exists)
        proof(app, "Settings — sound and general only")
        app.buttons["close-settings"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-menu-close"].tap()
        XCTAssertFalse(app.buttons["mode-live"].exists)
        app.buttons["mode-menu"].tap()
        let widths = ["metronome", "practice", "live"].map { app.buttons["mode-\($0)"].frame.width }
        XCTAssertEqual(widths[0], widths[1], accuracy: 1)
        XCTAssertEqual(widths[1], widths[2], accuracy: 1)
        proof(app, "Mode chooser — equal widths")
        app.buttons["mode-metronome"].tap()
        app.buttons["transport"].tap()
        let playingLabel = app.buttons["transport"].label
        app.buttons["mode-menu"].tap()
        app.buttons["mode-practice"].tap()
        XCTAssertTrue(app.buttons["practice-ramp"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["mode-menu"].label, "Practice")
        proof(app, "Practice mode")
        app.buttons["mode-menu"].tap()
        assertMenuAnchor(app)
        proof(app, "Practice menu anchor")
        app.buttons["mode-live"].tap()
        XCTAssertEqual(app.buttons["settings-transport"].label, playingLabel)
        XCTAssertEqual(app.buttons["mode-menu"].label, "Live")
        proof(app, "Live mode")
        app.buttons["mode-menu"].tap()
        assertMenuAnchor(app)
        proof(app, "Live menu anchor")
        app.buttons["mode-metronome"].tap()
        XCTAssertEqual(app.buttons["transport"].label, playingLabel)
        app.buttons["transport"].tap()
        app.buttons["mode-menu"].tap()
        app.buttons["mode-metronome"].tap()
        XCTAssertFalse(app.buttons["mode-live"].exists)
        XCTAssertTrue(app.buttons["tempoDisplay"].exists)
        XCTAssertEqual(app.buttons["mode-menu"].label, "Metronome")
    }
    func testLiveHomeRoutesAndEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "--mode-live", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["live-new-setlist"].waitForExistence(timeout: 8))
        proof(app, "First visit Live")
        app.buttons["live-new-setlist"].tap()
        XCTAssertTrue(app.buttons["cancel-setlist"].waitForExistence(timeout: 3))
        app.buttons["cancel-setlist"].tap()
        app.buttons["close-panel"].tap()
        app.buttons["live-all-songs"].tap()
        XCTAssertTrue(app.buttons["library-new-song"].waitForExistence(timeout: 3))
    }
    func testPolyrhythmNeedleVisualProof() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "--mode-practice", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["practice-polyrhythm"].waitForExistence(timeout: 8))
        app.buttons["practice-polyrhythm"].tap()
        app.buttons["practice-transport"].tap()
        proof(app, "Track pulse running 1")
        proof(app, "Track pulse running 2")
        app.buttons["poly-mute-0"].tap()
        proof(app, "Track pulse muted voice")
        app.buttons["practice-transport"].tap()
    }
    func testPolyrhythmStackedCardsAndTempoReference() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "--mode-practice", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["practice-polyrhythm"].waitForExistence(timeout: 8))
        app.buttons["practice-polyrhythm"].tap()
        XCTAssertEqual(app.buttons["poly-reference-picker"].value as? String, "A")
        XCTAssertFalse(app.buttons["poly-third"].exists)
        proof(app, "Polyrhythm A two voices")
        app.buttons["poly-plus-0"].tap()
        app.buttons["poly-minus-0"].tap()
        app.buttons["practice-transport"].tap()
        app.buttons["poly-reference-picker"].tap()
        app.buttons["poly-reference-1"].tap()
        XCTAssertEqual(app.buttons["poly-reference-picker"].value as? String, "B")
        app.buttons["poly-reference-picker"].tap()
        app.buttons["poly-reference-0"].tap()
        app.buttons["poly-mute-0"].tap()
        XCTAssertEqual(app.buttons["poly-mute-0"].value as? String, "Muted")
        app.buttons["poly-mute-0"].tap()
        app.buttons["poly-more"].tap()
        app.swipeUp()
        app.buttons["poly-third"].tap()
        app.buttons["poly-reference-picker"].tap()
        app.buttons["poly-reference-2"].tap()
        app.swipeUp()
        app.buttons["poly-third"].tap()
        XCTAssertEqual(app.buttons["poly-reference-picker"].value as? String, "A")
        app.buttons["close-panel"].tap()
        app.buttons["practice-polyrhythm"].tap()
        XCTAssertFalse(app.buttons["poly-plus-2"].exists)
        XCTAssertFalse(app.buttons["poly-third"].exists)
        proof(app, "Polyrhythm A restored")
    }
    func testPracticeScreensAndRepeatedChoices() {
        let app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--organization-ui-test", "--mode-practice", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["practice-ramp"].waitForExistence(timeout: 8))
        proof(app, "Practice redesigned")
        app.buttons["practice-ramp"].tap()
        XCTAssertTrue(app.staticTexts["Start"].waitForExistence(timeout: 3))
        proof(app, "Tempo ramp redesigned")
        app.buttons["close-panel"].tap()
        app.buttons["practice-gap"].tap()
        proof(app, "Silent bars redesigned")
        app.buttons["close-panel"].tap()
        app.buttons["practice-polyrhythm"].tap()
        app.buttons["polyrhythm-4-3"].tap()
        if !app.buttons["polyrhythm-5-4"].exists { app.buttons["poly-more"].tap() }
        app.buttons["polyrhythm-5-4"].tap()
        XCTAssertTrue(app.buttons["polyrhythm-5-4"].isSelected)
        app.buttons["practice-transport"].tap()
        app.buttons["poly-mute-0"].tap()
        XCTAssertEqual(app.buttons["poly-mute-0"].value as? String, "Muted")
        app.buttons["poly-mute-1"].tap()
        XCTAssertEqual(app.buttons["poly-mute-1"].value as? String, "Muted")
        app.buttons["poly-plus-0"].tap()
        proof(app, "Polyrhythm independent muted voices")
        if !app.buttons["polyrhythm-5-4"].exists { app.buttons["poly-more"].tap() }
        app.buttons["polyrhythm-5-4"].tap()
        app.buttons["poly-third"].tap()
        XCTAssertTrue(app.buttons["poly-plus-2"].waitForExistence(timeout: 3))
        app.buttons["poly-plus-2"].tap()
        app.buttons["poly-minus-2"].tap()
        app.buttons["poly-mute-2"].tap()
        XCTAssertEqual(app.buttons["poly-mute-2"].value as? String, "Muted")
        app.buttons["poly-reference-picker"].tap()
        app.buttons["poly-reference-0"].tap()
        proof(app, "Three voices and bottom tempo")
        app.buttons["poly-reference-picker"].tap()
        app.buttons["poly-reference-1"].tap()
        app.buttons["close-panel"].tap()
        app.buttons["practice-polyrhythm"].tap()
        app.buttons["poly-more"].tap()
        XCTAssertTrue(app.buttons["polyrhythm-5-4"].isSelected)
        XCTAssertTrue(app.buttons["poly-plus-2"].exists)
        proof(app, "Polyrhythm remembered controls")
        app.buttons["close-panel"].tap()
        app.buttons["settings"].tap()
        app.buttons["settings-count-in"].tap()
        app.buttons["1 bar"].tap()
        app.buttons["2 bars"].tap()
        XCTAssertTrue(app.buttons["2 bars"].isSelected)
        proof(app, "Count-in redesigned")
        app.buttons["close-panel"].tap()
        app.buttons["close-settings"].tap()

    }
    private func assertMenuAnchor(_ app: XCUIApplication) {
        let header = app.buttons["mode-menu"].frame
        let item = app.buttons["mode-metronome"].frame
        // Choices now live inside the shared LCD, below its Choose mode heading.
        XCTAssertLessThan(item.minY - header.maxY, 60)
        XCTAssertGreaterThanOrEqual(item.minY, header.maxY - 1)
        XCTAssertLessThan(abs(item.minX - header.minX), 40)
    }
    private func proof(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
