import XCTest
import AVFoundation
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
    @MainActor func testLibraryCRUDPersistsWithoutListsAndDeletesEveryReference() throws {
        try clean { m in
            var r = Rhythm(); r.bpm = 123; r.setMeter(beats: 7, denominator: 8, compound: false)
            m.createLibrarySong("  Independent  ", rhythm: r)
            m.createLibrarySong("  ", rhythm: r)
            XCTAssertEqual(m.songLibrary.count, 1); XCTAssertTrue(m.setlists.isEmpty)
            let id = try XCTUnwrap(m.songLibrary.first?.id)
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.songLibrary.first?.name, "Independent")
            m.addSetlist("A"); m.addExistingSong(id)
            m.addSetlist("B"); m.addExistingSong(id)
            m.renameSetlist("  Show  "); XCTAssertEqual(m.activeSetlist?.name, "Show")
            m.editSong(id, name: "Renamed", bpm: 150)
            XCTAssertTrue(m.setlists.allSatisfy { $0.songs.first?.rhythm.bpm == 150 })
            m.loadSong(m.songLibrary[0]); m.start(); XCTAssertTrue(m.playing)
            m.deleteLibrarySong(id)
            XCTAssertFalse(m.playing); XCTAssertNil(m.selectedSongID)
            XCTAssertTrue(m.songLibrary.isEmpty); XCTAssertTrue(m.setlists.allSatisfy { $0.songs.isEmpty })
            let deleted = MetronomeModel(); defer { deleted.stop() }
            XCTAssertTrue(deleted.songLibrary.isEmpty); XCTAssertTrue(deleted.setlists.allSatisfy { $0.songs.isEmpty })
            m.deleteActiveSetlist(); m.deleteActiveSetlist(); XCTAssertTrue(m.setlists.isEmpty)
        }
    }
    func testPolyrhythmSyntheticAndAcousticChoicesProduceAudio() throws {
        // Exercise the real renderer, including a synthetic second lane (previously bell-only).
        for pair in [(InstrumentSound.rim, InstrumentSound.stageClick), (.click, .naturalHiHat)] {
            let audio = MetronomeAudio()
            var r = Rhythm(); r.bpm = 240; r.polyrhythmPrimary = 3; r.crossRhythm = 2
            r.polyrhythmPrimarySound = pair.0.rawValue; r.polyrhythmSecondarySound = pair.1.rawValue
            try audio.start(r)
            let audible = expectation(description: "Audible \(pair.0) / \(pair.1)")
            var fulfilled = false
            audio.engine.mainMixerNode.installTap(onBus: 0, bufferSize: 512, format: nil) { buffer, _ in
                guard !fulfilled, let samples = buffer.floatChannelData?[0] else { return }
                for i in 0..<Int(buffer.frameLength) where abs(samples[i]) > 0.001 {
                    fulfilled = true; audible.fulfill(); break
                }
            }
            wait(for: [audible], timeout: 3)
            audio.engine.mainMixerNode.removeTap(onBus: 0); audio.stop()
        }
    }
    func testPolyrhythmSoundDefaultsMigrationAndIndependentChoices() throws {
        var r = Rhythm(); r.polyrhythmPrimary = 3; r.crossRhythm = 2
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as? [String: Any])
        json.removeValue(forKey: "polyrhythmPrimarySound"); json.removeValue(forKey: "polyrhythmSecondarySound")
        let legacy = try JSONDecoder().decode(Rhythm.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.primaryPulseSound, InstrumentSound.wood.rawValue)
        XCTAssertEqual(legacy.secondaryPulseSound, InstrumentSound.bell.rawValue)
        for sound in InstrumentSound.allCases {
            r.polyrhythmPrimarySound = sound.rawValue; r.polyrhythmSecondarySound = InstrumentSound.stageClick.rawValue
            let restored = try JSONDecoder().decode(Rhythm.self, from: JSONEncoder().encode(r))
            XCTAssertEqual(restored.primaryPulseSound, sound.rawValue)
            XCTAssertEqual(restored.secondaryPulseSound, InstrumentSound.stageClick.rawValue)
        }
        r.polyrhythmPrimarySound = 999; r.polyrhythmSecondarySound = -1
        XCTAssertEqual(r.primaryPulseSound, InstrumentSound.wood.rawValue); XCTAssertEqual(r.secondaryPulseSound, InstrumentSound.bell.rawValue)
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
