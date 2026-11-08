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
    @MainActor func testCatalogReorderPersistsWithoutChangingSetlistsOrPlayback() throws {
        try clean { m in
            let list = try XCTUnwrap(m.addSetlist("Show"))
            m.addSong("A", bpm: 100); m.addSong("B", bpm: 110); m.addSong("C", bpm: 120)
            let original = try XCTUnwrap(m.activeSetlist).songs.map(\.id)
            m.startSetlist(list)
            m.moveLibrarySong(original[0], to: 2)
            XCTAssertEqual(m.songLibrary.map(\.name), ["B","C","A"])
            XCTAssertEqual(m.activeSetlist?.songs.map(\.id), original)
            XCTAssertEqual(m.selectedSongID, original[0]); XCTAssertTrue(m.playing)
            m.moveLibrarySong(original[0], to: -1)
            XCTAssertEqual(m.songLibrary.map(\.name), ["B","C","A"])
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.songLibrary.map(\.name), ["B","C","A"])
            XCTAssertEqual(restored.activeSetlist?.songs.map(\.id), original)
        }
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
            m.tap(live: true, at: 10)
            m.tap(live: true, at: 10.5)
            XCTAssertEqual(m.bpm, 120)
            m.performPedal(.faster)
            XCTAssertEqual(m.bpm, 121)
            m.editSong(song.id, name: song.name, rhythm: song.rhythm, notes: "Watch the ending")
            XCTAssertEqual(m.bpm, 121)
            XCTAssertEqual(m.currentSong?.rhythm.bpm, 85)
            let reopened = MetronomeModel()
            XCTAssertEqual(reopened.bpm, 85)
            m.loadSong(song)
            XCTAssertEqual(m.bpm, 85)
            m.editSong(song.id, name: song.name, bpm: 91)
            XCTAssertEqual(m.bpm, 91)
            XCTAssertEqual(m.setlists.first { $0.id == friday }?.songs.first?.rhythm.bpm, 91)
            XCTAssertEqual(m.setlists.first { $0.id == saturday }?.songs.first?.rhythm.bpm, 91)
            m.deleteSong(song.id)
            XCTAssertEqual(m.selectedSongID, song.id); XCTAssertNil(m.activeSetlist)
            XCTAssertTrue(m.setlists.first { $0.id == saturday }!.songs.isEmpty)
            XCTAssertEqual(m.songLibrary.first?.rhythm.bpm, 91)
            for id in m.setlists.map(\.id) { m.deleteSetlist(id) }
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
            for id in m.setlists.map(\.id) { m.deleteSetlist(id) }; XCTAssertTrue(m.setlists.isEmpty)
        }
    }
    @MainActor func testBrowsingListMutationsNeverChangeLoadedSongOrClock() throws {
        try clean { m in
            let show = try XCTUnwrap(m.addSetlist("Show"))
            m.addSong("Opener", bpm: 180)
            let opener = try XCTUnwrap(m.activeSetlist?.songs.first)
            m.loadSong(opener, from: show); m.start()
            let original = m.rhythm
            let other = try XCTUnwrap(m.addSetlist("Other", activate: false))
            m.addExistingSong(opener.id, to: other)
            m.addSong("Encore", bpm: 150, into: other)
            m.renameSetlist("Rehearsal", in: other)
            m.moveSong(opener.id, to: 1, in: other)
            XCTAssertEqual(m.setlists.first { $0.id == other }?.songs.map(\.name), ["Encore", "Opener"])
            m.deleteSong(opener.id, from: other)
            m.deleteSetlist(other)
            XCTAssertTrue(m.playing); XCTAssertEqual(m.activeSetlistID, show)
            XCTAssertEqual(m.selectedSongID, opener.id); XCTAssertEqual(m.rhythm, original)
            XCTAssertEqual(m.presetCaption, "Opener · Show")
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.activeSetlistID, show); XCTAssertEqual(restored.presetCaption, m.presetCaption)
        }
    }
    @MainActor func testReorderUsesStableSongsAndSelectingAcrossListsIsExplicit() throws {
        try clean { m in
            let first = try XCTUnwrap(m.addSetlist("Friday"))
            for name in ["A", "B", "C", "D"] { m.addSong(name, bpm: 180) }
            let a = m.activeSetlist!.songs[0], c = m.activeSetlist!.songs[2]
            m.loadSong(c, from: first); m.start()
            m.moveSong(a.id, to: 3, in: first)
            XCTAssertEqual(m.activeSetlist?.songs.map(\.name), ["B", "C", "D", "A"])
            m.moveSong(a.id, to: -1, in: first); m.moveSong(a.id, to: 4, in: first)
            XCTAssertEqual(m.activeSetlist?.songs.map(\.name), ["B", "C", "D", "A"])
            XCTAssertEqual(m.selectedSongID, c.id); XCTAssertTrue(m.playing)
            let second = try XCTUnwrap(m.addSetlist("Saturday", activate: false))
            m.addExistingSong(c.id, to: second)
            Thread.sleep(forTimeInterval: 0.2); m.refreshBeat(); let beat = m.event
            m.loadSong(c, from: second)
            XCTAssertEqual(m.activeSetlistID, second); XCTAssertEqual(m.selectedSongID, c.id)
            XCTAssertTrue(m.playing); XCTAssertEqual(m.event?.beat, beat?.beat)
            m.loadSong(a, from: second) // Invalid membership must not change the live context.
            XCTAssertEqual(m.selectedSongID, c.id)
            m.deleteSetlist(first); XCTAssertTrue(m.playing)
            m.deleteSetlist(second); XCTAssertTrue(m.playing); XCTAssertNil(m.activeSetlistID)
        }
    }
    @MainActor func testRecentPresetCaptionSurvivesTweaksAndIndependentListCreation() throws {
        try clean { m in
            let preset = SavedPreset(name: "Warm hands", rhythm: Rhythm())
            m.presets = [preset]; m.load(preset)
            m.rhythm.bpm = 103
            XCTAssertEqual(m.presetCaption, "Warm hands")
            XCTAssertFalse(m.isCurrentPreset(preset))
            m.addSetlist("Planning", activate: false)
            XCTAssertNil(m.activeSetlistID); XCTAssertEqual(m.presetCaption, "Warm hands")
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.presetCaption, "Warm hands"); XCTAssertEqual(restored.bpm, 103)
        }
    }
    @MainActor func testNotesMigrationSharingAndManualSetlistStart() throws {
        try clean { m in
            let old = SavedPreset(name: "Legacy", rhythm: Rhythm())
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
            json.removeValue(forKey: "notes")
            XCTAssertNil(try JSONDecoder().decode(SavedPreset.self, from: JSONSerialization.data(withJSONObject: json)).notes)
            let list = try XCTUnwrap(m.addSetlist("Show", activate: false))
            m.addSong("First", bpm: 180, into: list, notes: "Enter after four bars")
            m.addSong("Second", bpm: 100, into: list)
            m.startSetlist(list)
            XCTAssertTrue(m.playing); XCTAssertEqual(m.currentSong?.name, "First")
            let id = try XCTUnwrap(m.currentSong?.id)
            m.adjustCurrentSongTempo(181); XCTAssertEqual(m.currentSong?.notes, "Enter after four bars")
            let other = try XCTUnwrap(m.addSetlist("Other", activate: false)); m.addExistingSong(id, to: other)
            m.editSong(id, name: "First", rhythm: m.rhythm, notes: "Quiet ending")
            XCTAssertEqual(m.setlists.first { $0.id == other }?.songs.first?.notes, "Quiet ending")
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.currentSong?.notes, "Quiet ending")
            m.performPedal(.next); XCTAssertEqual(m.currentSong?.name, "Second")
            m.performPedal(.next); XCTAssertEqual(m.currentSong?.name, "Second")
            m.startSetlist(list); XCTAssertEqual(m.currentSong?.name, "First")
            let copy = try XCTUnwrap(m.duplicateSetlist(list))
            XCTAssertEqual(m.activeSetlistID, list); XCTAssertTrue(m.playing)
            XCTAssertEqual(m.setlists.first { $0.id == copy }?.songs.map(\.id), m.activeSetlist?.songs.map(\.id))
            m.editSong(id, name: "First", rhythm: m.rhythm, notes: "")
            XCTAssertEqual(m.currentSong?.notes, "")
        }
    }
    @MainActor func testStandaloneSongContextPersistenceAndPedalIsolation() throws {
        try clean { m in
            let list = try XCTUnwrap(m.addSetlist("Set"))
            m.addSong("A", bpm: 120); m.addSong("B", bpm: 140)
            let a = m.songLibrary[0], b = m.songLibrary[1]
            m.presets = [SavedPreset(name: "Practice", rhythm: Rhythm())]
            m.loadSong(a, from: list); m.start()
            let before = m.event
            m.loadStandaloneSong(a.id)
            XCTAssertNil(m.activeSetlist); XCTAssertEqual(m.currentSong?.id, a.id)
            XCTAssertTrue(m.playing); XCTAssertEqual(m.event?.beat, before?.beat)
            m.addPreset("Song snapshot")
            XCTAssertNil(UserDefaults.standard.string(forKey: "selectedPresetID")); XCTAssertEqual(m.currentSong?.id, a.id)
            m.performPedal(.next); m.performPedal(.previous)
            XCTAssertEqual(m.currentSong?.id, a.id); XCTAssertEqual(m.presetCaption, "A")
            let restored = MetronomeModel(); defer { restored.stop() }
            XCTAssertEqual(restored.currentSong?.id, a.id); XCTAssertNil(restored.activeSetlist)
            m.loadStandaloneSong(b.id); XCTAssertTrue(m.playing); XCTAssertEqual(m.bpm, 140)
            m.stop(); m.loadStandaloneSong(a.id); XCTAssertFalse(m.playing)
            m.loadStandaloneSong(UUID()); XCTAssertEqual(m.currentSong?.id, a.id)
        }
    }
    @MainActor func testListDraftAtomicCommitDeduplicatesAndPreservesCurrentSong() throws {
        try clean { m in
            let a = try XCTUnwrap(m.createLibrarySong("A", rhythm: Rhythm()))
            let b = try XCTUnwrap(m.createLibrarySong("B", rhythm: Rhythm()))
            XCTAssertNil(m.saveSetlist(id: nil, name: "  ", songIDs: [a]))
            XCTAssertTrue(m.setlists.isEmpty)
            let list = try XCTUnwrap(m.saveSetlist(id: nil, name: "  Show  ", songIDs: [a,b,a,UUID()]))
            XCTAssertEqual(m.setlists[0].songs.map(\.id), [a,b]); XCTAssertNil(m.activeSetlistID)
            m.loadSong(m.songLibrary[0], from: list); m.start()
            m.editSong(b, name: "B edited", bpm: 150)
            m.saveSetlist(id: list, name: "Renamed", songIDs: [b])
            XCTAssertNil(m.activeSetlistID); XCTAssertEqual(m.currentSong?.id, a); XCTAssertTrue(m.playing)
            XCTAssertEqual(m.setlists[0].songs[0].name, "B edited")
            XCTAssertEqual(m.setlists[0].songs[0].rhythm.bpm, 150)
            let empty = try XCTUnwrap(m.saveSetlist(id: nil, name: "Empty", songIDs: []))
            m.moveSetlist(empty, to: 0); XCTAssertEqual(m.setlists[0].id, empty)
            m.moveSetlist(empty, to: -1); XCTAssertEqual(m.setlists[0].id, empty)
            m.deleteSetlist(list); XCTAssertEqual(m.songLibrary.count, 2); XCTAssertTrue(m.playing)
            XCTAssertNil(m.saveSetlist(id: list, name: "Stale", songIDs: []))
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
            XCTAssertNil(restored.activeSetlist)
            XCTAssertEqual(restored.setlists.first?.songs.map(\.id), [second.id])
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
            m.deleteSong(m.selectedSongID!); XCTAssertTrue(m.playing); XCTAssertNil(m.activeSetlistID)
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
