import XCTest

final class PerformanceUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ lang: String = "zh-Hans", dark: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["--reference", dark ? "--dark" : "--light", "--redesign-ui-test", "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "zh-Hans" ? "zh_CN" : "en_US"]
        app.launch(); XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 5))
    }
    private func b(_ id: String) -> XCUIElement {
        let matches = app.buttons.matching(identifier: id).allElementsBoundByIndex
        return matches.first { $0.isHittable } ?? app.buttons[id].firstMatch
    }
    private func tap(_ id: String) {
        let button = b(id)
        for _ in 0..<7 { if button.exists && button.isHittable { break }; (app.scrollViews.allElementsBoundByIndex.last { $0.isHittable } ?? app.scrollViews.firstMatch).swipeUp() }
        if !button.isHittable { print(app.debugDescription) }
        XCTAssertTrue(button.isHittable, "Missing \(id)"); button.tap()
    }
    private func shot(_ name: String) { RunLoop.current.run(until: Date().addingTimeInterval(0.4)); let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    private func openList(_ name: String) { tap("settings"); tap("settings-setlists"); tap("setlist-\(name)") }
    func testStartSetlistNotesAndExitToInstrument() {
        launch(); tap("settings"); tap("settings-setlists"); shot("01-root")
        tap("setlist-周六演出"); shot("02-song-list")
        tap("start-setlist")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "Gossip")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        XCTAssertEqual(app.staticTexts["performance-position"].label, "第 1 首 · 共 3 首")
        tap("performance-edit")
        let notes = app.textFields["song-notes"].firstMatch
        notes.tap(); notes.typeText("Intro: wait four bars. Last chorus: stop on one.")
        tap("save-song"); XCTAssertTrue(app.staticTexts["performance-notes"].exists)
        shot("03-live-with-notes")
        tap("view-song-notes"); shot("04-notes-expanded"); tap("close-performance-overlay")
        tap("performance-next"); XCTAssertFalse(b("view-song-notes").exists)
        tap("performance-previous"); XCTAssertTrue(b("view-song-notes").exists)
        tap("exit-live-mode")
        XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
        XCTAssertEqual(b("transport").label, "停止播放")
        tap("transport"); tap("presets"); tap("song-Gossip")
        XCTAssertTrue(app.staticTexts["performance-notes"].exists)
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("exit-live-mode"); XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
        tap("settings"); tap("settings-setlists"); tap("edit-setlist"); tap("setlist-周六演出")
        tap("duplicate-setlist"); tap("choose-setlist")
        XCTAssertTrue(b("setlist-周六演出 副本").exists)
    }
    func testDirectSongLibraryEntry() {
        launch(); tap("settings"); shot("05-settings-live-entries")
        tap("settings-songLibrary"); XCTAssertTrue(b("import-song-Gossip").exists)
        XCTAssertFalse(b("choose-setlist").exists); shot("06-song-library")
        tap("import-song-Gossip"); tap("cancel-song")
        XCTAssertTrue(b("import-song-Gossip").exists)
        tap("close-panel"); tap("settings-setlists")
        XCTAssertTrue(b("setlist-周六演出").exists)
    }
    func testSettledNavigationScreens() {
        launch(); tap("settings"); tap("settings-setlists"); shot("09-root-zh")
        tap("setlist-周六演出"); XCTAssertTrue(b("song-Gossip").exists); shot("10-list-zh")
        tap("song-男孩别哭"); tap("performance-play"); shot("11-live-zh")
        tap("performance-play"); tap("close-performance")
        tap("choose-setlist"); XCTAssertTrue(b("setlist-周六演出").exists)
    }
    func testPerformanceVisualOnlyRepeatedSongsTempoAndReturning() {
        launch(); tap("settings"); tap("general-sound-off"); tap("close-settings")
        openList("周六演出"); shot("01-songs-zh"); tap("song-男孩别哭")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        XCTAssertFalse(b("performance-sound").exists)
        XCTAssertFalse(b("performance-division").exists)
        XCTAssertFalse(b("performance-plus").exists)
        XCTAssertTrue(app.staticTexts["下一首"].exists)
        tap("performance-play")
        let cue = app.otherElements["performance-beat"]
        XCTAssertTrue(cue.waitForExistence(timeout: 3))
        let beat = cue.value as? String ?? ""
        let changes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", beat), object: cue)
        XCTAssertEqual(XCTWaiter.wait(for: [changes], timeout: 3), .completed)
        shot("02-live-playing-zh")
        tap("performance-next"); XCTAssertEqual(app.staticTexts["performance-song"].label, "夜来香"); XCTAssertFalse(b("performance-next").isEnabled)
        tap("performance-previous"); XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        tap("performance-previous"); XCTAssertEqual(app.staticTexts["performance-song"].label, "Gossip"); XCTAssertFalse(b("performance-previous").isEnabled)
        tap("performance-next")
        tap("performance-edit"); shot("03-live-editor")
        let tempo = app.textFields["BPM"]; tempo.tap(); tempo.typeText("87"); tap("save-song")
        XCTAssertEqual(app.staticTexts["performance-tempo"].label, "87 BPM")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("performance-edit"); tap("cancel-song")
        XCTAssertEqual(app.staticTexts["performance-tempo"].label, "87 BPM")
        tap("close-performance"); XCTAssertTrue(b("song-男孩别哭").isSelected)
        XCTAssertFalse(b("setlist-play").exists)
        tap("song-夜来香"); XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("close-performance"); tap("song-男孩别哭")
        XCTAssertEqual(app.staticTexts["performance-tempo"].label, "87 BPM")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("close-performance"); tap("close-panel"); tap("close-settings")
        XCTAssertTrue(b("home-muted").exists)
        XCTAssertTrue((b("presets").value as? String ?? "").contains("男孩别哭"))
        tap("home-muted"); XCTAssertFalse(b("home-muted").exists); tap("transport")
    }
    func testStoppedNavigationAndControlRows() {
        launch(); openList("周六演出"); tap("song-Gossip")
        XCTAssertFalse(b("performance-previous").isEnabled)
        XCTAssertTrue(b("performance-next").label.contains("男孩别哭"))
        tap("performance-next")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        XCTAssertEqual(b("performance-play").label, "开始播放")
        XCTAssertTrue(b("performance-next").label.contains("夜来香"))
        XCTAssertEqual(b("performance-previous").frame.midY, b("performance-next").frame.midY, accuracy: 2)
        XCTAssertEqual(b("performance-tap").frame.midY, b("performance-play").frame.midY, accuracy: 2)
        XCTAssertEqual(app.staticTexts["performance-tempo"].frame.midY, app.staticTexts["performance-meter"].frame.midY, accuracy: 2)
        XCTAssertFalse(b("performance-tempo").exists); XCTAssertFalse(b("performance-meter").exists)
        shot("04-live-stopped")
        tap("performance-next"); XCTAssertFalse(b("performance-next").isEnabled)
        tap("performance-previous"); tap("performance-previous")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "Gossip")
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("performance-tap"); tap("performance-tap")
        XCTAssertTrue(b("performance-play").isHittable)
    }
    func testSettingsStartsAtRootAndHomeKeepsRecentLoadedSong() {
        launch("en"); openList("Saturday"); tap("song-Gossip")
        tap("close-performance"); tap("choose-setlist")
        XCTAssertTrue(b("setlist-Saturday").exists)
        tap("new-setlist")
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Sunday"); tap("create-setlist")
        tap("add-song"); shot("05-add-song-sources")
        tap("import-presets"); tap("import-preset-Warm hands")
        XCTAssertTrue(b("song-Warm hands").exists)
        tap("close-panel"); tap("close-settings")
        XCTAssertTrue((b("presets").value as? String ?? "").contains("Gossip"))
        tap("presets"); XCTAssertTrue(b("song-Gossip").exists)
        XCTAssertFalse(b("song-Warm hands").exists); tap("close-panel")
        tap("settings"); tap("settings-setlists")
        XCTAssertTrue(b("setlist-Saturday").exists); XCTAssertTrue(b("setlist-Sunday").exists)
        shot("06-all-setlists")
        tap("setlist-Sunday"); XCTAssertFalse(b("song-Warm hands").isSelected)
        tap("song-Warm hands"); XCTAssertEqual(app.staticTexts["performance-song"].label, "Warm hands")
        tap("close-performance"); tap("close-panel"); tap("close-settings")
        XCTAssertTrue((b("presets").value as? String ?? "").contains("Sunday"))
        tap("presets"); XCTAssertTrue(b("song-Warm hands").exists)
        tap("close-panel"); tap("settings"); tap("settings-setlists")
        XCTAssertTrue(b("setlist-Saturday").exists); XCTAssertTrue(b("setlist-Sunday").exists)
    }
    func testSharedSongAddEditRemoveAndReuse() {
        launch("en"); openList("Saturday"); tap("choose-setlist")
        tap("new-setlist"); let field = app.textFields["setlist-name"]; field.tap(); field.typeText("Sunday"); tap("create-setlist")
        tap("add-song"); tap("import-songs"); tap("import-song-Gossip")
        tap("edit-setlist"); tap("edit-song-Gossip")
        let tempo = app.textFields["BPM"]; tempo.tap(); tempo.typeText("141"); tap("save-song")
        tap("edit-setlist"); tap("choose-setlist"); tap("setlist-Saturday")
        XCTAssertTrue(b("song-Gossip").label.contains("141"))
        tap("edit-setlist"); tap("share-song-男孩别哭"); shot("04-song-targets")
        tap("share-to-Sunday"); tap("edit-setlist"); tap("choose-setlist"); tap("setlist-Sunday")
        XCTAssertTrue(b("song-男孩别哭").exists)
        tap("edit-setlist"); tap("delete-song-Gossip"); tap("Remove")
        XCTAssertFalse(b("song-Gossip").exists)
        tap("edit-setlist"); tap("add-song"); tap("import-songs"); XCTAssertTrue(b("import-song-Gossip").exists)
        tap("import-song-Gossip"); XCTAssertTrue(b("song-Gossip").label.contains("141"))
        shot("05-song-reused")
    }
    func testPracticeEntryAndImmediateInPlacePlayback() {
        launch(); tap("settings"); tap("practice"); shot("06-practice-compact-zh")
        XCTAssertFalse(b("practice-save-preset").exists); XCTAssertTrue(b("practice-transport").exists)
        XCTAssertFalse(b("TOUCH FEEDBACK-on").exists)
        tap("practice-gap"); tap("SOUND / SILENCE-on"); tap("practice-transport")
        XCTAssertEqual(b("practice-transport").label, "停止播放"); shot("07-practice-playing-zh")
        tap("close-panel"); XCTAssertTrue(b("practice-gap").exists)
        tap("practice-ramp"); XCTAssertEqual(b("practice-transport").label, "停止播放")
        tap("practice-transport"); tap("close-panel"); tap("close-panel")
        tap("general-haptics-off"); tap("general-haptics-on"); shot("08-general-haptics")
    }
    func testLibraryCreateSearchEditDeleteAndAddNavigation() {
        launch("en"); openList("Saturday")
        tap("add-song"); XCTAssertFalse(b("song-Gossip").exists); shot("13-add-sources")
        tap("new-song"); tap("cancel-song"); XCTAssertTrue(b("new-song").exists)
        tap("choose-setlist"); XCTAssertTrue(b("song-Gossip").exists)
        tap("choose-setlist"); tap("manage-song-library")
        tap("library-new-song")
        app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Encore")
        tap("save-song"); XCTAssertTrue(b("import-song-Encore").exists)
        let search = app.textFields["song-search"]; search.tap(); search.typeText("Encore"); search.typeText("\n")
        XCTAssertFalse(b("import-song-Gossip").exists)
        tap("import-song-Encore"); let tempo = app.textFields["BPM"]; tempo.tap(); tempo.typeText("127"); tap("save-song")
        tap("library-share-Encore"); tap("share-to-Saturday")
        let searchAgain = app.textFields["song-search"]; searchAgain.tap(); searchAgain.typeText("Encore\n")
        shot("14-library-song")
        tap("library-delete-Encore"); shot("15-library-delete-confirmation")
        tap("Cancel"); XCTAssertTrue(b("import-song-Encore").exists)
        tap("library-delete-Encore"); tap("confirm-delete-library-song")
        XCTAssertFalse(b("import-song-Encore").exists)
        tap("choose-setlist"); tap("setlist-Saturday"); XCTAssertFalse(b("song-Encore").exists)
    }
    func testSetlistRenameReorderAndDeleteKeepsLibrary() {
        launch("en"); openList("Saturday"); tap("edit-setlist")
        let grip = app.images["drag-song-Gossip"]
        let second = app.images["drag-song-男孩别哭"]
        XCTAssertTrue(grip.isHittable); XCTAssertTrue(second.isHittable)
        grip.press(forDuration: 0.8, thenDragTo: second)
        XCTAssertGreaterThan(b("song-Gossip").frame.minY, b("song-男孩别哭").frame.minY)
        shot("07-reordered-songs")
        app.images["drag-song-Gossip"].press(forDuration: 0.8, thenDragTo: app.images["drag-song-男孩别哭"])
        XCTAssertLessThan(b("song-Gossip").frame.minY, b("song-男孩别哭").frame.minY)
        let name = app.textFields["setlist-name"]; name.tap()
        let old = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "Friday")
        tap("Rename"); XCTAssertTrue(app.staticTexts["Friday"].exists)
        shot("19-setlist-edit")
        tap("Delete setlist"); tap("Cancel"); XCTAssertTrue(b("song-Gossip").exists)
        tap("Delete setlist"); tap("DELETE")
        XCTAssertFalse(b("setlist-Friday").exists); tap("manage-song-library")
        XCTAssertTrue(b("import-song-Gossip").exists)
    }
    func testPolyrhythmBothSoundsAndSharedPlaybackAcrossPages() {
        launch(); tap("settings"); tap("practice"); tap("practice-polyrhythm")
        tap("polyrhythm-3-2"); tap("practice-transport")
        tap("poly-lane-0"); tap("poly-sound-1"); tap("poly-sound-5")
        XCTAssertTrue(b("poly-sound-5").isSelected); XCTAssertEqual(b("practice-transport").label, "停止播放")
        shot("16-poly-instrument-picker"); tap("close-panel")
        tap("poly-lane-1"); tap("poly-sound-16"); XCTAssertTrue(b("poly-sound-16").isSelected)
        tap("close-panel"); tap("polyrhythm-4-3"); shot("17-poly-two-instruments")
        tap("close-panel"); tap("practice-polyrhythm"); tap("poly-lane-0")
        XCTAssertTrue(b("poly-sound-5").isSelected); tap("close-panel")
        tap("poly-lane-1"); XCTAssertTrue(b("poly-sound-16").isSelected); tap("close-panel")
        tap("polyrhythm-off"); tap("close-panel"); tap("close-panel"); tap("close-settings")
        tap("home-division"); tap("division-count-2"); tap("division-count-3")
        tap("division-patterns"); tap("pattern-family-3"); tap("pattern-3-5"); tap("pattern-3-6")
        XCTAssertTrue(b("pattern-3-6").isSelected); XCTAssertFalse(b("preview-3-5").exists)
        XCTAssertEqual(b("settings-transport").label, "停止播放"); shot("18-pattern-shared-playback")
        tap("settings-transport"); XCTAssertEqual(b("settings-transport").label, "开始播放")
        tap("settings-transport"); tap("close-panel"); tap("home-division")
        XCTAssertTrue(b("division-patterns").isSelected); tap("close-panel"); tap("transport")
    }
    func testFinalVisualStates() {
        launch(); openList("周六演出"); shot("20-setlist-browse-final")
        tap("add-song"); shot("21-add-sources-zh-final"); tap("choose-setlist"); tap("close-panel")
        tap("practice"); tap("practice-polyrhythm"); tap("polyrhythm-3-2"); tap("polyrhythm-4-3")
        tap("practice-transport"); XCTAssertTrue(b("polyrhythm-4-3").isSelected); shot("22-poly-selection-final")
        tap("close-panel"); tap("close-panel"); tap("close-settings"); tap("home-division"); tap("division-patterns")
        XCTAssertTrue(b("division-patterns").isSelected); shot("23-pattern-selection-final"); tap("settings-transport")
    }
    func testDarkPerformanceEditCancelSaveAndReopenKeepsPlaying() {
        launch("en", dark: true); openList("Saturday"); tap("song-Gossip"); tap("performance-play")
        tap("performance-edit"); tap("song-division"); tap("division-count-3")
        tap("cancel-song")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        tap("performance-edit"); tap("song-division"); tap("division-count-2"); tap("save-song")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        tap("performance-edit"); tap("song-division")
        XCTAssertTrue(b("division-count-2").isSelected)
        tap("division-count-3"); tap("save-song")
        shot("08-live-dark"); tap("performance-play"); tap("close-performance")
    }
}
