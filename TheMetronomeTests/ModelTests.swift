import XCTest
import AVFoundation
import MediaPlayer
@testable import TheMetronome

final class ModelTests: XCTestCase {
    @MainActor func testRuntimeStatePresetsMetadataAndInterruptions() async throws {
        let defaults = UserDefaults.standard
        let keys = ["rhythm", "presets", "selectedPresetID", "dark", "haptics"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        let model = MetronomeModel()
        defer { model.stop() }
        model.rhythm = Rhythm(); model.presets = []
        model.addPreset("  FIRST  ")
        model.setBPM(120); model.addPreset("SECOND")
        XCTAssertEqual(model.presetCaption, "PRESET 02 / SECOND")
        XCTAssertEqual(defaults.string(forKey: "selectedPresetID"), model.presets[1].id.uuidString)
        model.setBPM(121); XCTAssertEqual(model.presetCaption, "CUSTOM RHYTHM / SAVE")
        model.load(model.presets[1]); XCTAssertEqual(model.bpm, 120)
        XCTAssertEqual(model.presetCaption, "PRESET 02 / SECOND")
        model.presets.removeFirst(); XCTAssertEqual(model.presetCaption, "PRESET 01 / SECOND")
        model.presets = []; XCTAssertEqual(model.presetCaption, "PRESETS / SAVE A RHYTHM")
        model.addPreset("  \n "); XCTAssertTrue(model.presets.isEmpty)

        // A 1/4 ramp makes runtime and lock-screen metadata diverge quickly if stale.
        model.rhythm.beats = 1; model.rhythm.ramp = true
        model.rhythm.start = 240; model.rhythm.end = 250
        model.rhythm.every = 1; model.rhythm.increment = 5
        model.start(); XCTAssertTrue(model.playing); XCTAssertNil(model.error)
        try await Task.sleep(for: .milliseconds(900))
        model.refreshBeat()
        XCTAssertEqual(model.bpm, 250)
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "250 BPM · 1/4")
        XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
        model.setBPM(100)
        XCTAssertFalse(model.rhythm.ramp)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtist] as? String, "100 BPM · 1/4")
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(model.playing); XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        model.start(); XCTAssertTrue(model.playing)
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(model.playing)
        // These notifications test application handling, not actual phone hardware behavior.
        model.selectSound(11); XCTAssertFalse(model.playing); XCTAssertNil(model.error)
        model.endSoundPreview()
        model.start(); XCTAssertTrue(model.playing)
        model.load(SavedPreset(name: "LIVE", rhythm: Rhythm()))
        XCTAssertTrue(model.playing); XCTAssertEqual(model.bpm, 96)
    }
}
