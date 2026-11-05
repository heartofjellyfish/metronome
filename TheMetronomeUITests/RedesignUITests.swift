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
    private func tap(_ id: String) { let value=b(id); reveal(value); value.tap() }
    private func reveal(_ value: XCUIElement) {
        for _ in 0..<7 { if value.exists && value.isHittable { return }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(value.isHittable,"Missing control: \(value)")
    }
    private func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name=name; a.lifetime = .keepAlways; add(a) }
    func testRepeatedDivisionSelectionsAuditionsAndReopening() {
        launch(); tap("transport"); tap("home-division")
        XCTAssertTrue(b("division-count-8").isHittable)
        shot("01-even-all-eight")
        tap("division-count-5"); XCTAssertTrue(b("division-count-5").isSelected)
        tap("division-count-8"); XCTAssertTrue(b("division-count-8").isSelected)
        tap("division-count-2"); XCTAssertTrue(b("division-count-2").isSelected)
        tap("division-patterns"); tap("pattern-family-3")
        tap("preview-3-5"); XCTAssertFalse(b("pattern-3-5").isSelected)
        tap("pattern-3-5"); XCTAssertTrue(b("pattern-3-5").isSelected)
        tap("pattern-3-6"); XCTAssertTrue(b("pattern-3-6").isSelected)
        shot("02-triplets-live")
        tap("pattern-family-2"); tap("edit-rhythm")
        tap("editor-grid-4"); if b("Change").exists { b("Change").tap() }
        tap("division-pulse-1"); tap("division-pulse-3")
        tap("swing-options"); tap("2:1")
        reveal(b("preview-draft")); shot("03-rhythm-editor")
        tap("close-panel"); XCTAssertEqual(b("transport").label,"Stop metronome")
        tap("home-division"); XCTAssertTrue(b("division-patterns").isSelected)
        tap("close-panel"); tap("transport"); tap("home-division"); tap("division-even"); tap("division-count-6")
        XCTAssertTrue(b("home-division").waitForExistence(timeout: 2)); XCTAssertFalse(b("division-count-6").exists)
        tap("home-division"); XCTAssertTrue(b("division-count-6").isSelected); tap("close-panel")
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
        tap("song-Gossip"); tap("setlist-play"); tap("Next song")
        XCTAssertTrue(b("song-男孩别哭").isSelected); shot("08-setlist-playing")
        tap("edit-setlist"); tap("edit-song-Gossip"); shot("09-song-editor")
        tap("song-division"); tap("division-count-5"); tap("Cancel")
        tap("edit-setlist"); tap("add-song"); tap("import-presets"); tap("import-preset-Warm hands")
        XCTAssertTrue(b("song-Warm hands").waitForExistence(timeout: 3))
        tap("song-Warm hands"); shot("10-song-imported")
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
