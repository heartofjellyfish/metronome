import XCTest
import AVFoundation
@testable import TheMetronome

final class LiveModeTests: XCTestCase {
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
        let keys = ["rhythm", "presets", "selectedPresetID", "pedalBindings"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        let model = MetronomeModel(); defer { model.stop() }
        model.presets = []; model.rhythm = Rhythm(); model.addPreset("ONE")
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
