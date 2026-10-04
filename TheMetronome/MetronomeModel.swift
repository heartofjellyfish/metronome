import SwiftUI
import AVFoundation
import MediaPlayer

/// Main thread writes parameters; render thread only tries the lock once per buffer.
/// No waiting, allocations, dispatches or UI work in the audio rendering loop.
final class AudioMailbox {
    let lock = NSLock()
    var config = Rhythm()
    var event: ClockEvent?
    var serial = 0
    func set(_ value: Rhythm) { lock.lock(); config = value; lock.unlock() }
}

final class MetronomeAudio {
    let engine = AVAudioEngine()
    let mailbox = AudioMailbox()
    private var source: AVAudioSourceNode?
    private var acousticLibrary: AcousticLibrary?
    func start(_ rhythm: Rhythm) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        let rate = session.sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        if acousticLibrary == nil { acousticLibrary = try AcousticLibrary.bundled() }
        let acoustic = AcousticRenderer(library: acousticLibrary!)
        let clock = SampleClock(rate: rate); clock.reset(rhythm)
        mailbox.set(rhythm)
        var voices = (ClickVoice(), ClickVoice(), ClickVoice(), ClickVoice())
        var voiceIndex = 0
        var latest: ClockEvent?
        var serial = 0
        let box = mailbox
        let node = AVAudioSourceNode(format: format) { _, _, count, buffers in
            if box.lock.try() { clock.update(box.config); box.lock.unlock() }
            let audioBuffers = UnsafeMutableAudioBufferListPointer(buffers)
            for frame in 0..<Int(count) {
                if let (event, strength) = clock.advance() {
                    latest = event; serial += 1
                    if strength > 0 {
                        voices.0.chokeHat(); voices.1.chokeHat(); voices.2.chokeHat(); voices.3.chokeHat()
                        acoustic.chokeHats()
                        if clock.rhythm.sound != 1 {
                            acoustic.trigger(sound: clock.rhythm.sound, strength: strength, beat: event.beat, beats: clock.rhythm.pulseCount, denominator: clock.rhythm.usesCompoundPulse ? 4 : clock.rhythm.denominator, counting: event.countIn)
                        } else { switch voiceIndex % 4 {
                        case 0: voices.0.trigger(sound: clock.rhythm.sound, strength: strength)
                        case 1: voices.1.trigger(sound: clock.rhythm.sound, strength: strength)
                        case 2: voices.2.trigger(sound: clock.rhythm.sound, strength: strength)
                        default: voices.3.trigger(sound: clock.rhythm.sound, strength: strength)
                        }
                        }
                        voiceIndex += 1
                    }
                }
                let sample = voices.0.sample(rate: rate) + voices.1.sample(rate: rate) + voices.2.sample(rate: rate) + voices.3.sample(rate: rate) + acoustic.sample(rate: rate)
                for buffer in audioBuffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample }
            }
            if box.lock.try() { box.event = latest; box.serial = serial; box.lock.unlock() }
            return noErr
        }
        source = node; engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare(); try engine.start()
    }
    func stop() {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        mailbox.lock.lock(); mailbox.event = nil; mailbox.serial = 0; mailbox.lock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct SavedPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var rhythm: Rhythm
}

@MainActor
final class MetronomeModel: ObservableObject {
    @Published var rhythm: Rhythm { didSet { audio.mailbox.set(rhythm); save(); if playing { updateNowPlaying() } } }
    @Published var dark: Bool { didSet { UserDefaults.standard.set(dark, forKey: "dark") } }
    @Published var haptics = true { didSet { UserDefaults.standard.set(haptics, forKey: "haptics") } }
    @Published private(set) var playing = false
    @Published private(set) var event: ClockEvent?
    @Published var error: String?
    @Published var presets: [SavedPreset] { didSet { save() } }
    @Published var presetName = "DAILY PRACTICE"
    @Published var tapCount = 0
    private let audio = MetronomeAudio()
    private var displayTimer: Timer?
    private var taps: [TimeInterval] = []
    private var observers: [NSObjectProtocol] = []
    private var lastSerial = 0
    private var previewTimer: Timer?
    private let feedback = UISelectionFeedbackGenerator()

