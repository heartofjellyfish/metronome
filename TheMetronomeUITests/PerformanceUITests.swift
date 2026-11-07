import XCTest

final class PerformanceUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ lang: String = "zh-Hans", dark: Bool = false, manyLists: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["--reference", dark ? "--dark" : "--light", "--redesign-ui-test", "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "zh-Hans" ? "zh_CN" : "en_US"]
        if manyLists { app.launchArguments.append("--many-setlists") }
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
    private func settleDrop() { RunLoop.current.run(until: Date().addingTimeInterval(0.6)) }
    private func swipeKeyboardAway() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.23))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.42)))
    }
    private func enterTempo(_ value: String) {
        for digit in value { tap("key-\(digit)") }
        tap("panelApply")
    }
    private func openList(_ name: String) { tap("settings"); tap("settings-setlists"); tap("setlist-\(name)") }
    func testSongNameTypingWhileLive() throws { try measureSongName(playing: true) }
    func testSongNameTypingWhileStopped() throws { try measureSongName(playing: false) }
    private func measureSongName(playing: Bool) throws {
        guard #available(iOS 26, *) else { throw XCTSkip("Hitch measurements require iOS 26.") }
        launch("en"); openList("Saturday"); tap("song-Gossip"); if playing { tap("performance-play") }; tap("performance-edit")
        let name = app.textFields["song-name"]
        name.tap()
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTHitchMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            name.typeText("Crisis" + String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        }
        XCTAssertEqual(name.value as? String, "Gossip")
    }
    func testTypingInExistingPhoneLibraryWithoutSaving() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("This journey measures the physical device.")
        #else
        guard #available(iOS 26, *) else { throw XCTSkip("Requires iOS 26.") }
        app = XCUIApplication()
        app.launch()
        tap("settings"); tap("settings-songLibrary")
        let pencil = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-edit-")).firstMatch
        if pencil.exists { pencil.tap() } else { tap("library-new-song") }
        let name = app.textFields["song-name"]
        name.tap()
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTHitchMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            name.typeText("Crisis" + String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        }
        swipeKeyboardAway()
        tap("cancel-song")
        #endif
    }
    func testSongMeterAndCategorizedSounds() {
        launch("en"); openList("Saturday"); tap("song-Gossip"); tap("performance-edit")
        tap("song-meter"); tap("meter-6-8")
        XCTAssertTrue(b("meter-6-8").isSelected)
        tap("More meters")
        shot("27-song-meter")
        tap("song-picker-back"); tap("song-sound")
        tap("acoustic-sound-5"); XCTAssertTrue(b("acoustic-sound-5").isSelected)
        tap("classic-sound-16"); XCTAssertTrue(b("classic-sound-16").isSelected)
        shot("27-song-sounds")
        tap("song-picker-back"); tap("cancel-song")
        XCTAssertEqual(app.staticTexts["performance-meter"].label, "4/4")
        tap("performance-edit"); tap("song-meter"); tap("meter-3-4"); tap("song-picker-back"); tap("save-song")
        XCTAssertEqual(app.staticTexts["performance-meter"].label, "3/4")
    }
    func testOverflowSearchAndFrequentSetlists() {
        launch("en", manyLists: true)
        tap("settings"); tap("settings-setlists")
        let search = app.textFields["setlist-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        XCTAssertTrue(app.staticTexts["Frequently used"].exists)
        search.typeText("Tour 24")
        XCTAssertFalse(b("setlist-Saturday").exists)
        tap("setlist-Tour 24"); tap("song-Gossip")
        XCTAssertEqual(b("close-performance").value as? String, "Tour 24")
        shot("25-live")
        tap("performance-edit"); shot("25-editor")
    }
    func testLibraryRepeatedDragBothDirections() {
        launch("en"); tap("settings"); tap("settings-songLibrary")
        for iteration in 0..<6 {
            app.images["library-drag-Gossip"].press(forDuration: 0.8, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
            settleDrop()
            let first = app.otherElements["library-row-Gossip"].frame.minY
            let second = app.otherElements["library-row-男孩别哭"].frame.minY
            if iteration.isMultiple(of: 2) { XCTAssertGreaterThan(first, second) }
            else { XCTAssertLessThan(first, second) }
        }
    }
    func testBuild23LibraryStandaloneAndEditorDoNotExpandRows() {
        launch(); tap("settings"); tap("settings-songLibrary")
        let first = app.otherElements["library-row-Gossip"]
        let second = app.otherElements["library-row-男孩别哭"]
        XCTAssertTrue(first.exists); let oldY = second.frame.minY
        XCTAssertFalse(b("library-options-Gossip").exists)
        shot("23-01-library-A")
        tap("library-edit-Gossip"); shot("23-02-song-editor")
        tap("editor-add-to-setlist")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2))
        app.navigationBars.buttons.firstMatch.tap()
        tap("cancel-song")
        XCTAssertEqual(second.frame.minY, oldY, accuracy: 2)
        let search = app.textFields["song-search"]
        search.tap(); swipeKeyboardAway(); XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("library-open-Gossip")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "Gossip")
        XCTAssertFalse(app.staticTexts["performance-setlist"].exists)
        XCTAssertFalse(app.staticTexts["performance-position"].exists)
        XCTAssertFalse(b("performance-next").exists)
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("performance-play"); shot("23-03-standalone-live")
        tap("close-performance"); tap("library-open-男孩别哭")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("close-performance"); tap("library-open-夜来香")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("performance-play"); tap("exit-live-mode")
        XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
    }
    func testBuild23ListBrowseDraftCancelSaveAndContext() {
        launch(); tap("settings"); tap("settings-setlists")
        XCTAssertFalse(b("edit-setlist").exists); XCTAssertFalse(b("manage-song-library").exists)
        shot("23-04-all-setlists")
        tap("setlist-周六演出")
        XCTAssertFalse(b("start-setlist").exists); XCTAssertFalse(b("add-song").exists)
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "01")
        shot("23-05-browse")
        tap("edit-setlist"); shot("23-06-edit-list")
        tap("delete-song-Gossip"); XCTAssertFalse(b("edit-song-Gossip").exists)
        tap("cancel-setlist"); XCTAssertTrue(b("song-Gossip").exists)
        tap("edit-setlist")
        let name = app.textFields["setlist-name"]
        name.tap(); name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "2026 湾区巡演 — Friday night with our friends")
        swipeKeyboardAway()
        tap("delete-song-Gossip"); tap("save-setlist")
        XCTAssertFalse(b("song-Gossip").exists)
        XCTAssertEqual(app.staticTexts["song-position-男孩别哭"].label, "01")
        shot("23-07-long-name")
        tap("song-男孩别哭")
        XCTAssertTrue((b("close-performance").value as? String ?? "").contains("Friday night"))
        XCTAssertFalse((b("close-performance").value as? String ?? "").contains("2 首"))
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("performance-play"); tap("performance-next")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "夜来香")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        shot("23-08-setlist-live")
        tap("performance-previous"); tap("performance-play"); tap("close-performance")
        tap("choose-setlist"); XCTAssertFalse(b("edit-setlist").exists)
        tap("new-setlist"); shot("23-09-new-list")
        XCTAssertFalse(b("save-setlist").isEnabled)
        tap("cancel-setlist"); XCTAssertFalse(app.textFields["setlist-name"].exists)
        tap("new-setlist"); app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("New show"); swipeKeyboardAway()
        tap("add-song"); shot("28-add-song"); tap("import-song-Gossip")
        XCTAssertTrue(b("edit-song-Gossip").exists)
        tap("save-setlist"); XCTAssertTrue(b("song-Gossip").exists)
        tap("edit-setlist"); tap("delete-setlist")
        let delete = app.buttons["confirm-delete-setlist"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3)); delete.tap()
        XCTAssertTrue(b("setlist-周六演出").exists == false) // renamed earlier
        XCTAssertFalse(b("setlist-New show").exists)
        tap("close-panel"); tap("settings-songLibrary")
        XCTAssertTrue(b("library-open-Gossip").exists)
    }
    func testEditOrderMovesBackAndPersistsOnSave() {
        launch("en"); openList("Saturday"); tap("edit-setlist")
        let first = app.images["drag-song-Gossip"]
        let last = app.images["drag-song-夜来香"]
        first.press(forDuration: 0.4, thenDragTo: last, withVelocity: .slow, thenHoldForDuration: 0.6)
        settleDrop()
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "03")
        first.press(forDuration: 0.4, thenDragTo: last, withVelocity: .slow, thenHoldForDuration: 0.4)
        settleDrop()
        tap("save-setlist"); tap("choose-setlist"); tap("setlist-Saturday")
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "02")
        tap("song-Gossip"); shot("28-ready-b")
    }
    func testBuild23WholeRowReorderAndEmptyList() {
        launch("en"); tap("settings"); tap("settings-setlists"); tap("setlist-Saturday")
        XCTAssertFalse(app.images["drag-song-Gossip"].exists)
        XCTAssertFalse(app.textFields["setlist-search"].exists)
        shot("24-browse")
        tap("edit-setlist")
        app.images["drag-song-Gossip"].press(forDuration: 0.7, thenDragTo: app.images["drag-song-夜来香"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "03")
        tap("cancel-setlist")
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "01")
        tap("choose-setlist"); tap("new-setlist")
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Empty"); swipeKeyboardAway(); tap("save-setlist")
        XCTAssertTrue(app.staticTexts["0 songs"].exists); XCTAssertFalse(b("add-song").exists)
        shot("23-11-empty-list")
        tap("edit-setlist"); tap("add-song"); tap("new-song")
        app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Long song title — a whole verse to test wrapping"); swipeKeyboardAway()
        tap("save-song"); tap("save-setlist")
        XCTAssertTrue(b("song-Long song title — a whole verse to test wrapping").exists)
        shot("23-12-long-song")
        tap("song-Long song title — a whole verse to test wrapping")
        tap("full-song-title")
        XCTAssertTrue(app.staticTexts["Long song title — a whole verse to test wrapping"].exists)
        tap("close-performance-overlay")
        tap("close-performance")
        tap("choose-setlist")
        app.images["drag-setlist-Empty"].press(forDuration: 0.7, thenDragTo: app.images["drag-setlist-Saturday"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertLessThan(b("setlist-Empty").frame.minY, b("setlist-Saturday").frame.minY)
        tap("close-panel"); tap("settings-songLibrary")
        app.images["library-drag-Gossip"].press(forDuration: 0.7, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertGreaterThan(app.otherElements["library-row-Gossip"].frame.minY, app.otherElements["library-row-男孩别哭"].frame.minY)
        shot("23-13-library-reordered")
    }
    func testStartSetlistNotesAndExitToInstrument() {
        launch(); tap("settings"); tap("settings-setlists"); shot("01-root")
        tap("setlist-周六演出"); shot("02-song-list")
        tap("song-Gossip"); tap("performance-play")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "Gossip")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        XCTAssertEqual(app.staticTexts["performance-position"].label, "第 1 首")
        let cueHeight = app.otherElements["performance-beat"].frame.height
        XCTAssertEqual((b("close-performance").value as? String ?? ""), "周六演出")
        tap("performance-edit")
        let notes = app.textFields["song-notes"].firstMatch
        notes.tap(); notes.typeText("Intro: wait four bars. Last chorus: stop on one.")
        tap("save-song"); XCTAssertFalse(app.staticTexts["performance-notes"].exists)
        XCTAssertEqual(app.otherElements["performance-beat"].frame.height, cueHeight, accuracy: 1)
        XCTAssertEqual(b("view-song-notes").frame.midY, app.staticTexts["performance-tempo"].frame.midY, accuracy: 2)
        shot("03-live-with-notes")
        tap("view-song-notes"); shot("04-notes-expanded"); tap("close-performance-overlay")
        tap("performance-next"); XCTAssertFalse(b("view-song-notes").exists)
        tap("performance-previous"); XCTAssertTrue(b("view-song-notes").exists)
        tap("exit-live-mode")
        XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
        XCTAssertEqual(b("transport").label, "停止播放")
        tap("transport"); tap("presets"); tap("song-Gossip")
        XCTAssertTrue(b("view-song-notes").exists)
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("exit-live-mode"); XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
    }
    func testKeyboardEscapeAndUniformSongEditor() {
        launch("en"); tap("settings"); tap("settings-songLibrary")
        let search = app.textFields["song-search"]
        let restingY = search.frame.minY
        search.tap(); XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(search.frame.minY, restingY, accuracy: 2)
        shot("21-empty-search-keyboard"); swipeKeyboardAway()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        search.tap(); search.typeText("Gossip"); swipeKeyboardAway()
        XCTAssertTrue(app.otherElements["library-row-Gossip"].exists)
        search.tap(); search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6)); swipeKeyboardAway()
        tap("library-new-song")
        let name = app.textFields["song-name"]
        name.tap(); name.typeText("A new song with a longer title"); swipeKeyboardAway()
        XCTAssertEqual(name.value as? String, "A new song with a longer title")
        shot("22-uniform-song-editor")
        tap("song-tempo"); enterTempo("123"); XCTAssertTrue(b("song-tempo").label.contains("123"))
        tap("song-sound"); XCTAssertEqual(app.buttons.matching(identifier: "song-picker-back").count, 1)
        XCTAssertFalse(b("choose-setlist").exists); shot("23-single-sound-back")
        tap("song-picker-back"); XCTAssertEqual(name.value as? String, "A new song with a longer title")
        let notes = app.textFields["song-notes"]
        notes.tap(); notes.typeText("Four bars in. Watch the ending."); swipeKeyboardAway()
        XCTAssertEqual(notes.value as? String, "Four bars in. Watch the ending.")
        tap("save-song"); XCTAssertTrue(app.otherElements["library-row-A new song with a longer title"].exists)
        XCTAssertFalse(b("library-reorder").exists); shot("24-library-always-draggable")
    }
    func testDirectSongLibraryEntry() {
        launch(); tap("settings"); shot("05-settings-live-entries")
        tap("settings-songLibrary"); XCTAssertTrue(app.otherElements["library-row-Gossip"].exists)
        XCTAssertFalse(b("choose-setlist").exists); shot("06-song-library")
        XCTAssertTrue(b("library-edit-Gossip").exists)
        XCTAssertFalse(b("library-options-Gossip").exists); shot("07-library-actions")
        tap("library-edit-Gossip"); tap("cancel-song")
        XCTAssertTrue(app.otherElements["library-row-Gossip"].exists)
        tap("close-panel"); tap("settings-setlists")
        XCTAssertTrue(b("setlist-周六演出").exists)
    }
    func testLibraryMembershipLabelsAndIndependentReorder() {
        launch(); tap("settings"); tap("settings-setlists"); tap("new-setlist")
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Sunday"); swipeKeyboardAway()
        tap("add-song"); tap("import-song-Gossip"); tap("save-setlist")
        tap("close-panel"); tap("settings-songLibrary")
        XCTAssertTrue(app.staticTexts["membership-Gossip-周六演出"].exists)
        XCTAssertTrue(app.staticTexts["membership-Gossip-Sunday"].exists)
        shot("08-library-memberships")
        app.images["library-drag-Gossip"].press(forDuration: 0.8, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertGreaterThan(app.otherElements["library-row-Gossip"].frame.minY, app.otherElements["library-row-男孩别哭"].frame.minY)
        shot("09-library-reorder")
        tap("close-panel"); tap("settings-setlists"); tap("setlist-周六演出")
        XCTAssertLessThan(b("song-Gossip").frame.minY, b("song-男孩别哭").frame.minY)
        tap("close-panel"); tap("settings-songLibrary")
        XCTAssertGreaterThan(app.otherElements["library-row-Gossip"].frame.minY, app.otherElements["library-row-男孩别哭"].frame.minY)
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
        tap("song-tempo"); enterTempo("87"); tap("save-song")
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
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Sunday"); swipeKeyboardAway()
        tap("add-song"); shot("05-add-song-sources")
        tap("new-song"); app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Warm hands\n"); tap("save-song"); tap("save-setlist")
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
        launch("en"); tap("settings"); tap("settings-setlists"); tap("new-setlist")
        let field = app.textFields["setlist-name"]; field.tap(); field.typeText("Sunday"); swipeKeyboardAway()
        tap("add-song"); tap("import-song-Gossip")
        tap("edit-song-Gossip"); tap("song-tempo")
        enterTempo("141"); tap("save-song")
        tap("save-setlist"); tap("choose-setlist"); tap("setlist-Saturday")
        XCTAssertTrue(b("song-Gossip").label.contains("141"))
        tap("choose-setlist"); tap("setlist-Sunday"); tap("edit-setlist")
        tap("delete-song-Gossip"); tap("save-setlist"); XCTAssertFalse(b("song-Gossip").exists)
        tap("edit-setlist"); tap("add-song")
        XCTAssertTrue(b("import-song-Gossip").exists)
        tap("import-song-Gossip"); tap("save-setlist")
        XCTAssertTrue(b("song-Gossip").label.contains("141")); shot("05-song-reused")
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
        launch("en"); tap("settings"); tap("settings-songLibrary"); tap("library-new-song")
        app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Encore"); swipeKeyboardAway()
        tap("save-song"); XCTAssertTrue(app.otherElements["library-row-Encore"].exists)
        let search = app.textFields["song-search"]; search.tap(); search.typeText("Encore"); swipeKeyboardAway()
        XCTAssertFalse(app.otherElements["library-row-Gossip"].exists)
        tap("library-edit-Encore"); tap("song-tempo")
        enterTempo("127")
        tap("editor-add-to-setlist"); tap("share-to-Saturday")
        XCTAssertTrue(b("song-tempo").label.contains("127")); tap("save-song")
        tap("library-edit-Encore"); tap("editor-delete-song"); shot("15-library-delete-confirmation")
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        if dismissRegion.exists { dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap() }
        else { tap("Cancel") }
        XCTAssertTrue(b("editor-delete-song").exists)
        tap("editor-delete-song"); tap("confirm-delete-library-song")
        XCTAssertFalse(app.otherElements["library-row-Encore"].exists)
        tap("close-panel"); tap("settings-setlists"); tap("setlist-Saturday")
        XCTAssertFalse(b("song-Encore").exists)
    }
    func testSetlistRenameReorderAndDeleteKeepsLibrary() {
        launch("en"); openList("Saturday"); tap("edit-setlist")
        let name = app.textFields["setlist-name"]; name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "Friday"); swipeKeyboardAway()
        tap("save-setlist"); XCTAssertEqual(app.staticTexts["setlist-title"].label, "Friday")
        tap("edit-setlist"); tap("delete-setlist"); tap("Cancel")
        XCTAssertTrue(b("edit-song-Gossip").exists)
        tap("delete-setlist"); tap("confirm-delete-setlist")
        XCTAssertFalse(b("setlist-Friday").exists)
        tap("close-panel"); tap("settings-songLibrary"); XCTAssertTrue(b("library-open-Gossip").exists)
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
        tap("edit-setlist"); tap("add-song"); shot("21-add-sources-zh-final"); tap("choose-setlist"); tap("cancel-setlist"); tap("close-panel")
        tap("practice"); tap("practice-polyrhythm"); tap("polyrhythm-3-2"); tap("polyrhythm-4-3")
        tap("practice-transport"); XCTAssertTrue(b("polyrhythm-4-3").isSelected); shot("22-poly-selection-final")
        tap("close-panel"); tap("close-panel"); tap("close-settings"); tap("home-division"); tap("division-patterns")
        XCTAssertTrue(b("division-patterns").isSelected); shot("23-pattern-selection-final"); tap("settings-transport")
    }
    func testDarkPerformanceEditCancelSaveAndReopenKeepsPlaying() {
        launch("en", dark: true); openList("Saturday"); tap("song-Gossip"); tap("performance-play")
        tap("performance-edit"); tap("song-division"); tap("division-count-3"); tap("song-picker-back")
        tap("cancel-song")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        tap("performance-edit"); tap("song-division"); tap("division-count-2"); tap("song-picker-back"); tap("save-song")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        tap("performance-edit"); tap("song-division")
        XCTAssertTrue(b("division-count-2").isSelected)
        tap("division-count-3"); tap("song-picker-back"); tap("save-song")
        shot("08-live-dark"); tap("performance-play"); tap("close-performance")
    }
}
