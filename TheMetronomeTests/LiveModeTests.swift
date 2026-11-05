import XCTest
import AVFoundation
@testable import TheMetronome

final class LiveModeTests: XCTestCase {
    @MainActor func testFirstPressLearnsWithoutVerificationAndSavedMappingWorksAfterReset() {
        let defaults = UserDefaults(suiteName: "PedalDirectLearningTests")!
        defaults.removePersistentDomain(forName: "PedalDirectLearningTests")
        defer { defaults.removePersistentDomain(forName: "PedalDirectLearningTests") }
        let pedal = PedalControl(defaults: defaults)
        let key = PedalBinding(kind: .keyboard, code: 40, label: "RETURN")
        var actions: [PedalAction] = []
        pedal.perform = { actions.append($0) }
        pedal.setupVisible = true
        XCTAssertFalse(pedal.inputAvailable)
        pedal.learn(.toggle)
        XCTAssertTrue(pedal.receive(key, down: true, at: 0))
        XCTAssertEqual(pedal.bindings[.toggle], key)
        XCTAssertTrue(actions.isEmpty)
        XCTAssertFalse(pedal.receive(key, down: true, at: 1))
        pedal.receive(key, down: false, at: 2)
        pedal.resetInputSession()
        XCTAssertFalse(pedal.inputAvailable)
        XCTAssertTrue(pedal.receive(key, down: true, at: 3))
        XCTAssertEqual(actions, [.toggle])
        pedal.receive(key, down: false, at: 4)
        pedal.learn(.tap)
        pedal.cancelLearning()
        XCTAssertEqual(pedal.bindings[.toggle], key)
        pedal.resetInputSession()
        pedal.learn(.tap)
        XCTAssertTrue(pedal.media(10, label: "NEXT"))
        XCTAssertEqual(pedal.bindings[.tap]?.kind, .media)
        XCTAssertEqual(actions, [.toggle])
        let restored = PedalControl(defaults: defaults)
        XCTAssertEqual(restored.bindings, pedal.bindings)
        XCTAssertFalse(restored.bluetoothConnected)
    }
    @MainActor func testBluetoothIndicatorRequiresMappedOnlineBluetoothSource() {
        let defaults = UserDefaults(suiteName: "PedalBluetoothStatusTests")!
        defaults.removePersistentDomain(forName: "PedalBluetoothStatusTests")
        defer { defaults.removePersistentDomain(forName: "PedalBluetoothStatusTests") }
        let pedal = PedalControl(defaults: defaults)
        pedal.updateMIDISources([12], bluetooth: [12])
        XCTAssertFalse(pedal.bluetoothConnected) // unrelated Bluetooth MIDI device
        pedal.learn(.toggle)
        pedal.receiveMIDI([0x90,60,100],source: 12)
        XCTAssertTrue(pedal.bluetoothConnected)
        XCTAssertEqual(pedal.pressRevision,1)
        pedal.receiveMIDI([0x90,60,100],source: 12)
        XCTAssertEqual(pedal.pressRevision,1) // held key must not pulse repeatedly
        pedal.updateMIDISources([12])
        XCTAssertFalse(pedal.bluetoothConnected) // wired/unknown transport
        pedal.updateMIDISources([12],bluetooth: [12])
        XCTAssertTrue(pedal.bluetoothConnected)
        pedal.updateMIDISources([],bluetooth: [12])
        XCTAssertFalse(pedal.bluetoothConnected) // stale Bluetooth metadata
        pedal.receiveMIDI([0x90,60,100],source: 12)
        XCTAssertEqual(pedal.pressRevision,1)
        pedal.updateMIDISources([12],bluetooth: [12])
        pedal.clearAll()
        XCTAssertFalse(pedal.bluetoothConnected)
        pedal.learn(.toggle)
        pedal.receive(PedalBinding(kind: .keyboard,code: 40,label: "RETURN"),down: true)
        XCTAssertFalse(pedal.bluetoothConnected) // HID cannot establish Bluetooth identity
    }
    @MainActor func testDisconnectDuringRebindPreservesSavedKeyAndClearsHeldPress() {
        let defaults = UserDefaults(suiteName: "PedalDisconnectTests")!
        defaults.removePersistentDomain(forName: "PedalDisconnectTests")
        defer { defaults.removePersistentDomain(forName: "PedalDisconnectTests") }
        let pedal = PedalControl(defaults: defaults)
        let key = PedalBinding(kind: .keyboard, code: 40, label: "RETURN")
        pedal.learn(.toggle)
        XCTAssertTrue(pedal.receive(key, down: true, at: 0))
        pedal.learn(.toggle)
        pedal.resetInputSession()
        XCTAssertNil(pedal.learning)
        XCTAssertEqual(pedal.bindings[.toggle], key)
        var actions: [PedalAction] = []
        pedal.perform = { actions.append($0) }
        // Reconnect without an old key-up must not leave the pedal stuck.
        XCTAssertTrue(pedal.receive(key, down: true, at: 1))
        XCTAssertEqual(actions, [.toggle])
        pedal.resetInputSession()
        XCTAssertEqual(pedal.bindings[.toggle], key)
    }
    @MainActor func testMIDIDisconnectRejectsQueuedEventsAndReconnectNeedsFreshMessage() {
        let defaults = UserDefaults(suiteName: "PedalMIDILifecycleTests")!
        defaults.removePersistentDomain(forName: "PedalMIDILifecycleTests")
        defer { defaults.removePersistentDomain(forName: "PedalMIDILifecycleTests") }
        let pedal = PedalControl(defaults: defaults)
        pedal.updateMIDISources([12])
        pedal.learn(.toggle)
        pedal.receiveMIDI([0x90, 60, 100], source: 12)
        XCTAssertEqual(pedal.bindings[.toggle]?.source, 12)
        var actions: [PedalAction] = []
        pedal.perform = { actions.append($0) }
        pedal.learn(.toggle)
        pedal.updateMIDISources([])
        XCTAssertNil(pedal.learning)
        pedal.receiveMIDI([0x90, 60, 100], source: 12)
        XCTAssertTrue(actions.isEmpty) // queued input after disconnection
        XCTAssertNotNil(pedal.bindings[.toggle])
        pedal.updateMIDISources([12])
        pedal.receiveMIDI([0x90, 60], source: 12) // partial packet
        pedal.updateMIDISources([])
        pedal.updateMIDISources([12])
        pedal.receiveMIDI([100], source: 12)
        XCTAssertTrue(actions.isEmpty) // no running status carried across sessions
        pedal.receiveMIDI([0x90, 60, 100], source: 99)
        XCTAssertTrue(actions.isEmpty) // unknown source
        pedal.receiveMIDI([0x90, 60, 100], source: 12)
        XCTAssertEqual(actions, [.toggle])
    }
    @MainActor func testSameMIDITopologyDoesNotCancelLearningButSourceReplacementDoes() {
        let defaults = UserDefaults(suiteName: "PedalTopologyTests")!
        defer { defaults.removePersistentDomain(forName: "PedalTopologyTests") }
        let pedal = PedalControl(defaults: defaults)
        pedal.updateMIDISources([12]); pedal.learn(.tap)
        pedal.updateMIDISources([12]); XCTAssertEqual(pedal.learning, .tap)
        pedal.updateMIDISources([13]); XCTAssertNil(pedal.learning)
        XCTAssertTrue(pedal.bindings.isEmpty)
    }
    @MainActor func testLeavingForegroundCancelsLearningWithoutDeletingAssignment() async throws {
        let defaults = UserDefaults(suiteName: "PedalForegroundTests")!
        defaults.removePersistentDomain(forName: "PedalForegroundTests")
        defer { defaults.removePersistentDomain(forName: "PedalForegroundTests") }
        let pedal = PedalControl(defaults: defaults)
        let key = PedalBinding(kind: .keyboard, code: 44, label: "SPACE")
        pedal.learn(.toggle); pedal.receive(key, down: true, at: 0)
        pedal.learn(.next)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(pedal.learning)
        XCTAssertEqual(pedal.bindings[.toggle], key)
        XCTAssertNil(pedal.bindings[.next])
    }
    func testLearnConsumesPressRebindAndHeldKeyDoesNotRepeat() {
        var gate = PedalGate()
        let key = PedalBinding(kind: .keyboard, code: 40, label: "RETURN")
        gate.learning = .toggle
        XCTAssertEqual(gate.receive(key, down: true, at: 0), .learned)
        XCTAssertEqual(gate.receive(key, down: true, at: 1), .ignored)
        XCTAssertEqual(gate.receive(key, down: false, at: 1), .ignored)
        XCTAssertEqual(gate.receive(key, down: true, at: 2), .perform(.toggle))
        gate.learning = .tap; gate.clearHeld()
        XCTAssertEqual(gate.receive(key, down: true, at: 3), .learned)
        XCTAssertNil(gate.bindings[.toggle]); XCTAssertEqual(gate.bindings[.tap], key)
        _ = gate.receive(key, down: false, at: 3.01)
        XCTAssertEqual(gate.receive(key, down: true, at: 3.02), .ignored) // switch bounce
        _ = gate.receive(key, down: false, at: 3.05)
        XCTAssertEqual(gate.receive(key, down: true, at: 3.2), .perform(.tap)) // 300 BPM remains possible
    }
    func testMIDIPacketBoundariesRealtimeNoteOffCCAndDeviceIdentity() {
        var parser = PedalMIDIParser()
        XCTAssertTrue(parser.feed([0x91, 60], source: 12).isEmpty)
        let down = parser.feed([0xF8, 100], source: 12)
        XCTAssertEqual(down.count, 1); XCTAssertTrue(down[0].1)
        XCTAssertEqual(down[0].0.channel, 1); XCTAssertEqual(down[0].0.source, 12)
        XCTAssertFalse(parser.feed([60, 0], source: 12)[0].1)
        let cc = parser.feed([0xB0, 64, 127, 64, 0], source: 12)
        XCTAssertEqual(cc.count, 2); XCTAssertTrue(cc[0].1); XCTAssertFalse(cc[1].1)
        let pc = parser.feed([0xC2, 7, 8], source: 12)
        XCTAssertEqual(pc.count, 4); XCTAssertEqual(pc[0].0.kind, .midiProgram)
        XCTAssertTrue(pc[0].1); XCTAssertFalse(pc[1].1); XCTAssertEqual(pc[2].0.code, 8)
        XCTAssertTrue(parser.feed([0xF0, 1, 2, 3, 0xF7, 1, 2], source: 12).isEmpty)
        var gate = PedalGate(); gate.bindings[.toggle] = down[0].0
        var another = down[0].0; another.source = 99
        XCTAssertEqual(gate.receive(another, down: true, at: 0), .ignored)
    }
    func testClockRecoveryMatchesUninterruptedRampGapAndCountIn() {
        var rhythm = Rhythm(); rhythm.countIn = 1; rhythm.ramp = true
        rhythm.start = 90; rhythm.end = 140; rhythm.every = 2; rhythm.increment = 5
        rhythm.gap = true; rhythm.audibleBars = 2; rhythm.silentBars = 3; rhythm.subdivision = 3
        let reference = SampleClock(rate: 1000); reference.reset(rhythm)
        for _ in 0..<1357 { _ = reference.advance() }
        let resumed = reference.copy(atRate: 1000)
        for _ in 0..<600_000 { _ = reference.advance() }
        resumed.skip(seconds: 600)
        XCTAssertEqual(reference.tick, resumed.tick); XCTAssertEqual(reference.tempo, resumed.tempo)
        for _ in 0..<20_000 {
            let a = reference.advance(), b = resumed.advance()
            XCTAssertEqual(a?.0.beat, b?.0.beat); XCTAssertEqual(a?.0.bar, b?.0.bar)
            XCTAssertEqual(a?.0.silent, b?.0.silent); XCTAssertEqual(a?.1, b?.1)
        }
    }
    func testClockRecoveryRescalesFractionalPositionWhenOutputChanges() {
        var r = Rhythm(); r.bpm = 120
        let clock = SampleClock(rate: 1000); clock.reset(r)
        for _ in 0..<250 { _ = clock.advance() }
        let recovered = clock.copy(atRate: 2000)
        recovered.skip(seconds: 0.1)
        var firstHit: Int?
        for index in 0..<1000 { if recovered.advance() != nil { firstHit = index; break } }
        XCTAssertEqual(firstHit, 300)
    }
    @MainActor func testSixActionsPersistenceAndSetlistBoundaries() {
        let defaults = UserDefaults.standard
        let keys = ["rhythm", "presets", "selectedPresetID", "pedalBindings", "pedalProfiles", "pedalProfileID", "activeSetlistID", "selectedSongID", "songLibraryStore", "setlists"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        let model = MetronomeModel(); defer { model.stop() }
        model.presets = []; model.activeSetlistID = nil; model.rhythm = Rhythm(); model.addPreset("ONE")
        model.setBPM(130); model.addPreset("TWO")
        model.performPedal(.previous); XCTAssertEqual(model.bpm, 96)
        model.performPedal(.previous); XCTAssertEqual(model.bpm, 96)
        model.performPedal(.next); XCTAssertEqual(model.bpm, 130)
        model.performPedal(.next); XCTAssertEqual(model.bpm, 130)
        model.performPedal(.faster); XCTAssertEqual(model.bpm, 131)
        model.performPedal(.slower); XCTAssertEqual(model.bpm, 130)
        model.performPedal(.tap); XCTAssertEqual(model.tapCount, 1)
        model.performPedal(.toggle); XCTAssertTrue(model.playing)
        model.performPedal(.previous); XCTAssertTrue(model.playing); XCTAssertEqual(model.bpm, 96)
        model.performPedal(.toggle); XCTAssertFalse(model.playing)
        model.pedal.clearAll()
        for (index, action) in PedalAction.allCases.enumerated() {
            model.pedal.learn(action)
            let key = PedalBinding(kind: .keyboard, code: 40 + index, label: "KEY")
            model.pedal.receive(key, down: true, at: Double(index))
            model.pedal.receive(key, down: false, at: Double(index) + 0.1)
        }
        XCTAssertEqual(model.pedal.bindings.count, 6)
        let restored = PedalControl(defaults: defaults)
        XCTAssertEqual(restored.bindings, model.pedal.bindings)
    }
    @MainActor func testExplicitMediaPauseNeverStartsAndPlayNeverStops() async throws {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "pedalBindings")
        defer { defaults.set(original, forKey: "pedalBindings") }
        let model = MetronomeModel(); defer { model.stop() }
        model.pedal.clearAll(); model.pedal.learn(.toggle)
        XCTAssertTrue(model.pedal.media(0, label: "PLAY / PAUSE"))
        try await Task.sleep(for: .milliseconds(100))
        model.handleMediaCommand(code: 0, label: "PLAY / PAUSE", explicitPlaying: false) { model.stop() }
        XCTAssertFalse(model.playing)
        model.handleMediaCommand(code: 0, label: "PLAY / PAUSE", explicitPlaying: true) { model.start() }
        XCTAssertTrue(model.playing)
        try await Task.sleep(for: .milliseconds(100))
        model.handleMediaCommand(code: 0, label: "PLAY / PAUSE", explicitPlaying: true) { model.start() }
        XCTAssertTrue(model.playing)
        model.handleMediaCommand(code: 0, label: "PLAY / PAUSE", explicitPlaying: false) { model.stop() }
        XCTAssertFalse(model.playing)
    }
    @MainActor func testInterruptedPlaybackResumesOnlyWithPermissionAndUserIntent() async throws {
        let model = MetronomeModel(); defer { model.stop() }
        model.start(); XCTAssertTrue(model.playing)
        try await Task.sleep(for: .milliseconds(100))
        let began = AVAudioSession.InterruptionType.began.rawValue
        let ended = AVAudioSession.InterruptionType.ended.rawValue
        let resume = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        model.handleInterruption(type: began, options: 0)
        XCTAssertFalse(model.playing); XCTAssertTrue(model.transportActive)
        model.handleInterruption(type: ended, options: resume)
        XCTAssertTrue(model.playing)
        model.handleInterruption(type: began, options: 0)
        model.toggle() // a pedal stop during interruption cancels the pending resume
        model.handleInterruption(type: ended, options: resume)
        XCTAssertFalse(model.playing)
        model.start(); model.handleInterruption(type: began, options: 0)
        model.handleInterruption(type: ended, options: 0)
        XCTAssertFalse(model.playing)
        model.start(); model.handleInterruption(type: began, options: 0)
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        try await Task.sleep(for: .milliseconds(50))
        model.handleInterruption(type: ended, options: resume)
        XCTAssertFalse(model.playing) // never resume through speaker after headphones disconnect
    }
}

