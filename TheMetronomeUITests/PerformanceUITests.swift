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
    private var liveSongTitle: XCUIElement { app.descendants(matching: .any)["performance-song"].firstMatch }
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
    private func returnToInstrument() {
        tap("close-performance")
        tap("close-panel")
        if b("close-settings").isHittable { tap("close-settings") }
    }
    private func openList(_ name: String) { tap("settings"); tap("settings-setlists"); tap("setlist-\(name)") }
    func testSongNameTypingWhileLive() throws { try measureSongName(playing: true) }
    func testSongNameTypingWhileStopped() throws { try measureSongName(playing: false) }
    private func measureSongName(playing: Bool) throws {
        guard #available(iOS 26, *) else { throw XCTSkip("Hitch measurements require iOS 26.") }
        launch("en"); openList("Saturday"); tap("song-Gossip"); if playing { tap("performance-play") }; liveSongTitle.doubleTap()
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
        if b("library-start-editing").exists { tap("library-start-editing") }
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
    func testDarkHeaderGestures() {
        launch("en"); openList("Saturday"); tap("song-Gossip")
        let title = liveSongTitle
        title.tap()
        XCTAssertFalse(app.textFields["song-name"].exists)
        XCTAssertFalse(b("exit-live-mode").exists)
        XCTAssertFalse(b("performance-edit").exists)
        shot("31-live-header")
        tap("performance-play"); title.doubleTap()
        XCTAssertTrue(app.textFields["song-name"].exists)
        tap("cancel-song"); XCTAssertEqual(b("performance-play").label, "Stop metronome")
        tap("close-performance"); XCTAssertTrue(b("song-Gossip").exists)
    }
    func testSongMeterAndCategorizedSounds() {
        launch("en"); openList("Saturday"); tap("song-Gossip"); liveSongTitle.doubleTap()
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
        liveSongTitle.doubleTap(); tap("song-meter"); tap("meter-3-4"); tap("song-picker-back"); tap("save-song")
        XCTAssertEqual(app.staticTexts["performance-meter"].label, "3/4")
    }
    private func launchLongCatalog() {
        app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--redesign-ui-test", "--long-list-test", "-AppleLanguages", "(en)"]
        app.launch()
    }
    func testSaveNamedSetlistWithFiveSelections() {
        launchLongCatalog()
        tap("settings"); tap("settings-setlists"); tap("new-setlist")
        XCTAssertFalse(b("save-setlist").isEnabled)
        let name = app.textFields["setlist-name"]
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["setlist-empty-message"].exists)
        XCTAssertFalse(app.collectionViews.firstMatch.exists)
        shot("61-name-entry")
        name.typeText("November show\n")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        shot("61-named-draft")
        XCTAssertTrue(b("save-setlist").isEnabled)
        tap("add-song")
        for index in 1...5 { tap(String(format: "import-song-Track %02d", index)) }
        XCTAssertEqual(b("save-setlist").frame.height, b("cancel-picking-songs").frame.height, accuracy: 1)
        XCTAssertEqual(b("cancel-picking-songs").frame.width, 44, accuracy: 1)
        XCTAssertEqual(b("new-song").frame.maxX, b("save-setlist").frame.maxX, accuracy: 1)
        shot("55-save-five")
        tap("save-setlist")
        XCTAssertEqual(app.staticTexts["setlist-title"].label, "November show")
        XCTAssertEqual(app.staticTexts["setlist-count"].label, "5 songs")
    }
    func testAddSongSearchFollowsLibrarySize() {
        launch("zh-Hans")
        tap("settings"); tap("settings-setlists"); tap("new-setlist")
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Friday"); swipeKeyboardAway()
        tap("add-song")
        XCTAssertTrue(b("import-song-Gossip").isHittable)
        XCTAssertFalse(app.textFields["song-search"].exists)
        tap("import-song-夜来香"); tap("import-song-Gossip"); tap("import-song-男孩别哭"); tap("import-song-男孩别哭")
        XCTAssertTrue(b("import-song-Gossip").isSelected)
        XCTAssertFalse(b("import-song-男孩别哭").isSelected)
        shot("40-picker-short")
        tap("save-setlist")
        XCTAssertEqual(app.staticTexts["song-position-夜来香"].label, "01")
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "02")
        tap("edit-setlist"); tap("add-song")
        XCTAssertFalse(b("import-song-Gossip").isEnabled)
        tap("import-song-男孩别哭"); tap("cancel-picking-songs"); tap("save-setlist")
        XCTAssertFalse(b("song-男孩别哭").exists)

        launchLongCatalog()
        tap("settings"); tap("settings-setlists"); tap("new-setlist")
        app.textFields["setlist-name"].typeText("\n"); tap("add-song")
        let field = app.textFields["song-search"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let pickerWindow = app.collectionViews.firstMatch.frame
        let searchY = field.frame.midY
        let newSongY = b("new-song").frame.midY
        let saveY = b("save-setlist").frame.midY
        tap("import-song-Track 01")
        revealCatalogRow("import-song-Track 42")
        let scrolledWindow = app.collectionViews.firstMatch.frame
        XCTAssertEqual(scrolledWindow.minY, pickerWindow.minY, accuracy: 0.33)
        XCTAssertEqual(scrolledWindow.maxY, pickerWindow.maxY, accuracy: 0.33)
        XCTAssertEqual(field.frame.midY, searchY, accuracy: 1)
        XCTAssertEqual(b("new-song").frame.midY, newSongY, accuracy: 1)
        XCTAssertEqual(b("save-setlist").frame.midY, saveY, accuracy: 1)
        XCTAssertGreaterThan(newSongY, b("import-song-Track 42").frame.midY)
        shot("40-picker-scrolled")
        tap("new-song"); tap("cancel-song")
        field.tap(); field.typeText("Track 42"); swipeKeyboardAway()
        tap("import-song-Track 42")
        tap("Clear search"); tap("save-setlist")
        XCTAssertTrue(b("edit-song-Track 42").exists)
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Tour"); swipeKeyboardAway()
        tap("save-setlist")
        XCTAssertEqual(app.staticTexts["song-position-Track 01"].label, "01")
        XCTAssertEqual(app.staticTexts["song-position-Track 42"].label, "02")
    }
    func testLongListsPreserveContext() {
        launchLongCatalog()
        tap("settings"); tap("settings-setlists")
        let newSetlist = b("new-setlist").frame
        XCTAssertGreaterThan(newSetlist.minY, app.collectionViews.firstMatch.frame.maxY)
        revealCatalogRow("setlist-Set 30")
        XCTAssertEqual(b("new-setlist").frame, newSetlist)
        shot("57-setlists-scrolled")
        tap("setlist-Set 30")
        let toolbarY = b("edit-setlist").frame.midY
        revealCatalogRow("song-Track 42")
        XCTAssertEqual(b("edit-setlist").frame.midY, toolbarY, accuracy: 1)
        XCTAssertEqual(app.staticTexts["setlist-count"].label, "42 songs")
        XCTAssertEqual(app.staticTexts["compact-setlist-title"].label, "Set 30")
        shot("33-long-browse")
        tap("song-Track 42"); tap("performance-play"); tap("close-performance")
        XCTAssertTrue(b("song-Track 42").isHittable)
        for finish in ["cancel-setlist", "save-setlist"] {
            tap("edit-setlist")
            XCTAssertTrue(b("add-song").isHittable)
            XCTAssertTrue(b("edit-song-Track 42").isHittable)
            XCTAssertTrue(b("delete-setlist").isHittable)
            XCTAssertEqual(b("delete-setlist").frame.midY, toolbarY, accuracy: 1)
            XCTAssertEqual(b("add-song").frame.midY, toolbarY, accuracy: 1)
            shot("42-sticky-long-edit")
            tap(finish)
            XCTAssertTrue(b("song-Track 42").isHittable)
        }
        tap("choose-setlist")
        XCTAssertTrue(b("setlist-Set 30").isHittable)
        tap("close-panel"); tap("settings-songLibrary")
        let newSongFrame = b("library-new-song").frame
        let libraryWindow = app.collectionViews.firstMatch.frame
        XCTAssertGreaterThan(newSongFrame.minY, libraryWindow.maxY)
        revealCatalogRow("library-open-Track 42")
        XCTAssertEqual(app.collectionViews.firstMatch.frame, libraryWindow)
        XCTAssertEqual(b("library-new-song").frame, newSongFrame)
        XCTAssertTrue(app.textFields["song-search"].isHittable)
        XCTAssertTrue(b("library-new-song").isHittable)
        shot("33-long-library")
        tap("library-start-editing"); tap("library-edit-Track 42"); tap("cancel-song")
        XCTAssertTrue(b("library-open-Track 42").isHittable)
    }
    func testScrollingIntoEditModeKeepsEverySongDraggable() {
        app = XCUIApplication()
        app.launchArguments = ["--reference", "--light", "--redesign-ui-test", "--nine-song-setlist-test", "-AppleLanguages", "(en)"]
        app.launch()
        openList("载歌在谷歌手赛 2026")
        tap("edit-setlist")
        app.collectionViews.firstMatch.swipeUp()
        shot("65-edit-rows-08-09")
        for name in ["Track 08", "Track 09"] {
            XCTAssertTrue(app.images["drag-song-" + name].isHittable)
            XCTAssertTrue(b("delete-song-" + name).isHittable)
            XCTAssertFalse(b("song-" + name).isHittable)
        }
        let eighth = app.images["drag-song-Track 08"]
        let ninth = app.images["drag-song-Track 09"]
        ninth.press(forDuration: 0, thenDragTo: eighth, withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        tap("save-setlist")
        XCTAssertEqual(app.staticTexts["song-position-Track 09"].label, "08")
        XCTAssertEqual(app.staticTexts["song-position-Track 08"].label, "09")
        XCTAssertTrue(b("song-Track 09").isHittable)
        XCTAssertFalse(ninth.isHittable)
    }
    func testDragToEdgeAdvancesThroughLongSetlist() {
        launchLongCatalog()
        tap("settings"); tap("settings-setlists")
        let search = app.textFields["setlist-search"]
        search.tap(); search.typeText("Set 30")
        tap("setlist-Set 30"); tap("edit-setlist")
        let list = app.collectionViews.firstMatch
        let grip = app.images["drag-song-Track 01"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        let edge = list.coordinate(withNormalizedOffset: .init(dx: 0.28, dy: 0.985))
        grip.press(forDuration: 0, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 2)
        settleDrop()
        let number = app.staticTexts["song-position-Track 01"]
        XCTAssertTrue(number.exists)
        XCTAssertGreaterThan(Int(number.label) ?? 0, 9)
        tap("cancel-setlist")
        // In-place editing keeps the list scrolled to the drop, even when the move is cancelled.
        for _ in 0..<12 {
            if number.exists && number.isHittable { break }
            list.swipeDown()
        }
        XCTAssertEqual(number.label, "01")
    }
    private func revealCatalogRow(_ id: String) {
        let row = app.buttons[id].firstMatch
        for _ in 0..<22 {
            if row.exists && row.isHittable { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(row.isHittable, "Could not scroll to \(id)")
    }
    func testShortSetlistBrowserFitsRows() {
        launch("en"); tap("settings"); tap("settings-setlists")
        let list = app.collectionViews.firstMatch
        let button = b("new-setlist")
        XCTAssertEqual(button.frame.minY - list.frame.maxY, 12, accuracy: 1)
        XCTAssertLessThan(button.frame.maxY, app.frame.midY)
        XCTAssertFalse(app.textFields["setlist-search"].exists)
        shot("58-short-setlists")
        tap("new-setlist"); tap("cancel-setlist")
        XCTAssertEqual(button.frame.minY - list.frame.maxY, 12, accuracy: 1)
    }
    func testOverflowSearchAndFrequentSetlists() {
        launch("en", manyLists: true)
        tap("settings"); tap("settings-setlists")
        let search = app.textFields["setlist-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        let footer = b("new-setlist").frame
        search.tap()
        XCTAssertTrue(app.staticTexts["Frequently used"].waitForExistence(timeout: 3))
        for term in ["Tour 14", "Tour 21", "Tour 24"] {
            search.typeText(term)
            XCTAssertEqual(b("new-setlist").frame.midY, footer.midY, accuracy: 1)
            XCTAssertEqual(search.value as? String, term)
            XCTAssertTrue(app.buttons["setlist-\(term)"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["setlist-Saturday"].waitForNonExistence(timeout: 2))
            if term != "Tour 24" { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: term.count)) }
        }
        tap("setlist-Tour 24"); tap("song-Gossip")
        XCTAssertEqual(app.staticTexts["performance-setlist"].label, "Tour 24")
        shot("25-live")
        liveSongTitle.doubleTap(); shot("25-editor")
    }
    func testLibraryCancelOnlyDiscardsOrder() {
        launch("en"); tap("settings"); tap("settings-songLibrary")
        let newSong = b("library-new-song").frame
        tap("library-start-editing")
        XCTAssertEqual(b("library-new-song").frame, newSong)
        app.images["library-drag-Gossip"].press(forDuration: 0, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        tap("library-edit-Gossip"); tap("song-tempo"); enterTempo("127"); tap("save-song")
        tap("library-new-song")
        app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Encore\n")
        tap("save-song"); tap("cancel-library")
        XCTAssertLessThan(b("library-open-Gossip").frame.minY, b("library-open-男孩别哭").frame.minY)
        XCTAssertTrue(b("library-open-Encore").exists)
        tap("library-start-editing"); tap("library-edit-Gossip")
        XCTAssertTrue(b("song-tempo").label.contains("127"))
    }
    func testLibraryRepeatedDragBothDirections() {
        launch("en"); tap("settings"); tap("settings-songLibrary")
        tap("library-start-editing")
        for iteration in 0..<6 {
            app.images["library-drag-Gossip"].press(forDuration: 0, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
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
        tap("library-start-editing"); tap("library-edit-Gossip"); shot("23-02-song-editor")
        tap("editor-add-to-setlist")
        tap("membership-done")
        tap("cancel-song")
        tap("cancel-library")
        XCTAssertEqual(second.frame.minY, oldY, accuracy: 2)
        let search = app.textFields["song-search"]
        search.tap(); swipeKeyboardAway(); XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("library-open-Gossip")
        XCTAssertEqual(liveSongTitle.label, "Gossip")
        XCTAssertFalse(app.staticTexts["performance-setlist"].exists)
        XCTAssertFalse(app.staticTexts["performance-position"].exists)
        XCTAssertFalse(b("performance-next").exists)
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("performance-play"); shot("23-03-standalone-live")
        tap("close-performance"); tap("library-open-男孩别哭")
        XCTAssertEqual(liveSongTitle.label, "男孩别哭")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("close-performance"); tap("library-open-夜来香")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("performance-play"); returnToInstrument()
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
        tap("rename-setlist")
        let name = app.textFields["setlist-name"]
        name.typeText("2026 湾区巡演 — Friday night with our friends")
        swipeKeyboardAway()
        tap("delete-song-Gossip"); tap("save-setlist")
        XCTAssertFalse(b("song-Gossip").exists)
        XCTAssertEqual(app.staticTexts["song-position-男孩别哭"].label, "01")
        shot("23-07-long-name")
        tap("song-男孩别哭")
        XCTAssertTrue(app.staticTexts["performance-setlist"].label.contains("Friday night"))
        XCTAssertFalse(app.staticTexts["performance-setlist"].label.contains("2 首"))
        XCTAssertEqual(b("performance-play").label, "开始播放")
        tap("performance-play"); tap("performance-next")
        XCTAssertEqual(liveSongTitle.label, "夜来香")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        shot("23-08-setlist-live")
        tap("performance-previous"); tap("performance-play"); tap("close-performance")
        tap("choose-setlist"); XCTAssertFalse(b("edit-setlist").exists)
        tap("new-setlist"); shot("23-09-new-list")
        XCTAssertFalse(b("save-setlist").isEnabled)
        XCTAssertFalse(b("delete-setlist").exists)
        tap("cancel-setlist"); XCTAssertFalse(app.textFields["setlist-name"].exists)
        tap("new-setlist"); app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("New show"); swipeKeyboardAway()
        tap("add-song"); shot("28-add-song"); tap("import-song-Gossip")
        XCTAssertTrue(b("import-song-Gossip").isSelected)
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
        first.tap()
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "01")
        first.press(forDuration: 0, thenDragTo: last, withVelocity: .slow, thenHoldForDuration: 0.6)
        settleDrop()
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "03")
        first.press(forDuration: 0, thenDragTo: last, withVelocity: .slow, thenHoldForDuration: 0.4)
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
        app.images["drag-song-Gossip"].press(forDuration: 0, thenDragTo: app.images["drag-song-夜来香"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "03")
        tap("cancel-setlist")
        XCTAssertEqual(app.staticTexts["song-position-Gossip"].label, "01")
        tap("choose-setlist"); tap("new-setlist")
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Empty"); swipeKeyboardAway(); tap("save-setlist")
        XCTAssertEqual(app.staticTexts["setlist-empty-message"].label, "0 songs")
        XCTAssertGreaterThan(b("add-song").frame.minY, app.collectionViews.firstMatch.frame.maxY)
        shot("23-11-empty-list")
        tap("add-song"); tap("cancel-picking-songs")
        XCTAssertTrue(b("edit-setlist").exists)
        tap("edit-setlist"); tap("cancel-setlist")
        tap("add-song"); tap("new-song")
        app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Long song title — a whole verse to test wrapping"); swipeKeyboardAway()
        tap("save-song"); tap("save-setlist")
        XCTAssertTrue(b("song-Long song title — a whole verse to test wrapping").exists)
        shot("23-12-long-song")
        tap("song-Long song title — a whole verse to test wrapping")
        XCTAssertEqual(liveSongTitle.label, "Long song title — a whole verse to test wrapping")
        tap("close-performance")
        tap("choose-setlist")
        app.images["drag-setlist-Empty"].press(forDuration: 0, thenDragTo: app.images["drag-setlist-Saturday"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertLessThan(b("setlist-Empty").frame.minY, b("setlist-Saturday").frame.minY)
        tap("close-panel"); tap("settings-songLibrary"); tap("library-start-editing")
        app.images["library-drag-Gossip"].press(forDuration: 0, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertGreaterThan(app.otherElements["library-row-Gossip"].frame.minY, app.otherElements["library-row-男孩别哭"].frame.minY)
        shot("23-13-library-reordered")
    }
    func testStartSetlistNotesAndExitToInstrument() {
        launch(); tap("settings"); tap("settings-setlists"); shot("01-root")
        tap("setlist-周六演出"); shot("02-song-list")
        tap("song-Gossip"); tap("performance-play")
        XCTAssertEqual(liveSongTitle.label, "Gossip")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        XCTAssertEqual(app.staticTexts["performance-position"].label, "第 1 首")
        let cueHeight = app.otherElements["performance-beat"].frame.height
        XCTAssertEqual(app.staticTexts["performance-setlist"].label, "周六演出")
        liveSongTitle.doubleTap()
        let notes = app.textFields["song-notes"].firstMatch
        notes.tap(); notes.typeText("Intro: wait four bars. Last chorus: stop on one.")
        swipeKeyboardAway()
        tap("save-song"); XCTAssertFalse(app.staticTexts["performance-notes"].exists)
        XCTAssertEqual(app.otherElements["performance-beat"].frame.height, cueHeight, accuracy: 1)
        XCTAssertTrue(b("view-song-notes").isHittable)
        shot("03-live-with-notes")
        tap("view-song-notes"); shot("04-notes-expanded"); tap("close-performance-overlay")
        tap("performance-next"); XCTAssertFalse(b("view-song-notes").exists)
        tap("performance-previous"); XCTAssertTrue(b("view-song-notes").exists)
        returnToInstrument()
        XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
        XCTAssertEqual(b("transport").label, "停止播放")
        tap("transport"); tap("presets"); tap("song-Gossip")
        XCTAssertTrue(b("view-song-notes").exists)
        XCTAssertEqual(b("performance-play").label, "开始播放")
        returnToInstrument(); XCTAssertTrue(b("settings").waitForExistence(timeout: 3))
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
        XCTAssertFalse(b("library-edit-Gossip").exists)
        XCTAssertFalse(app.images["library-drag-Gossip"].exists)
        tap("library-start-editing")
        XCTAssertTrue(b("library-edit-Gossip").exists)
        XCTAssertFalse(b("library-options-Gossip").exists); shot("07-library-actions")
        tap("library-edit-Gossip"); tap("cancel-song")
        XCTAssertTrue(app.otherElements["library-row-Gossip"].exists)
        tap("cancel-library"); tap("close-panel"); tap("settings-setlists")
        XCTAssertTrue(b("setlist-周六演出").exists)
    }
    func testLibraryMembershipLabelsAndIndependentReorder() {
        launch(); tap("settings"); tap("settings-setlists"); tap("new-setlist")
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Sunday"); swipeKeyboardAway()
        tap("add-song"); tap("import-song-Gossip"); tap("save-setlist")
        tap("close-panel"); tap("settings-songLibrary")
        XCTAssertTrue(app.staticTexts["membership-Gossip-周六演出"].exists)
        XCTAssertEqual(app.staticTexts["membership-overflow-Gossip"].label, "Sunday")
        tap("library-setlists-Gossip")
        XCTAssertTrue(b("share-to-Sunday").isSelected)
        shot("50-song-setlists")
        tap("share-to-Sunday"); tap("membership-done")
        XCTAssertFalse(app.staticTexts["membership-overflow-Gossip"].exists)
        tap("library-setlists-Gossip"); XCTAssertFalse(b("share-to-Sunday").isSelected)
        tap("share-to-Sunday"); tap("membership-done")
        shot("08-library-memberships"); tap("library-start-editing")
        app.images["library-drag-Gossip"].press(forDuration: 0, thenDragTo: app.images["library-drag-男孩别哭"], withVelocity: .slow, thenHoldForDuration: 0.2)
        settleDrop()
        XCTAssertGreaterThan(app.otherElements["library-row-Gossip"].frame.minY, app.otherElements["library-row-男孩别哭"].frame.minY)
        shot("09-library-reorder"); tap("save-library")
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
        XCTAssertEqual(liveSongTitle.label, "男孩别哭")
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
        tap("performance-next"); XCTAssertEqual(liveSongTitle.label, "夜来香"); XCTAssertFalse(b("performance-next").isEnabled)
        tap("performance-previous"); XCTAssertEqual(liveSongTitle.label, "男孩别哭")
        tap("performance-previous"); XCTAssertEqual(liveSongTitle.label, "Gossip"); XCTAssertFalse(b("performance-previous").isEnabled)
        tap("performance-next")
        liveSongTitle.doubleTap(); shot("03-live-editor")
        tap("song-tempo"); enterTempo("87"); tap("save-song")
        XCTAssertEqual(app.staticTexts["performance-tempo"].label, "87 BPM")
        XCTAssertEqual(b("performance-play").label, "停止播放")
        liveSongTitle.doubleTap(); tap("cancel-song")
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
        XCTAssertEqual(liveSongTitle.label, "男孩别哭")
        XCTAssertEqual(b("performance-play").label, "开始播放")
        XCTAssertTrue(b("performance-next").label.contains("夜来香"))
        XCTAssertEqual(b("performance-previous").frame.midY, b("performance-next").frame.midY, accuracy: 2)
        XCTAssertEqual(b("performance-tap").frame.midY, b("performance-play").frame.midY, accuracy: 2)
        XCTAssertEqual(app.staticTexts["performance-tempo"].frame.midY, app.staticTexts["performance-meter"].frame.midY, accuracy: 2)
        XCTAssertFalse(b("performance-tempo").exists); XCTAssertFalse(b("performance-meter").exists)
        shot("04-live-stopped")
        tap("performance-next"); XCTAssertFalse(b("performance-next").isEnabled)
        tap("performance-previous"); tap("performance-previous")
        XCTAssertEqual(liveSongTitle.label, "Gossip")
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
        tap("song-Warm hands"); XCTAssertEqual(liveSongTitle.label, "Warm hands")
        tap("close-performance"); tap("close-panel"); tap("close-settings")
        XCTAssertTrue((b("presets").value as? String ?? "").contains("Sunday"))
        tap("presets"); XCTAssertTrue(b("song-Warm hands").exists)
        tap("close-panel"); tap("settings"); tap("settings-setlists")
        XCTAssertTrue(b("setlist-Saturday").exists); XCTAssertTrue(b("setlist-Sunday").exists)
    }
    func testSharedSongAddEditRemoveAndReuse() {
        launch("en"); tap("settings"); tap("settings-setlists"); tap("new-setlist")
        let field = app.textFields["setlist-name"]; field.tap(); field.typeText("Sunday"); swipeKeyboardAway()
        tap("add-song"); tap("import-song-Gossip"); tap("save-setlist"); tap("edit-setlist")
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
    func testDeleteSongNamesAllAffectedSetlists() {
        launch("zh-Hans")
        tap("settings"); tap("settings-setlists"); tap("new-setlist")
        let name = "2026 秋季巡演 · 西雅图不插电加演场"
        app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText(name); swipeKeyboardAway()
        tap("add-song"); tap("import-song-Gossip"); tap("save-setlist"); tap("close-panel")
        tap("settings-songLibrary"); tap("library-start-editing"); tap("library-edit-Gossip")
        tap("editor-delete-song")
        XCTAssertEqual(app.staticTexts["affected-setlist-周六演出"].label, "周六演出")
        XCTAssertEqual(app.staticTexts["affected-setlist-" + name].label, name)
        shot("38-two-affected-setlists")
        tap("取消"); tap("cancel-song")
        XCTAssertTrue(b("library-open-Gossip").exists)

        launch("en", manyLists: true)
        tap("settings"); tap("settings-songLibrary"); tap("library-start-editing"); tap("library-edit-Gossip")
        tap("editor-delete-song")
        let scroll = app.scrollViews["delete-impact-scroll"]
        XCTAssertTrue(scroll.isHittable)
        let confirm = b("confirm-delete-library-song")
        let y = confirm.frame.midY
        let last = app.staticTexts["affected-setlist-Tour 24"]
        for _ in 0..<8 {
            if last.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(last.isHittable)
        XCTAssertEqual(confirm.frame.midY, y, accuracy: 1)
        tap("Cancel")
    }
    func testLibraryCreateSearchEditDeleteAndAddNavigation() {
        launch("en"); tap("settings"); tap("settings-songLibrary"); tap("library-new-song")
        app.textFields["song-name"].tap(); app.textFields["song-name"].typeText("Encore"); swipeKeyboardAway()
        tap("save-song"); XCTAssertTrue(app.otherElements["library-row-Encore"].exists)
        let search = app.textFields["song-search"]; search.tap(); search.typeText("Encore"); swipeKeyboardAway()
        XCTAssertFalse(app.otherElements["library-row-Gossip"].exists)
        tap("library-start-editing"); tap("library-edit-Encore"); tap("song-tempo")
        enterTempo("127")
        tap("editor-add-to-setlist"); tap("share-to-Saturday"); tap("membership-done")
        XCTAssertTrue(b("song-tempo").label.contains("127")); tap("save-song")
        tap("library-edit-Encore")
        let save = b("save-song")
        let cancel = b("cancel-song")
        XCTAssertGreaterThan(save.frame.midX, cancel.frame.midX)
        XCTAssertEqual(save.frame.midY, cancel.frame.midY, accuracy: 1)
        XCTAssertLessThan(save.frame.maxY, app.textFields["song-name"].frame.minY)
        XCTAssertEqual(b("editor-add-to-setlist").label, "Manage setlists")
        XCTAssertTrue(b("editor-delete-song").isHittable)
        XCTAssertGreaterThan(b("editor-delete-song").frame.minY, b("editor-add-to-setlist").frame.maxY)
        shot("51-editor-single-screen")
        tap("editor-delete-song"); shot("15-library-delete-confirmation")
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        if dismissRegion.exists { dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap() }
        else { tap("Cancel") }
        XCTAssertTrue(b("editor-delete-song").exists)
        tap("editor-delete-song"); tap("confirm-delete-library-song")
        XCTAssertFalse(app.otherElements["library-row-Encore"].exists)
        tap("cancel-library"); tap("close-panel"); tap("settings-setlists"); tap("setlist-Saturday")
        XCTAssertFalse(b("song-Encore").exists)
    }
    func testImmediateReorderOnConnectedPhoneWithoutSaving() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Checks the physical drag handle.")
        #else
        app = XCUIApplication()
        app.launch()
        tap("settings"); tap("settings-setlists")
        let lists = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "setlist-"))
        for list in lists.allElementsBoundByIndex where list.isHittable {
            list.tap()
            tap("edit-setlist")
            let handles = app.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "drag-song-"))
                .allElementsBoundByIndex.filter { $0.isHittable }
            if handles.count >= 2 {
                let position = "song-position-" + handles[0].identifier.dropFirst("drag-song-".count)
                let number = app.staticTexts[position]
                let original = number.label
                handles[0].press(forDuration: 0, thenDragTo: handles[1], withVelocity: .default, thenHoldForDuration: 0)
                settleDrop()
                XCTAssertNotEqual(number.label, original)
                tap("cancel-setlist")
                XCTAssertEqual(number.label, original)
                tap("close-panel"); tap("close-settings")
                return
            }
            tap("cancel-setlist"); tap("choose-setlist")
        }
        throw XCTSkip("Needs two songs in a setlist.")
        #endif
    }
    func testRenameOnConnectedPhoneWithoutSaving() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Checks the actual pencil hit target on the phone.")
        #else
        app = XCUIApplication()
        app.launch()
        tap("settings"); tap("settings-setlists")
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "setlist-")).allElementsBoundByIndex.first { $0.isHittable }
        let row = try XCTUnwrap(first)
        row.tap()
        let original = app.staticTexts["setlist-title"].label
        tap("edit-setlist")
        b("rename-setlist").coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        let field = app.textFields["setlist-name"]
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
        field.typeText(" Soundcheck")
        XCTAssertEqual(field.value as? String, original + " Soundcheck")
        tap("finish-rename-setlist")
        XCTAssertEqual(b("rename-setlist").value as? String, original + " Soundcheck")
        tap("cancel-setlist")
        XCTAssertEqual(app.staticTexts["setlist-title"].label, original)
        tap("close-panel"); tap("close-settings")
        #endif
    }
    func testSetlistRenameReorderAndDeleteKeepsLibrary() {
        launch("en"); openList("Saturday")
        let browseButton = b("edit-setlist").frame
        tap("edit-setlist")
        XCTAssertEqual(b("add-song").frame, browseButton)
        let title = b("rename-setlist")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let name = app.textFields["setlist-name"]
        name.typeText(" Rehearsal")
        shot("45-rename-check")
        tap("finish-rename-setlist")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertEqual(b("rename-setlist").value as? String, "Saturday Rehearsal")
        tap("rename-setlist"); name.typeText("!\n")
        XCTAssertEqual(b("rename-setlist").value as? String, "Saturday Rehearsal!")
        tap("cancel-setlist")
        XCTAssertEqual(app.staticTexts["setlist-title"].label, "Saturday")
        tap("edit-setlist")
        b("rename-setlist").coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        XCTAssertFalse(b("finish-rename-setlist").isEnabled)
        XCTAssertFalse(b("save-setlist").isEnabled)
        name.typeText("Friday")
        XCTAssertEqual(name.value as? String, "Friday")
        tap("save-setlist"); XCTAssertEqual(app.staticTexts["setlist-title"].label, "Friday")
        tap("edit-setlist")
        XCTAssertTrue(b("add-song").isHittable)
        XCTAssertTrue(b("delete-setlist").isHittable)
        let deleteFrame = b("delete-setlist").frame
        let addFrame = b("add-song").frame
        XCTAssertEqual(deleteFrame.height, addFrame.height, accuracy: 1)
        XCTAssertEqual(deleteFrame.midY, addFrame.midY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(addFrame.minX - deleteFrame.maxX, 16)
        XCTAssertGreaterThan(addFrame.width, deleteFrame.width)
        shot("42-sticky-short-edit")
        tap("delete-setlist"); tap("Cancel")
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
        tap("edit-setlist"); tap("add-song"); shot("21-add-sources-zh-final"); tap("cancel-picking-songs"); tap("cancel-setlist"); tap("close-panel")
        tap("practice"); tap("practice-polyrhythm"); tap("polyrhythm-3-2"); tap("polyrhythm-4-3")
        tap("practice-transport"); XCTAssertTrue(b("polyrhythm-4-3").isSelected); shot("22-poly-selection-final")
        tap("close-panel"); tap("close-panel"); tap("close-settings"); tap("home-division"); tap("division-patterns")
        XCTAssertTrue(b("division-patterns").isSelected); shot("23-pattern-selection-final"); tap("settings-transport")
    }
    func testDarkPerformanceEditCancelSaveAndReopenKeepsPlaying() {
        launch("en", dark: true); openList("Saturday"); tap("song-Gossip"); tap("performance-play")
        liveSongTitle.doubleTap(); tap("song-division"); tap("division-count-3"); tap("song-picker-back")
        tap("cancel-song")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        liveSongTitle.doubleTap(); tap("song-division"); tap("division-count-2"); tap("song-picker-back"); tap("save-song")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        liveSongTitle.doubleTap(); tap("song-division")
        XCTAssertTrue(b("division-count-2").isSelected)
        tap("division-count-3"); tap("song-picker-back"); tap("save-song")
        shot("08-live-dark"); tap("performance-play"); tap("close-performance")
    }
}
