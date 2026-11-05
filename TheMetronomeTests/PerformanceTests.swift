import XCTest
@testable import TheMetronome

final class PerformanceTests: XCTestCase {
    @MainActor private func clean(_ body: (MetronomeModel) throws -> Void) rethrows {
        let d = UserDefaults.standard
        let keys = ["songLibraryStore", "setlists", "activeSetlistID", "selectedSongID", "rhythm", "presets", "selectedPresetID"]
        let saved = keys.map { d.object(forKey: $0) }
        for key in keys { d.removeObject(forKey: key) }
        defer { for (k, v) in zip(keys, saved) { d.set(v, forKey: k) } }
        let model = MetronomeModel(); defer { model.stop() }
        try body(model)
    }
    @MainActor func testSharedSongEditsMembershipRemovalAndRelaunch() throws {
        try clean { m in
            m.addSetlist("Friday"); let friday = m.activeSetlistID!
            m.addSong("Opener", bpm: 85)
            let song = try XCTUnwrap(m.currentSong ?? m.activeSetlist?.songs.first)
            m.addSetlist("Saturday"); let saturday = m.activeSetlistID!
            m.addExistingSong(song.id); m.addExistingSong(song.id)
            XCTAssertEqual(m.activeSetlist?.songs.count, 1)
            m.loadSong(song)
            m.adjustCurrentSongTempo(91)
            XCTAssertEqual(m.bpm, 91)
            XCTAssertEqual(m.setlists.first { $0.id == friday }?.songs.first?.rhythm.bpm, 91)
            XCTAssertEqual(m.setlists.first { $0.id == saturday }?.songs.first?.rhythm.bpm, 91)
            m.deleteSong(song.id)
            XCTAssertNil(m.selectedSongID); XCTAssertTrue(m.activeSetlist!.songs.isEmpty)
            XCTAssertEqual(m.songLibrary.first?.rhythm.bpm, 91)
            m.deleteActiveSetlist(); m.deleteActiveSetlist()
            XCTAssertTrue(m.setlists.isEmpty); XCTAssertEqual(m.songLibrary.count, 1)
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.songLibrary.first?.id, song.id)
            restored.addSetlist("Sunday"); restored.addExistingSong(song.id)
            XCTAssertEqual(restored.activeSetlist?.songs.first?.rhythm.bpm, 91)
            let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "songLibraryStore"))
            let store = try JSONDecoder().decode(SongLibraryStore.self, from: data)
            XCTAssertEqual(store.songs.count, 1); XCTAssertEqual(store.lists[0].songIDs, [song.id])
        }
    }
    @MainActor func testLegacyListMigrationKeepsSongIDsOrderAndParameters() throws {
        try clean { _ in
            let d = UserDefaults.standard; d.removeObject(forKey: "songLibraryStore")
            var r = Rhythm(); r.bpm = 137; r.setMeter(beats: 7, denominator: 8, compound: false); r.setDivision(3, mask: 5)
            let first = SavedPreset(name: "Odd meter", rhythm: r), second = SavedPreset(name: "Finale", rhythm: Rhythm())
            let list = SongSetlist(name: "Legacy", songs: [first, second])
            d.set(try JSONEncoder().encode([list]), forKey: "setlists")
            d.set(list.id.uuidString, forKey: "activeSetlistID"); d.set(first.id.uuidString, forKey: "selectedSongID")
            let migrated = MetronomeModel(); defer { migrated.stop() }
            XCTAssertEqual(migrated.songLibrary.map(\.id), [first.id, second.id])
            XCTAssertEqual(migrated.currentSong?.rhythm, r)
            migrated.deleteSong(first.id)
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.activeSetlist?.songs.map(\.id), [second.id])
            XCTAssertTrue(restored.songLibrary.contains { $0.id == first.id })
        }
    }
    @MainActor func testTempoEditsWhilePlayingDoNotResetAndMuteKeepsVisualClock() throws {
        try clean { m in
            m.addSetlist("Show"); m.addSong("First", bpm: 180); m.addSong("Last", bpm: 220)
            m.loadSong(m.activeSetlist!.songs[0]); m.soundEnabled = false; m.start()
            XCTAssertTrue(m.playing)
            Thread.sleep(forTimeInterval: 0.45); m.refreshBeat()
            XCTAssertNotNil(m.event)
            let before = m.event!
            m.adjustCurrentSongTempo(190)
            XCTAssertTrue(m.playing); XCTAssertNotNil(m.event)
            XCTAssertEqual(m.event?.beat, before.beat) // no stop/start or clearing the display
            m.soundEnabled = true
            Thread.sleep(forTimeInterval: 0.38); m.refreshBeat()
            XCTAssertTrue(m.playing); XCTAssertNotEqual(m.event?.beat, before.beat)
            m.performPedal(.next); XCTAssertEqual(m.currentSong?.name, "Last"); XCTAssertTrue(m.playing)
            m.performPedal(.next); XCTAssertEqual(m.currentSong?.name, "Last")
            m.deleteSong(m.selectedSongID!); XCTAssertFalse(m.playing)
        }
    }
    func testMuteControlsActualAudioOutputWithoutStoppingClock() throws {
        let audio = MetronomeAudio(); defer { audio.stop() }
        var rhythm = Rhythm(); rhythm.bpm = 240
        try audio.start(rhythm, audible: false)
        XCTAssertEqual(audio.engine.mainMixerNode.outputVolume, 0)
        Thread.sleep(forTimeInterval: 0.3)
        audio.mailbox.lock.lock(); let initial = audio.mailbox.serial; audio.mailbox.lock.unlock()
        XCTAssertGreaterThan(initial, 0)
        audio.setAudible(true)
        XCTAssertEqual(audio.engine.mainMixerNode.outputVolume, 1)
        Thread.sleep(forTimeInterval: 0.3)
        audio.mailbox.lock.lock(); let after = audio.mailbox.serial; audio.mailbox.lock.unlock()
        XCTAssertGreaterThan(after, initial); XCTAssertTrue(audio.engine.isRunning)
    }
}