final class StageFeatureTests: XCTestCase {
    func testSubdivisionPatternsAndPolyrhythmsAtSampleBoundaries() throws {
        for bpm in [20, 137, 300] {
            for divisions in 1...8 {
                for mask in 1..<(1 << divisions) {
                    var r = Rhythm(); r.bpm = bpm; r.setDivision(divisions, mask: mask)
                    let clock = SampleClock(rate: 1200); clock.reset(r)
                    var hits: [Int] = []
                    for frame in 0..<Int(ceil(1200 * 60 / Double(bpm))) {
                        if let (_, strength) = clock.advance(), strength > 0 { hits.append(frame) }
                    }
                    let expected = (0..<divisions).filter { mask & (1 << $0) != 0 }.map { Int(ceil(Double($0) * 1200 * 60 / Double(bpm * divisions) - 0.000001)) }
                    XCTAssertEqual(hits.count, expected.count)
                    for (actual, target) in zip(hits, expected) { XCTAssertLessThanOrEqual(abs(actual - target), 1) }
                }
            }
        }
        var r = Rhythm(); r.bpm = 60; r.setDivision(3); r.crossRhythm = 2
        let clock = SampleClock(rate: 600); clock.reset(r)
        var hits: [Int] = []
        for frame in 0..<600 { if let (e, s) = clock.advance(), s > 0 || e.crossStrength > 0 { hits.append(frame) } }
        XCTAssertEqual(hits, [0, 200, 300, 400])
        r.setDivision(6, mask: 17); r.crossRhythm = nil; clock.reset(r); hits = []
        for frame in 0..<600 { if let (e, s) = clock.advance(), s > 0 || e.crossStrength > 0 { hits.append(frame) } }
        XCTAssertEqual(hits, [0, 400]) // long-short swing, not equal eighths
        r.sanitize()
        XCTAssertEqual(try JSONDecoder().decode(Rhythm.self, from: JSONEncoder().encode(r)), r)
    }
    func testStageClickIsBoundedShortAndPresentWithoutShrillDownbeat() {
        for rate in [44100.0, 48000.0, 96000.0] {
            for strength in [1, 2, 3, 4, 5] {
                var stage = ClickVoice(); stage.trigger(sound: 16, strength: strength)
                let samples = (0..<Int(rate * 0.1)).map { _ in stage.sample(rate: rate) }
                XCTAssertEqual(samples[0], 0)
                XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) < 1 })
                XCTAssertTrue(samples.suffix(Int(rate * 0.05)).allSatisfy { $0 == 0 })
                // Compare equal windows so a longer decay cannot masquerade as a higher pitch.
                func pitch(_ signal: [Float]) -> Double {
                    let window = Array(signal[Int(rate * 0.005)..<Int(rate * 0.025)])
                    let crossings = zip(window, window.dropFirst()).filter { $0.0 <= 0 && $0.1 > 0 }.count
                    return Double(crossings) / 0.020
                }
                let stagePitch = pitch(samples)
                XCTAssertGreaterThan(stagePitch, 2000)
                XCTAssertLessThan(stagePitch, 3000, "The accented hit should not return to the piercing 4 kHz register")
                var classic = ClickVoice(); classic.trigger(sound: 1, strength: strength)
                let classicSamples = (0..<Int(rate * 0.1)).map { _ in classic.sample(rate: rate) }
                XCTAssertGreaterThan(stagePitch, pitch(classicSamples))
            }
        }
    }
    func testEveryPolyrhythmPairAndLegacyRhythmDecoding() throws {
        for bpm in [60, 137, 300] {
            for base in 1...8 {
                for secondary in 2...9 {
                    var r = Rhythm(); r.bpm = bpm; r.setDivision(base); r.crossRhythm = secondary
                    let rate = 6000.0, beatFrames = rate * 60 / Double(bpm)
                    let clock = SampleClock(rate: rate); clock.reset(r)
                    var hits: [Int] = []
                    for frame in 0..<Int(ceil(beatFrames)) {
                        if let (e, strength) = clock.advance(), strength > 0 || e.crossStrength > 0 { hits.append(frame) }
                    }
                    let expected = Set((0..<base).map { Int(ceil(Double($0) * beatFrames / Double(base) - 0.000001)) }
                        + (0..<secondary).map { Int(ceil(Double($0) * beatFrames / Double(secondary) - 0.000001)) }).sorted()
                    XCTAssertEqual(hits.count, expected.count, "\(base):\(secondary) at \(bpm)")
                    for (actual, target) in zip(hits, expected) { XCTAssertLessThanOrEqual(abs(actual - target), 1) }
                    r.accents = Array(repeating: 0, count: 12); clock.reset(r)
                    for _ in 0..<Int(ceil(beatFrames)) { if let (_, s) = clock.advance() { XCTAssertEqual(s, 0) } }
                }
            }
        }
        var legacy = Rhythm(); legacy.bpm = 137; legacy.subdivision = 4
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "divisionMask"); json.removeValue(forKey: "crossRhythm")
        let restored = try JSONDecoder().decode(Rhythm.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored, legacy); XCTAssertEqual(restored.clockDivisions, 4)
    }
    @MainActor func testSetlistCRUDPersistencePedalsAndPresetIsolation() throws {
        let defaults = UserDefaults.standard
        let keys = ["songLibraryStore", "setlists", "activeSetlistID", "selectedSongID", "rhythm", "presets", "selectedPresetID"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (k,v) in zip(keys,saved) { defaults.set(v, forKey: k) } }
        let m = MetronomeModel(); defer { m.stop() }
        m.setlists = []; m.presets = []; m.rhythm = Rhythm()
        m.addPreset("OLD"); m.addSetlist("Live")
        m.addSong("First", bpm: 85); m.addSong("Second", bpm: 140)
        let first = m.activeSetlist!.songs[0], second = m.activeSetlist!.songs[1]
        m.performPedal(.next); XCTAssertEqual(m.bpm, 85)
        m.performPedal(.next); XCTAssertEqual(m.bpm, 140)
        m.performPedal(.next); XCTAssertEqual(m.selectedSongID, second.id) // no wrap
        m.performPedal(.previous); XCTAssertEqual(m.selectedSongID, first.id)
        m.editSong(first.id, name: "Opening", bpm: 90); XCTAssertEqual(m.bpm, 90)
        m.moveSong(second.id, by: -1); XCTAssertEqual(m.activeSetlist?.songs.first?.id, second.id)
        m.renameSetlist("Show")
        let restored = MetronomeModel(); defer { restored.stop() }
        XCTAssertEqual(restored.activeSetlist?.name, "Show")
        XCTAssertEqual(restored.currentSong?.name, "Opening")
        XCTAssertEqual(restored.activeSetlist?.songs.first?.rhythm.bpm, 140)
        m.deleteSong(first.id); XCTAssertNil(m.selectedSongID)
        m.deleteActiveSetlist(); XCTAssertTrue(m.setlists.isEmpty)
        XCTAssertEqual(m.presets.count, 1)
        m.load(m.presets[0]); XCTAssertNil(m.activeSetlistID)
    }
}

