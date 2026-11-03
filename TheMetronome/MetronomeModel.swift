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
    private var timeline: AudioTimeline?
    private var suspended: AudioTimeline?
    private final class AudioTimeline {
        let clock: SampleClock
        var renderedThrough = ProcessInfo.processInfo.systemUptime
        var rendered = false
        init(_ clock: SampleClock) { self.clock = clock }
    }
    func suspend() {
        engine.stop() // The render callback has finished before copying its clock.
        if let timeline, timeline.rendered {
            let saved = AudioTimeline(timeline.clock.copy(atRate: timeline.clock.rate))
            saved.renderedThrough = timeline.renderedThrough; saved.rendered = true; suspended = saved
        }
        stop(deactivate: false, discardTimeline: false)
    }
    func discardSuspension() { suspended = nil }

    func start(_ rhythm: Rhythm, previewBars: Int? = nil, resuming: Bool = false, exclusive: Bool = false) throws {
        let saved = resuming ? suspended : nil
        stop(deactivate: false)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: exclusive ? [] : [.mixWithOthers])
        try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        let rate = session.sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        if acousticLibrary == nil { acousticLibrary = try AcousticLibrary.bundled() }
        let acoustic = AcousticRenderer(library: acousticLibrary!, takeSeed: UInt64.random(in: .min ... .max))
        let clock = saved?.clock.copy(atRate: rate) ?? SampleClock(rate: rate)
        var resumeReference: TimeInterval?
        if let saved {
            let now = ProcessInfo.processInfo.systemUptime
            // Catch up a long interruption off the realtime thread. The first callback
            // only aligns the short graph-start interval using the render host timestamp.
            clock.skip(seconds: max(0, now - saved.renderedThrough))
            resumeReference = now; clock.update(rhythm)
        } else { clock.reset(rhythm, barLimit: previewBars) }
        let timeline = AudioTimeline(clock); self.timeline = timeline
        var alignOnFirstRender = saved != nil
        mailbox.set(rhythm)
        var voices = (ClickVoice(), ClickVoice(), ClickVoice(), ClickVoice())
        var voiceIndex = 0
        var latest: ClockEvent?
        var serial = 0
        let box = mailbox
        let node = AVAudioSourceNode(format: format) { _, timestamp, count, buffers in
            let hostTime = timestamp.pointee.mHostTime
            let bufferStart = hostTime == 0 ? ProcessInfo.processInfo.systemUptime : AVAudioTime.seconds(forHostTime: hostTime)
            if alignOnFirstRender, let resumeReference {
                clock.skip(seconds: max(0, bufferStart - resumeReference))
                alignOnFirstRender = false
            }
            if box.lock.try() { clock.update(box.config); box.lock.unlock() }
            let audioBuffers = UnsafeMutableAudioBufferListPointer(buffers)
            for frame in 0..<Int(count) {
                if let (event, strength) = clock.advance() {
                    latest = event; serial += 1
                    if strength > 0 {
                        voices.0.chokeHat(); voices.1.chokeHat(); voices.2.chokeHat(); voices.3.chokeHat()
                        acoustic.chokeHats()
                        if clock.rhythm.sound != 1 {
                            acoustic.trigger(sound: clock.rhythm.sound, strength: strength, beat: event.beat, beats: clock.rhythm.pulseCount, denominator: clock.rhythm.usesCompoundPulse ? 4 : clock.rhythm.denominator, counting: event.countIn, gainScale: event.gainScale, hitInterval: event.hitInterval)
                        } else { switch voiceIndex % 4 {
                        case 0: voices.0.trigger(sound: clock.rhythm.sound, strength: strength, gainScale: event.gainScale)
                        case 1: voices.1.trigger(sound: clock.rhythm.sound, strength: strength, gainScale: event.gainScale)
                        case 2: voices.2.trigger(sound: clock.rhythm.sound, strength: strength, gainScale: event.gainScale)
                        default: voices.3.trigger(sound: clock.rhythm.sound, strength: strength, gainScale: event.gainScale)
                        }
                        }
                        voiceIndex += 1
                    }
                }
                let sample = voices.0.sample(rate: rate) + voices.1.sample(rate: rate) + voices.2.sample(rate: rate) + voices.3.sample(rate: rate) + acoustic.sample(rate: rate)
                for buffer in audioBuffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample }
            }
            timeline.renderedThrough = bufferStart + Double(count) / rate
            timeline.rendered = true
            if box.lock.try() { box.event = latest; box.serial = serial; box.lock.unlock() }
            return noErr
        }
        source = node; engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare(); try engine.start()
    }
    func stop(deactivate: Bool = true, discardTimeline: Bool = true) {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        mailbox.lock.lock(); mailbox.event = nil; mailbox.serial = 0; mailbox.lock.unlock()
        timeline = nil
        if discardTimeline { suspended = nil }
        if deactivate { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
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
    @Published private(set) var interrupted = false
    let pedal = PedalControl()
    private var resumeAfterInterruption = false
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    @Published private(set) var event: ClockEvent?
    @Published var error: String?
    @Published var presets: [SavedPreset] { didSet { save() } }
    @Published private var selectedPresetID: UUID? {
        didSet { UserDefaults.standard.set(selectedPresetID?.uuidString, forKey: "selectedPresetID") }
    }
    var presetCaption: String {
        guard let index = presets.firstIndex(where: { $0.id == selectedPresetID }) else { return L10n.text("PRESETS / SAVE A RHYTHM") }
        var saved = presets[index].rhythm; saved.sanitize()
        guard saved == rhythm else { return L10n.text("CUSTOM RHYTHM / SAVE") }
        return L10n.format("PRESET %02d / %@", index + 1, presets[index].name)
    }
    func isCurrentPreset(_ preset: SavedPreset) -> Bool {
        var saved = preset.rhythm; saved.sanitize()
        return preset.id == selectedPresetID && saved == rhythm
    }
    @Published var tapCount = 0
    private var audio = MetronomeAudio()
    private var displayTimer: Timer?
    private var tapTempo = TapTempo()
    private var observers: [NSObjectProtocol] = []
    private var lastSerial = 0
    private var previewTimer: Timer?
    private let feedback = UISelectionFeedbackGenerator()
    private let tempoDetent = UIImpactFeedbackGenerator(style: .light)

    init() {
        let defaults = UserDefaults.standard
        var stored = defaults.data(forKey: "rhythm").flatMap { try? JSONDecoder().decode(Rhythm.self, from: $0) } ?? Rhythm()
        stored.sanitize(); rhythm = stored
        dark = defaults.bool(forKey: "dark")
        presets = defaults.data(forKey: "presets").flatMap { try? JSONDecoder().decode([SavedPreset].self, from: $0) } ?? []
        selectedPresetID = defaults.string(forKey: "selectedPresetID").flatMap(UUID.init(uuidString:))
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        // Deterministic launch states for simulator visual verification only.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reference") { rhythm = Rhythm() }
        if ProcessInfo.processInfo.arguments.contains("--dark") { dark = true }
        if ProcessInfo.processInfo.arguments.contains("--light") { dark = false }
        #endif
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in self?.handleInterruption(type: type, options: options) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor in self?.stop() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playing, !self.interrupted, !self.audio.engine.isRunning else { return }
                self.stop(); self.error = L10n.text("Audio output changed. Press play to continue.")
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.stop(); self.audio = MetronomeAudio()
                self.error = L10n.text("Audio output changed. Press play to continue.")
            }
        })
        pedal.perform = { [weak self] action in self?.performPedal(action) }
        let center = MPRemoteCommandCenter.shared()
        register(center.playCommand, code: 0, label: "PLAY / PAUSE", explicitPlaying: true) { $0.start() }
        register(center.pauseCommand, code: 0, label: "PLAY / PAUSE", explicitPlaying: false) { $0.stop() }
        register(center.togglePlayPauseCommand, code: 0, label: "PLAY / PAUSE") { $0.toggle() }
        register(center.stopCommand, code: 1, label: "STOP") { $0.stop() }
        register(center.nextTrackCommand, code: 2, label: "NEXT") { $0.performPedal(.next) }
        register(center.previousTrackCommand, code: 3, label: "PREVIOUS") { $0.performPedal(.previous) }
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for (command, token) in remoteTargets { command.removeTarget(token) }
    }
    private func register(_ command: MPRemoteCommand, code: Int, label: String, explicitPlaying: Bool? = nil, fallback: @escaping @MainActor (MetronomeModel) -> Void) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleMediaCommand(code: code, label: label, explicitPlaying: explicitPlaying) { fallback(self) }
            }
            return .success
        }
        remoteTargets.append((command, token))
    }
    func handleMediaCommand(code: Int, label: String, explicitPlaying: Bool?, fallback: () -> Void) {
        // An explicit system Pause must never start an already stopped player,
        // even when the physical pedal's media button was learned as a toggle.
        if let explicitPlaying, pedal.learning == nil,
           let binding = pedal.bindings[.toggle], binding.kind == .media, binding.code == code,
           transportActive == explicitPlaying { return }
        if !pedal.media(code, label: label) { fallback() }
    }
    func beginPedalLearning(_ action: PedalAction) {
        guard !interrupted else { return }
        do {
            // Becoming the primary player allows iOS media buttons to reach us while learning.
            // No silent keep-alive audio and no first-screen audio work.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
            try session.setActive(true)
            updateNowPlaying()
            pedal.learn(action)
        } catch { self.error = error.localizedDescription }
    }
    func performPedal(_ action: PedalAction) {
        switch action {
        case .toggle: toggle()
        case .tap: tap()
        case .faster: setBPM(bpm + 1)
        case .slower: setBPM(bpm - 1)
        case .next, .previous:
            guard !presets.isEmpty else { return }
            let index = presets.firstIndex { $0.id == selectedPresetID }
            let next = index.map { $0 + (action == .next ? 1 : -1) } ?? (action == .next ? 0 : presets.count - 1)
            guard presets.indices.contains(next) else { return } // No surprise wrap to the first song.
            load(presets[next])
        }
    }
    func handleInterruption(type: UInt?, options: UInt) {
        if type == AVAudioSession.InterruptionType.began.rawValue {
            guard !interrupted else { return }
            interrupted = true; resumeAfterInterruption = playing
            audio.suspend(); playing = false
            displayTimer?.invalidate(); displayTimer = nil; previewTimer?.invalidate()
            UIApplication.shared.isIdleTimerDisabled = false
            updateNowPlaying()
        } else if type == AVAudioSession.InterruptionType.ended.rawValue {
            guard interrupted else { return }
            interrupted = false
            let resume = resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            resumeAfterInterruption = false
            if resume { start(resuming: true) } else { audio.discardSuspension(); updateNowPlaying() }
        }
    }

    var bpm: Int { playing && rhythm.ramp ? event?.bpm ?? rhythm.start : rhythm.bpm }
    var marking: String {
        switch bpm { case ..<40: return "GRAVE"; case ..<60: return "LARGO"; case ..<76: return "ADAGIO"; case ..<108: return "ANDANTE"; case ..<120: return "MODERATO"; case ..<168: return "ALLEGRO"; case ..<200: return "VIVACE"; default: return "PRESTO" }
    }
    func setBPM(_ bpm: Int, rotary: Bool = false) {
        let value = min(300, max(20, bpm))
        // A manual tempo change takes over from automation, so display and sound agree.
        if rhythm.ramp { rhythm.ramp = false }
        guard value != rhythm.bpm else { return }
        let previous = rhythm.bpm
        rhythm.bpm = value
        // Mark a ten-BPM boundary once, including one crossed between drag events.
        // Leaving a marked value must not immediately create a second detent.
        let crossedTen = value > previous ? value / 10 > previous / 10 : (value + 9) / 10 < (previous + 9) / 10
        if rotary && haptics && crossedTen {
            tempoDetent.impactOccurred(intensity: 0.55)
            tempoDetent.prepare()
        } else { tickFeedback() }
    }
    func prepareTempoFeedback() {
        guard haptics else { return }
        feedback.prepare(); tempoDetent.prepare()
    }
    func tickFeedback() { if haptics { feedback.selectionChanged() } }
    var transportActive: Bool { playing || resumeAfterInterruption }
    func toggle() { (playing || resumeAfterInterruption) ? stop() : start() }
    func start(resuming: Bool = false) {
        guard !playing, !interrupted else { return }
        previewTimer?.invalidate()
        do {
            try audio.start(rhythm, resuming: resuming, exclusive: !pedal.bindings.isEmpty); playing = true; lastSerial = 0; event = nil
            UIApplication.shared.isIdleTimerDisabled = true
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshBeat() }
            }
            if let displayTimer { RunLoop.main.add(displayTimer, forMode: .common) }
            updateNowPlaying()
        } catch { audio.stop(); self.error = error.localizedDescription }
    }
    func stop() {
        resumeAfterInterruption = false
        playing = false; displayTimer?.invalidate(); displayTimer = nil
        previewTimer?.invalidate(); audio.stop(); event = nil
        UIApplication.shared.isIdleTimerDisabled = false
        updateNowPlaying()
    }
    func refreshBeat() {
        let box = audio.mailbox
        box.lock.lock(); let e = box.event; let serial = box.serial; box.lock.unlock()
        guard serial != lastSerial else { return }
        let tempoChanged = event?.bpm != e?.bpm
        lastSerial = serial; event = e
        if playing && tempoChanged { updateNowPlaying() }
    }
    func tap() {
        if let bpm = tapTempo.record(at: ProcessInfo.processInfo.systemUptime) { setBPM(bpm) }
        tapCount = tapTempo.count
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
        let duration = Double(preview.pulseCount) * 60 / Double(preview.bpm) + 0.8
        do {
            try audio.start(preview, previewBars: 1)
            previewTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in if self?.playing == false { self?.audio.stop() } }
            }
        } catch { audio.stop(); self.error = error.localizedDescription }
    }
    func addPreset(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let preset = SavedPreset(name: clean.uppercased(), rhythm: rhythm)
        presets.append(preset); selectedPresetID = preset.id
    }
    func load(_ preset: SavedPreset) {
        let resume = playing; stop()
        var value = preset.rhythm; value.sanitize(); rhythm = value; selectedPresetID = preset.id
        if resume { start() }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(rhythm) { UserDefaults.standard.set(data, forKey: "rhythm") }
        if let data = try? JSONEncoder().encode(presets) { UserDefaults.standard.set(data, forKey: "presets") }
    }
    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: presets.first(where: { $0.id == selectedPresetID })?.name ?? "metronome, just cleaner", MPMediaItemPropertyArtist: "\(bpm) BPM · \(rhythm.beats)/\(rhythm.denominator)", MPNowPlayingInfoPropertyIsLiveStream: true, MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0]
    }
}
