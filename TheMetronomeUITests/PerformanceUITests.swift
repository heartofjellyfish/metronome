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
    private func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    private func openList(_ name: String) { tap("settings"); tap("settings-setlists"); tap("setlist-\(name)") }
    func testPerformanceVisualOnlyRepeatedSongsTempoAndReturning() {
        launch(); openList("周六演出"); tap("song-男孩别哭"); shot("01-setlist-zh")
        tap("open-performance"); XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        tap("performance-play"); tap("performance-sound")
        XCTAssertEqual(b("performance-sound").value as? String, "仅视觉拍点")
        let cue = app.otherElements["performance-beat"]
        XCTAssertTrue(cue.waitForExistence(timeout: 3))
        let beat = cue.value as? String ?? ""
        let changes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", beat), object: cue)
        XCTAssertEqual(XCTWaiter.wait(for: [changes], timeout: 3), .completed)
        tap("performance-plus"); tap("performance-plus"); XCTAssertTrue(b("performance-tempo").label.contains("87"))
        shot("02-performance-visual-zh")
        tap("performance-next"); XCTAssertEqual(app.staticTexts["performance-song"].label, "夜来香"); XCTAssertFalse(b("performance-next").isEnabled)
        tap("performance-previous"); XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        tap("performance-previous"); XCTAssertEqual(app.staticTexts["performance-song"].label, "Gossip"); XCTAssertFalse(b("performance-previous").isEnabled)
        tap("performance-choose-song"); tap("performance-select-男孩别哭")
        XCTAssertEqual(app.staticTexts["performance-song"].label, "男孩别哭")
        tap("performance-edit"); shot("03-performance-song-editor")
        tap("cancel-song"); XCTAssertEqual(b("performance-play").label, "停止播放")
        tap("close-performance"); XCTAssertTrue(b("song-男孩别哭").isSelected)
        XCTAssertEqual(b("setlist-play").label, "停止播放")
        tap("close-panel"); tap("close-settings"); XCTAssertTrue(b("home-muted").exists)
        tap("home-muted"); XCTAssertFalse(b("home-muted").exists); tap("transport")
    }
    func testSharedSongAddEditRemoveAndReuse() {
        launch("en"); openList("Saturday"); tap("choose-setlist")
        let field = app.textFields["setlist-name"]; field.tap(); field.typeText("Sunday"); tap("Create setlist")
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
        XCTAssertFalse(b("practice-save-preset").exists); XCTAssertFalse(b("practice-transport").exists)
        XCTAssertFalse(b("TOUCH FEEDBACK-on").exists)
        tap("practice-gap"); tap("SOUND / SILENCE-on"); tap("practice-transport")
        XCTAssertEqual(b("practice-transport").label, "停止播放"); shot("07-practice-playing-zh")
        tap("close-panel"); XCTAssertTrue(b("practice-gap").exists)
        tap("practice-ramp"); XCTAssertEqual(b("practice-transport").label, "停止播放")
        tap("practice-transport"); tap("close-panel"); tap("close-panel")
        tap("general-haptics-off"); tap("general-haptics-on"); shot("08-general-haptics")
    }
    func testDarkPerformancePickerKeepsPlayingAcrossRepeatedChanges() {
        launch("en", dark: true); openList("Saturday"); tap("song-Gossip"); tap("open-performance"); tap("performance-play")
        tap("performance-division"); tap("division-count-2"); tap("division-count-3")
        XCTAssertTrue(b("division-count-3").isSelected); tap("close-panel")
        XCTAssertEqual(b("performance-play").label, "Stop metronome")
        tap("performance-division"); XCTAssertTrue(b("division-count-3").isSelected); tap("close-panel")
        shot("09-performance-dark"); tap("performance-play"); tap("close-performance")
    }
}