final class OrganizationTests: XCTestCase {
    @MainActor func testPracticePresetCopiesToPerformanceSongWithoutEffects() throws {
        let defaults = UserDefaults.standard
        let keys = ["songLibraryStore", "setlists", "activeSetlistID", "selectedSongID", "rhythm", "presets", "selectedPresetID"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (k,v) in zip(keys,saved) { defaults.set(v, forKey: k) } }
        let m = MetronomeModel(); defer { m.stop() }
        m.presets = []; m.setlists = []; m.rhythm = Rhythm()
        m.rhythm.ramp = true; m.rhythm.start = 72; m.rhythm.end = 110
        m.rhythm.gap = true; m.rhythm.silentBars = 2; m.rhythm.sound = 16
        m.rhythm.setDivision(3, mask: 5); m.rhythm.crossRhythm = 2
        m.addPreset("  Warm hands  ")
        let original = try XCTUnwrap(m.presets.first)
        XCTAssertEqual(original.name, "Warm hands")
        XCTAssertNil(m.activeSetlist)
        m.addSetlist("Friday")
        m.importPreset(original)
        let copied = try XCTUnwrap(m.activeSetlist?.songs.first)
        XCTAssertNotEqual(copied.id, original.id)
        XCTAssertEqual(copied.rhythm, original.rhythm.performanceCopy)
        XCTAssertNil(m.selectedSongID) // Importing never starts or selects a song.
        m.loadSong(copied)
        m.editSong(copied.id, name: "Warm-up", bpm: copied.rhythm.bpm)
        XCTAssertFalse(m.rhythm.ramp)
        XCTAssertFalse(m.rhythm.gap)
        XCTAssertEqual(m.rhythm.crossCount, 0)
        XCTAssertFalse(try XCTUnwrap(m.currentSong).rhythm.ramp)
        m.editSong(copied.id, name: "Opening", bpm: 140)
        XCTAssertFalse(m.rhythm.ramp)
        XCTAssertFalse(try XCTUnwrap(m.currentSong).rhythm.ramp)
        let currentQueue = m.activeSetlistID
        m.addPreset("Opening snapshot")
        XCTAssertEqual(m.activeSetlistID, currentQueue)
        XCTAssertEqual(m.selectedSongID, copied.id)
        XCTAssertEqual(m.presets.first?.rhythm, original.rhythm)
        m.presets.removeAll()
        let restored = MetronomeModel(); defer { restored.stop() }
        XCTAssertEqual(restored.currentSong?.name, "Opening")
        XCTAssertEqual(restored.currentSong?.rhythm.bpm, 140)
        XCTAssertEqual(restored.currentSong?.rhythm.silentBars, 2)
        XCTAssertTrue(restored.presets.isEmpty)
        m.deleteActiveSetlist()
        m.rhythm = original.rhythm; m.addPreset("Solo practice")
        XCTAssertTrue(m.setlists.isEmpty)
        XCTAssertEqual(m.presets.first?.rhythm, original.rhythm)
    }
}