    init() {
        let defaults = UserDefaults.standard
        var stored = defaults.data(forKey: "rhythm").flatMap { try? JSONDecoder().decode(Rhythm.self, from: $0) } ?? Rhythm()
        stored.sanitize(); rhythm = stored
        dark = defaults.bool(forKey: "dark")
        presets = defaults.data(forKey: "presets").flatMap { try? JSONDecoder().decode([SavedPreset].self, from: $0) } ?? []
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        // Deterministic launch states for simulator visual verification only.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reference") { rhythm = Rhythm() }
        if ProcessInfo.processInfo.arguments.contains("--dark") { dark = true }
        if ProcessInfo.processInfo.arguments.contains("--light") { dark = false }
        #endif
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.stop() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor in self?.stop() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audio.engine, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playing else { return }
                self.stop(); self.error = "Audio output changed. Press play to continue."
            }
        })
        MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.start() }; return .success }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.stop() }; return .success }
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
    }
    var bpm: Int { playing && rhythm.ramp ? event?.bpm ?? rhythm.start : rhythm.bpm }
    var marking: String {
        switch bpm { case ..<40: return "GRAVE"; case ..<60: return "LARGO"; case ..<76: return "ADAGIO"; case ..<108: return "ANDANTE"; case ..<120: return "MODERATO"; case ..<168: return "ALLEGRO"; case ..<200: return "VIVACE"; default: return "PRESTO" }
    }
    func setBPM(_ bpm: Int) {
        let value = min(300, max(20, bpm))
        // A manual tempo change takes over from automation, so display and sound agree.
        if rhythm.ramp { rhythm.ramp = false }
        guard value != rhythm.bpm else { return }
        rhythm.bpm = value; tickFeedback()
    }
    func tickFeedback() { if haptics { feedback.selectionChanged() } }
    func toggle() { playing ? stop() : start() }
    func start() {
        guard !playing else { return }
        previewTimer?.invalidate()
        do {
            try audio.start(rhythm); playing = true; lastSerial = 0; event = nil
            UIApplication.shared.isIdleTimerDisabled = true
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshBeat() }
            }
            if let displayTimer { RunLoop.main.add(displayTimer, forMode: .common) }
            updateNowPlaying()
        } catch { audio.stop(); self.error = error.localizedDescription }
    }
    func stop() {
        playing = false; displayTimer?.invalidate(); displayTimer = nil
        previewTimer?.invalidate(); audio.stop(); event = nil
        UIApplication.shared.isIdleTimerDisabled = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    func refreshBeat() {
        let box = audio.mailbox
        box.lock.lock(); let e = box.event; let serial = box.serial; box.lock.unlock()
        guard serial != lastSerial else { return }
        lastSerial = serial; event = e
    }
    func tap() {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = taps.last, now - last > 2.5 { taps.removeAll() }
        taps.append(now); taps = Array(taps.suffix(6)); tapCount = taps.count
        if taps.count >= 2 {
            let intervals = zip(taps.dropFirst(), taps).map(-)
            let sorted = intervals.sorted(); let median = sorted[sorted.count / 2]
            let valid = intervals.filter { abs($0 - median) < median * 0.3 }
            if !valid.isEmpty { setBPM(Int((60 / (valid.reduce(0, +) / Double(valid.count))).rounded())) }
        }
        tickFeedback()
    }
    func cycleAccent(_ index: Int) { rhythm.accents[index] = (rhythm.displayedAccent(index) + 1) % 3; tickFeedback() }
    func endSoundPreview() {
        previewTimer?.invalidate()
        if !playing { audio.stop() }
    }
    func setDynamics(_ followsMeter: Bool) {
        rhythm.followsMeter = followsMeter
        selectSound(rhythm.sound)
    }
    func selectSound(_ sound: Int) {
        rhythm.sound = sound; tickFeedback()
        guard !playing else { return }
        previewTimer?.invalidate()
        var preview = rhythm; preview.bpm = min(160, max(80, rhythm.bpm))
        preview.countIn = 0; preview.ramp = false; preview.gap = false
        let duration = Double(preview.pulseCount * preview.subdivision - 1) * 60 / Double(preview.bpm * preview.subdivision) + 0.18
        do {
            try audio.start(preview)
            previewTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in if self?.playing == false { self?.audio.stop() } }
            }
        } catch { self.error = error.localizedDescription }
    }
    func addPreset(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        presets.append(SavedPreset(name: clean.uppercased(), rhythm: rhythm)); presetName = clean.uppercased()
    }
    func load(_ preset: SavedPreset) {
        let resume = playing; stop()
        var value = preset.rhythm; value.sanitize(); rhythm = value; presetName = preset.name
        if resume { start() }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(rhythm) { UserDefaults.standard.set(data, forKey: "rhythm") }
        if let data = try? JSONEncoder().encode(presets) { UserDefaults.standard.set(data, forKey: "presets") }
    }
    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: "The Metronome", MPMediaItemPropertyArtist: "\(rhythm.bpm) BPM · \(rhythm.beats)/\(rhythm.denominator)", MPNowPlayingInfoPropertyIsLiveStream: true, MPNowPlayingInfoPropertyPlaybackRate: 1.0]
    }
}
