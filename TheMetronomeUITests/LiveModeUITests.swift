import XCTest

final class LiveModeUITests: XCTestCase {
    func testSettingsTilesAndBluetoothDisplay() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "--light", "--pedal-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["pedal-display-status"].exists)
        capture(app, "Home disconnected")
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["settings-pedal"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        capture(app, "Settings physical tiles")
        for identifier in ["practice", "settings-presets", "settings-setlists", "settings-pedal"] {
            app.buttons[identifier].tap()
            XCTAssertTrue(app.buttons["close-panel"].waitForExistence(timeout: 3))
            app.buttons["close-panel"].tap()
        }
        app.buttons["theme-dark"].tap()
        capture(app, "Settings physical tiles dark")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--pedal-ui-test", "--pedal-fixture-bluetooth"]
        app.launch()
        let status = app.buttons["pedal-display-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        capture(app, "Home Bluetooth fixture")
        status.tap()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 3))
        app.buttons["close-panel"].tap()
        app.buttons["transport"].tap()
        status.tap()
        app.buttons["close-panel"].tap()
        XCTAssertEqual(app.buttons["transport"].label, "Stop metronome")
        app.buttons["transport"].tap()
    }
    func testLearningAvailableWithoutConnectionAndBackgroundCancels() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--panel=pedal", "--pedal-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["pedal-tab-connect"].exists)
        for action in ["toggle", "tap", "next", "previous", "faster", "slower"] {
            XCTAssertTrue(app.buttons["pedal-\(action)"].isEnabled)
        }
        capture(app, "Direct assignment without device")
        app.buttons["pedal-toggle"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learning")
        capture(app, "Direct learning")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["pedal-toggle"].tap()
        app.buttons["pedal-tap"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        XCTAssertEqual(app.buttons["pedal-tap"].value as? String, "Learning")
        app.buttons["pedal-tap"].tap()
        XCTAssertEqual(app.buttons["pedal-tap"].value as? String, "Learn")
    }
    func testSixActionsLearningCancellationAndPlaybackRemainAccessible() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--pedal-ui-test", "--pedal-fixture-input"]
        app.launch()
        let transport = app.buttons["transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 8))
        transport.tap()
        app.buttons["settings"].tap()
        app.buttons["settings-pedal"].tap()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 5))
        for action in ["next", "previous", "faster", "slower", "toggle", "tap"] {
            XCTAssertTrue(app.buttons["pedal-\(action)"].waitForExistence(timeout: 2))
        }
        let row = app.buttons["pedal-tap"].frame
        for action in ["toggle", "next", "tap"] {
            let key = app.buttons["pedal-\(action)"]
            key.tap()
            XCTAssertEqual(key.value as? String, "Learning")
            XCTAssertEqual(app.buttons["pedal-tap"].frame.minY, row.minY, accuracy: 1)
            key.tap()
            XCTAssertEqual(key.value as? String, "Learn")
        }
        app.buttons["pedal-toggle"].tap()
        app.buttons["pedal-toggle"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["close-panel"].tap()
        app.buttons["settings-preparation"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Avoid call interruptions"].exists)
        app.swipeDown()
        app.buttons["settings-preparation"].tap()
        XCTAssertFalse(app.staticTexts["Avoid call interruptions"].exists)
        app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Stop metronome")
        transport.tap()
        app.buttons["settings"].tap(); app.buttons["settings-pedal"].tap()
        app.buttons["pedal-toggle"].tap()
        app.buttons["close-panel"].tap(); app.buttons["settings-pedal"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Learn")
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        XCTAssertEqual(transport.label, "Start metronome")
    }
    func testLocalizedStatesAndRebindCancellationPreserveAssignment() {
        for language in ["zh-Hans", "de", "en"] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "--light", "--panel=pedal", "--pedal-ui-test", "--pedal-fixture-bound", "--pedal-fixture-input"]
            app.launch()
            let key = app.buttons["pedal-toggle"]
            XCTAssertTrue(key.waitForExistence(timeout: 8))
            let assigned = key.value as? String
            capture(app, "Cassette bound — \(language)")
            key.tap()
            XCTAssertNotEqual(key.value as? String, assigned)
            capture(app, "Cassette learning — \(language)")
            key.tap(); XCTAssertEqual(key.value as? String, assigned)
            XCTAssertFalse(app.images["checkmark"].exists)
            app.buttons["pedal-help"].tap(); app.swipeUp(); XCTAssertTrue(app.buttons["pedal-midi"].exists)
            capture(app, "Assignments — \(language)")
            app.terminate()
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}

final class StageFeatureUITests: XCTestCase {
    func testSetlistCreateSongsSelectAndEdit() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--stage-ui-test", "--panel=setlists"]
        app.launch()
        XCTAssertTrue(app.buttons["new-setlist"].waitForExistence(timeout: 8)); app.buttons["new-setlist"].tap()
        let name = app.textFields["setlist-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 8)); name.tap(); name.typeText("Friday show")
        app.buttons["create-setlist"].tap()
        for (song, bpm) in [("Opening", "95"), ("Night drive", "140"), ("Encore", "85")] {
            reveal(app.buttons["add-song"], app); app.buttons["add-song"].tap()
            app.buttons["new-song"].tap()
            let title = app.textFields["song-name"]; reveal(title, app); title.tap(); title.typeText(song)
            reveal(app.buttons["song-tempo"], app); app.buttons["song-tempo"].tap()
            let tempo = app.textFields["BPM"]; tempo.tap(); tempo.typeText(bpm)
            app.buttons["song-picker-back"].tap()
            XCTAssertTrue(app.buttons["save-song"].isEnabled)
            reveal(app.buttons["save-song"], app); app.buttons["save-song"].tap()
        }
        app.swipeDown(); capture(app, "Setlist three songs")
        reveal(app.buttons["song-Opening"], app); app.buttons["song-Opening"].tap()
        app.buttons["performance-play"].tap()
        app.buttons["performance-next"].tap(); app.buttons["performance-next"].tap(); app.buttons["close-performance"].tap()
        XCTAssertTrue(app.buttons["song-Encore"].isSelected)
        app.buttons["edit-setlist"].tap()
        reveal(app.buttons["edit-song-Encore"], app); app.buttons["edit-song-Encore"].tap()
        let revisedName = app.textFields["song-name"]; reveal(revisedName, app); revisedName.tap()
        revisedName.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "Encore revised")
        reveal(app.buttons["song-tempo"], app); app.buttons["song-tempo"].tap()
        let revisedTempo = app.textFields["BPM"]; revisedTempo.tap()
        revisedTempo.typeText("86"); app.buttons["song-picker-back"].tap()
        reveal(app.buttons["save-song"], app); app.buttons["save-song"].tap()
        XCTAssertTrue(app.buttons["song-Encore revised"].isSelected)
        reveal(app.images["drag-song-Encore revised"], app); app.images["drag-song-Encore revised"].press(forDuration: 0.8, thenDragTo: app.images["drag-song-Night drive"])
        XCTAssertLessThan(app.buttons["song-Encore revised"].frame.minY, app.buttons["song-Night drive"].frame.minY)
        app.swipeDown(); app.swipeDown(); capture(app, "Setlist editing")
        app.buttons["edit-setlist"].tap(); app.buttons["close-panel"].tap()
        if app.buttons["close-settings"].exists { app.buttons["close-settings"].tap() }
        XCTAssertEqual(app.buttons["transport"].label, "Stop metronome"); app.buttons["transport"].tap()
        app.terminate(); app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--panel=setlists"]; app.launch()
        if app.buttons["setlist-Friday show"].exists { app.buttons["setlist-Friday show"].tap() }; XCTAssertTrue(app.buttons["song-Encore revised"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["song-Encore revised"].isSelected)
        capture(app, "Setlist saved and reopened")
        app.terminate(); app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "--light", "--panel=setlists"]; app.launch()
        if app.buttons["setlist-Friday show"].exists { app.buttons["setlist-Friday show"].tap() }; XCTAssertTrue(app.buttons["song-Encore revised"].waitForExistence(timeout: 8)); capture(app, "Setlist Chinese")
        app.terminate(); app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--panel=setlists"]; app.launch()
        if app.buttons["setlist-Friday show"].exists { app.buttons["setlist-Friday show"].tap() }; XCTAssertTrue(app.buttons["edit-setlist"].waitForExistence(timeout: 8)); app.buttons["edit-setlist"].tap()
        reveal(app.buttons["delete-song-Encore revised"], app); app.buttons["delete-song-Encore revised"].tap()
        reveal(app.buttons["Remove"], app); app.buttons["Remove"].tap()
        XCTAssertFalse(app.buttons["song-Encore revised"].exists)
        reveal(app.buttons["add-song"], app); app.buttons["add-song"].tap()
        app.buttons["new-song"].tap(); XCTAssertTrue(app.textFields["song-name"].exists)
    }
    func testAdvancedDivisionKeepsLiveSelectionAndReopens() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--stage-ui-test"]
        app.launch(); XCTAssertTrue(app.buttons["transport"].waitForExistence(timeout: 8)); app.buttons["transport"].tap()
        app.buttons["home-division"].tap(); app.buttons["division-patterns"].tap(); app.buttons["pattern-family-3"].tap()
        app.buttons["pattern-3-5"].tap(); XCTAssertTrue(app.buttons["pattern-3-5"].isSelected)
        app.buttons["pattern-3-6"].tap(); XCTAssertTrue(app.buttons["pattern-3-6"].isSelected)
        capture(app, "Rhythm patterns")
        app.buttons["close-panel"].tap(); XCTAssertEqual(app.buttons["transport"].label, "Stop metronome")
        app.buttons["home-division"].tap(); XCTAssertTrue(app.buttons["pattern-3-6"].isSelected)
        app.buttons["close-panel"].tap(); app.buttons["transport"].tap()
    }
    func testStageClickAuditionsAndKeepsSelection() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--stage-ui-test", "--panel=sounds"]
        app.launch()
        let stage = app.buttons["classic-sound-16"]
        reveal(stage, app); stage.tap(); XCTAssertTrue(stage.isSelected)
        app.buttons["classic-sound-1"].tap(); XCTAssertFalse(stage.isSelected)
        stage.tap(); XCTAssertTrue(stage.isSelected); capture(app, "Stage click sound")
        app.buttons["close-panel"].tap(); app.buttons["transport"].tap()
        app.buttons["settings"].tap(); app.buttons["all-sounds"].tap()
        reveal(stage, app); XCTAssertTrue(stage.isSelected)
        app.buttons["classic-sound-1"].tap(); stage.tap()
        app.buttons["close-panel"].tap(); app.buttons["close-settings"].tap()
        XCTAssertEqual(app.buttons["transport"].label, "Stop metronome"); app.buttons["transport"].tap()
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "--dark", "--stage-ui-test", "--panel=sounds"]
        app.launch(); reveal(stage, app); stage.tap()
        XCTAssertTrue(stage.isSelected); capture(app, "Stage click dark Chinese")
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}

