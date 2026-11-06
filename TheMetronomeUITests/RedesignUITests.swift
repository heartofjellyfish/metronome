import XCTest

final class RedesignUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ lang: String = "en", dark: Bool = false, pedal: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["--reference", dark ? "--dark" : "--light", "--redesign-ui-test", "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "zh-Hans" ? "zh_CN" : "en_US"]
        if pedal { app.launchArguments += ["--pedal-ui-test", "--pedal-fixture-bound"] }
        app.launch(); XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 5))
    }
    private func b(_ id: String) -> XCUIElement { app.buttons[id] }
    private func tap(_ id: String) {
        if id.hasPrefix("pattern-family-"), id != "pattern-family-menu" { tap("pattern-family-menu") }
        let value=b(id); reveal(value); value.tap() }
    private func reveal(_ value: XCUIElement) {
        for _ in 0..<7 { if value.exists && value.isHittable { return }; app.scrollViews.firstMatch.swipeUp() }
        for _ in 0..<7 { if value.exists && value.isHittable { return }; app.scrollViews.firstMatch.swipeDown() }
        XCTAssertTrue(value.isHittable,"Missing control: \(value)")
    }
    private func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name=name; a.lifetime = .keepAlways; add(a) }
    func testCategoryDisclosureAndLowerCatalogVisuals() {
        launch(); tap("home-division"); tap("division-patterns"); tap("pattern-family-menu")
        shot("35-category-expanded")
        b("pattern-family-4").tap()
        tap("pattern-4-8"); shot("36-sixteenth-lower-combinations")
        tap("close-panel")
        tap("home-division"); XCTAssertTrue(b("division-patterns").isSelected)
        tap("pattern-family-menu"); b("pattern-family-2").tap()
        tap("pattern-2-1"); tap("pattern-2-2"); shot("37-eighths-hierarchy")
        XCTAssertTrue(b("pattern-2-2").isSelected); tap("close-panel")
    }
    func testDivisionHierarchyPersistentSelectionAndNotation() {
        launch(); tap("home-division")
        tap("division-count-3"); tap("division-count-5"); tap("division-count-7")
        XCTAssertTrue(b("division-count-7").isSelected)
        XCTAssertTrue(b("close-panel").exists)
        app.scrollViews.firstMatch.swipeDown(); shot("30-even-hierarchy")
        tap("close-panel"); shot("31-home-septuplet")
        tap("home-division"); XCTAssertTrue(b("division-count-7").isSelected)
        tap("division-patterns"); tap("pattern-family-3")
        tap("pattern-3-5"); tap("pattern-3-3"); tap("pattern-3-2")
        XCTAssertTrue(b("pattern-3-2").isSelected); shot("32-triplet-hierarchy")
        tap("settings-transport"); XCTAssertEqual(b("settings-transport").label, "Stop metronome")
        tap("pattern-3-5"); tap("pattern-3-3")
        XCTAssertTrue(b("pattern-3-3").isSelected)
        tap("pattern-family-4"); tap("pattern-4-3"); shot("33-sixteenth-hierarchy")
        tap("pattern-4-8"); XCTAssertTrue(b("pattern-4-8").isSelected)
        tap("close-panel"); XCTAssertEqual(b("transport").label, "Stop metronome")
        tap("home-division"); XCTAssertTrue(b("division-patterns").isSelected)
        reveal(b("pattern-4-8")); XCTAssertTrue(b("pattern-4-8").isSelected)
        tap("settings-transport"); tap("close-panel")
        launch("zh-Hans", dark: true); tap("home-division"); tap("division-patterns"); tap("pattern-family-3")
        tap("pattern-3-5"); shot("34-triplets-dark-zh")
    }
    func testRepeatedDivisionSelectionsAuditionsAndReopening() {
        launch(); tap("transport"); tap("home-division")
        reveal(b("division-count-8"))
        shot("01-even-all-eight")
        tap("division-count-5"); XCTAssertTrue(b("division-count-5").isSelected)
        tap("division-count-8"); XCTAssertTrue(b("division-count-8").isSelected)
        tap("division-count-2"); XCTAssertTrue(b("division-count-2").isSelected)
        tap("division-patterns"); tap("pattern-family-3")
        XCTAssertFalse(b("preview-3-5").exists)
        tap("pattern-3-5"); XCTAssertTrue(b("pattern-3-5").isSelected)
        tap("pattern-3-6"); XCTAssertTrue(b("pattern-3-6").isSelected)
        shot("02-triplets-live")
        tap("pattern-family-2"); tap("edit-rhythm")
        tap("editor-grid-4"); if b("Change").exists { b("Change").tap() }
        tap("division-pulse-1"); tap("division-pulse-3")
        tap("2:1")
        shot("03-rhythm-editor")
        tap("use-rhythm"); XCTAssertTrue(b("edit-rhythm").isSelected)
        tap("close-panel"); XCTAssertEqual(b("transport").label,"Stop metronome")
        tap("home-division"); XCTAssertTrue(b("division-patterns").isSelected)
        tap("close-panel"); tap("transport"); tap("home-division"); tap("division-even"); tap("division-count-6")
        XCTAssertTrue(b("division-count-6").isSelected); tap("close-panel")
        tap("home-division"); XCTAssertTrue(b("division-count-6").isSelected); tap("close-panel")
    }
    func testNotationCardsAndCustomRhythmStoppedWorkflow() {
        launch(); tap("home-division"); tap("division-count-7"); tap("close-panel")
        shot("14-home-septuplet")
        tap("home-division"); tap("division-count-6"); tap("close-panel"); shot("15-home-sextuplet")
        tap("transport"); tap("home-division"); tap("division-patterns"); tap("pattern-family-4")
        tap("pattern-4-11"); XCTAssertTrue(b("pattern-4-11").isSelected)
        shot("16-sixteenth-patterns")
        tap("pattern-family-2"); shot("17-eighth-patterns")
        tap("close-panel"); tap("transport"); tap("home-division"); tap("edit-rhythm")
        XCTAssertTrue(app.staticTexts["Customize rhythm"].exists)
        tap("editor-grid-6"); tap("Change")
        tap("division-pulse-1"); tap("division-pulse-3"); tap("division-pulse-4")
        XCTAssertEqual(b("division-pulse-1").value as? String, "Rest")
        shot("18-custom-six-slots")
        tap("use-rhythm"); XCTAssertTrue(b("edit-rhythm").isSelected); tap("close-panel")
        tap("home-division"); XCTAssertTrue(b("edit-rhythm").isSelected)
        tap("edit-rhythm"); XCTAssertTrue(b("editor-grid-6").isSelected)
        XCTAssertEqual(b("division-pulse-4").value as? String, "Rest")
        tap("division-pulse-0"); tap("close-panel") // Back discards a stopped draft.
        tap("edit-rhythm"); XCTAssertEqual(b("division-pulse-0").value as? String, "Sound")
        tap("division-pulse-0"); tap("division-pulse-2"); tap("division-pulse-5")
        XCTAssertEqual(b("division-pulse-5").value as? String, "Sound") // keep the final note
        XCTAssertTrue(app.staticTexts["Keep at least one note."].exists)
        tap("close-panel"); tap("close-panel")
    }
    func testChineseCustomRhythmAndDarkPatternLayout() {
        launch("zh-Hans"); tap("home-division"); tap("edit-rhythm"); tap("editor-grid-4")
        tap("division-pulse-1"); tap("division-pulse-3"); tap("2:1")
        XCTAssertTrue(b("use-rhythm").isHittable)
        XCTAssertLessThan(b("use-rhythm").frame.maxY, b("settings-transport").frame.minY - 8)
        shot("19-custom-zh-top")
        reveal(b("use-rhythm")); shot("20-custom-zh-use")
        tap("use-rhythm")
        launch("en", dark: true); tap("home-division"); tap("division-patterns"); tap("pattern-family-4")
        shot("21-patterns-dark")
    }
    func testChineseSettingsCurrentSoundAndPracticeHierarchy() {
        launch("zh-Hans"); tap("settings"); tap("all-sounds"); tap("classic-sound-16"); tap("close-panel")
        XCTAssertTrue(b("recommended-sound-16").isSelected)
        XCTAssertFalse(b("settings-meter").exists); XCTAssertFalse(b("settings-division").exists)
        shot("04-settings-zh")
        tap("practice"); shot("05-practice-zh")
        tap("practice-polyrhythm"); tap("polyrhythm-3-2"); tap("polyrhythm-4-3"); XCTAssertTrue(b("polyrhythm-4-3").exists)
        shot("06-polyrhythm-zh"); tap("close-panel"); XCTAssertTrue(b("practice-gap").exists)
        tap("practice-gap"); shot("07-silent-bars-zh"); tap("close-panel"); tap("close-panel"); tap("close-settings")
    }
    func testSetlistContainsSongsDraftCancellationAndPedalEquivalentNavigation() {
        launch(); tap("settings"); tap("settings-setlists"); tap("setlist-Saturday")
        tap("song-Gossip"); tap("performance-play"); tap("performance-next"); tap("close-performance")
        XCTAssertTrue(b("song-男孩别哭").isSelected); shot("08-setlist-playing")
        tap("edit-setlist"); tap("edit-song-Gossip"); shot("09-song-editor")
        tap("song-division"); tap("division-count-5"); tap("song-picker-back"); tap("Cancel")
        tap("edit-setlist"); tap("add-song"); tap("import-presets"); tap("import-preset-Warm hands")
        XCTAssertTrue(b("song-Warm hands").waitForExistence(timeout: 3))
        tap("song-Warm hands"); shot("10-song-imported"); tap("close-performance")
        tap("close-panel"); tap("close-settings"); XCTAssertEqual(b("transport").label,"Stop metronome"); tap("transport")
    }
    func testDarkDivisionAndSavedPedalStatus() {
        launch("zh-Hans",dark:true,pedal:true); tap("home-division"); shot("11-even-dark"); tap("close-panel")
        tap("settings"); tap("settings-pedal")
        XCTAssertEqual(b("pedal-toggle").value as? String,"回车键")
        XCTAssertFalse(app.staticTexts["已连接"].exists)
        shot("12-pedal-saved-dark")
        tap("pedal-toggle"); shot("13-pedal-learning-dark"); tap("pedal-toggle")
        XCTAssertEqual(b("pedal-toggle").value as? String,"回车键")
        tap("pedal-help"); reveal(b("pedal-midi")); XCTAssertTrue(b("pedal-midi").exists)
        tap("close-panel"); tap("settings-pedal"); XCTAssertEqual(b("pedal-toggle").value as? String,"回车键")
    }
}