final class OrganizationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testStandalonePracticeImportAndEditingDoNotChangePlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--organization-ui-test"]
        app.launch(); XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 8))
        app.buttons["settings"].tap(); app.buttons["practice"].tap()
        app.buttons["practice-ramp"].tap(); app.buttons["RAMP-on"].tap(); app.buttons["close-panel"].tap()
        app.buttons["practice-gap"].tap(); app.buttons["SOUND / SILENCE-on"].tap(); app.buttons["close-panel"].tap()
        reveal(app.buttons["practice-save-preset"], app); capture(app, "Practice save shortcut")
        app.buttons["practice-save-preset"].tap()
        XCTAssertFalse(app.buttons["choose-setlist"].exists)
        app.textFields["preset-name"].tap(); app.textFields["preset-name"].typeText("Warm hands")
        app.buttons["save-preset"].tap()
        XCTAssertTrue(app.buttons["load-preset-Warm hands"].waitForExistence(timeout: 3))
        capture(app, "Standalone practice saved")
        app.buttons["close-panel"].tap()
        XCTAssertTrue(app.buttons["practice-countIn"].exists)
        app.buttons["close-panel"].tap(); app.buttons["settings-setlists"].tap()
        app.buttons["new-setlist"].tap(); app.textFields["setlist-name"].tap(); app.textFields["setlist-name"].typeText("Friday show")
        app.buttons["create-setlist"].tap(); app.buttons["add-song"].tap()
        app.buttons["import-presets"].tap(); capture(app, "Import preset copy")
        app.buttons["cancel-import"].tap(); XCTAssertFalse(app.buttons["song-Warm hands"].exists)
        app.buttons["import-presets"].tap(); app.buttons["import-preset-Warm hands"].tap()
        XCTAssertTrue(app.buttons["song-Warm hands"].exists)
        capture(app, "Setlist with practice copy")
        app.buttons["song-Warm hands"].tap(); app.buttons["close-performance"].tap(); app.buttons["close-panel"].tap()
        app.buttons["close-settings"].tap()
        XCTAssertEqual(app.buttons["transport"].label, "Start metronome")
        app.buttons["transport"].tap(); app.buttons["settings"].tap(); app.buttons["settings-setlists"].tap(); app.buttons["setlist-Friday show"].tap()
        app.buttons["edit-setlist"].tap(); app.buttons["song-Warm hands"].tap()
        XCTAssertTrue(app.textFields["song-name"].exists)
        XCTAssertTrue(app.buttons["close-panel"].exists) // Editing a row must never select/dismiss.
        reveal(app.buttons["save-song"], app); app.buttons["save-song"].tap()
        app.buttons["close-panel"].tap()
        app.buttons["close-settings"].tap(); XCTAssertEqual(app.buttons["transport"].label, "Stop metronome")
        app.buttons["transport"].tap(); app.buttons["settings"].tap(); app.buttons["settings-presets"].tap()
        XCTAssertTrue(app.buttons["load-preset-Warm hands"].exists)
        app.buttons["load-preset-Warm hands"].tap(); app.buttons["close-settings"].tap()
        app.terminate(); app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--panel=presets"]; app.launch()
        XCTAssertTrue(app.buttons["load-preset-Warm hands"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["load-preset-Warm hands"].isSelected)
        capture(app, "Standalone preset restored")
    }
    func testSettingsLanguagesThemesAndNavigation() {
        for language in ["en", "zh-Hans", "de", "fr", "ja", "ko", "es", "pt-BR", "zh-Hant"] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "--settings", "--light", "--reference"]
            app.launch(); XCTAssertTrue(app.buttons["practice"].waitForExistence(timeout: 8))
            capture(app, "Organized settings \(language)")
            for id in ["settings-presets", "settings-setlists", "settings-pedal"] {
                reveal(app.buttons[id], app); app.buttons[id].tap()
                XCTAssertTrue(app.buttons["close-panel"].waitForExistence(timeout: 3)); app.buttons["close-panel"].tap()
            }
            if ["en", "zh-Hans", "de"].contains(language) {
                reveal(app.buttons["settings-preparation"], app); app.buttons["settings-preparation"].tap()
                app.swipeUp(); capture(app, "Performance preparation \(language)")
                app.swipeDown(); reveal(app.buttons["settings-preparation"], app); app.buttons["settings-preparation"].tap()
                XCTAssertFalse(app.otherElements["performance-preparation-notes"].exists)
                reveal(app.buttons["theme-dark"], app); app.buttons["theme-dark"].tap()
                app.swipeDown(); capture(app, "Organized settings dark \(language)")
            }
            app.terminate()
        }
    }
    func testCompactAndLargeTextControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "--light", "--settings", "--organization-ui-test"]
        app.launch(); XCTAssertTrue(app.buttons["practice"].waitForExistence(timeout: 8))
        capture(app, "Compact settings French")
        for id in ["practice", "settings-presets", "settings-setlists", "settings-pedal"] {
            XCTAssertGreaterThanOrEqual(app.buttons[id].frame.height, 44)
        }
        reveal(app.buttons["settings-pedal"], app); app.buttons["settings-pedal"].tap()
        XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 3))
        app.buttons["pedal-toggle"].tap(); app.buttons["pedal-toggle"].tap()
        capture(app, "Compact pedal French")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "--light", "--panel=division", "--organization-ui-test"]
        app.launch(); XCTAssertTrue(app.buttons["division-count-8"].waitForExistence(timeout: 8))
        for i in 1...8 { XCTAssertGreaterThanOrEqual(app.buttons["division-count-\(i)"].frame.width, 44) }
        capture(app, "Compact eight divisions")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(de)", "--light", "--panel=pedal", "--pedal-ui-test", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch(); XCTAssertTrue(app.buttons["pedal-toggle"].waitForExistence(timeout: 8))
        app.buttons["pedal-toggle"].tap(); capture(app, "Accessible pedal German")
        app.buttons["pedal-toggle"].tap()
        reveal(app.buttons["pedal-tap"], app); app.buttons["pedal-tap"].tap()
        XCTAssertEqual(app.buttons["pedal-toggle"].value as? String, "Zuweisen")
        app.buttons["close-panel"].tap()
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
