import AVFoundation
import SwiftUI
import os

// Each tap has its own analysis window. Only one analysis task may be outstanding.
private final class PitchInput {
    private let queue = DispatchQueue(label: "Tuner.pitch", qos: .userInitiated)
    private let available = DispatchSemaphore(value: 1)
    private var window: [Float] = []
    private let windowDuration: Double
    private let measuresLevel: Bool
    private let chromatic: Bool
    private var nextSample: AVAudioFramePosition?
    private var lastPitch: Double?
    private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "TheMetronome", category: "Tuner")

    init(windowDuration: Double, measuresLevel: Bool, chromatic: Bool) {
        self.windowDuration = windowDuration
        self.measuresLevel = measuresLevel
        self.chromatic = chromatic
    }

    func consume(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime, receive: @escaping (Double?, Float?) -> Void) {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0,
              available.wait(timeout: .now()) == .success else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let rate = buffer.format.sampleRate
        let sample = time.isSampleTimeValid ? time.sampleTime : nil
        queue.async { [self] in
            defer { available.signal() }
            if let sample, let nextSample, sample != nextSample {
                window.removeAll(keepingCapacity: true)
                lastPitch = nil
            }
            nextSample = sample.map { $0 + AVAudioFramePosition(samples.count) }
            let duration = chromatic ? TunerPitch.chromaticWindowDuration(after: lastPitch) : windowDuration
            let size = Int(rate * duration)
            let capacity = Int(rate * (chromatic ? TunerPitch.chromaticWindowDuration(after: 0) : windowDuration))
            window.append(contentsOf: samples)
            guard window.count >= size else { return }
            if window.count > capacity { window.removeFirst(window.count - capacity) }
            let interval = signposter.beginInterval("Pitch analysis")
            let analyzed = window.count == size ? window : Array(window.suffix(size))
            let pitch = TunerPitch.detect(analyzed, sampleRate: rate)
            if chromatic { lastPitch = pitch }
            let level = measuresLevel ? TunerPitch.tailLevel(window, sampleRate: rate) : nil
            signposter.endInterval("Pitch analysis", interval)
            receive(pitch, level)
        }
    }
}

// Render state is owned by the audio callback. The main thread only writes the next frequency.
final class TunerToneSignal {
    private let frequency: OSAllocatedUnfairLock<Double>
    private let radiansPerHz: Double
    private let smoothing: Double
    private var step: Double
    private var phase = 0.0
    private var gain = 0.0

    init(frequency hz: Double, sampleRate: Double) {
        frequency = OSAllocatedUnfairLock(initialState: hz)
        radiansPerHz = 2 * Double.pi / sampleRate
        smoothing = 1 - exp(-1 / (sampleRate * 0.004))
        step = hz * radiansPerHz
    }

    func retune(to hz: Double) { frequency.withLock { $0 = hz } }

    func render(_ output: UnsafeMutableBufferPointer<Float>) {
        // A competing update can wait until the next buffer. The render callback never waits.
        let targetStep = frequency.withLockIfAvailable { $0 }.map { $0 * radiansPerHz } ?? step
        for index in output.indices {
            step += (targetStep - step) * smoothing
            gain += (0.16 - gain) * smoothing
            output[index] = Float(sin(phase) * gain)
            phase += step
            if phase >= 2 * .pi { phase -= 2 * .pi }
        }
    }
}

@MainActor
final class TunerAudio: ObservableObject {
    enum Status { case idle, permission, listening, denied, unavailable, tone }
    @Published private(set) var status: Status = .idle
    @Published private(set) var reading: TunerReading?
    private var engine: AVAudioEngine?
    private var toneSignal: TunerToneSignal?
    private var generation = UUID()
    private var ownsSession = false
    private var tracker = TunerTracker()
    #if DEBUG
    private let tracePitch = ProcessInfo.processInfo.arguments.contains("--tuner-trace-pitch")
    private let silentPreview = ProcessInfo.processInfo.arguments.contains("--tuner-test-silent")
    private let previewInput = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--tuner-test-input=") }
        .map { String($0.dropFirst("--tuner-test-input=".count)) }
    private let previewReplay = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--tuner-test-replay=") }
        .map { String($0.dropFirst("--tuner-test-replay=".count)) }
    private var previewSelections: [Int: Int] = [:]
    #endif
    var targets: [Int] = []
    var held: Int?
    var reference = 440
    var response = TunerResponse.balanced
    var tracksPlucks = false
    var isChromatic = false

    func ownsGraph(_ object: Any?) -> Bool {
        guard let engine, let changedGraph = object as? AVAudioEngine else { return false }
        return engine === changedGraph
    }

    func clearReading(preservingEnvelope: Bool = false) {
        tracker.reset(preservingEnvelope: preservingEnvelope)
        reading = nil
    }
    func stop() {
        generation = UUID()
        if let engine {
            engine.stop()
            if status == .listening { engine.inputNode.removeTap(onBus: 0) }
        }
        engine = nil
        toneSignal = nil
        if ownsSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsSession = false
        }
        clearReading()
        status = .idle
    }
    #if DEBUG
    func previewReading() -> Bool {
        if let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--tuner-test-cents=") }),
           let cents = Double(flag.dropFirst("--tuner-test-cents=".count)) {
            status = .listening
            if let previewReplay, let held {
                previewSelections[held, default: 0] += 1
                if previewSelections[held] == 2 {
                    previewSecondAttack(note: held, scenario: previewReplay)
                    return true
                }
            }
            let pitch = TunerPitch.frequency(held ?? targets.first ?? 69, reference: reference) * pow(2, cents/1200)
            let sustainPrefix = "--tuner-test-sustain="
            let sustain = ProcessInfo.processInfo.arguments.first { $0.hasPrefix(sustainPrefix) }
                .flatMap { Double($0.dropFirst(sustainPrefix.count)) }
            let sampleCount = 3 + Int(min(5, max(0, sustain ?? 0)) * 10)
            for step in 0..<sampleCount {
                _ = tracker.read(hz: pitch, reference: reference, targets: targets, held: held,
                                 time: Double(step) * 0.1, response: response, chromatic: isChromatic)
            }
            reading = tracker.read(hz: pitch, reference: reference, targets: targets, held: held,
                                   time: Double(sampleCount) * 0.1, response: response, chromatic: isChromatic)
            return true
        }
        return false
    }

    private func previewSecondAttack(note: Int, scenario: String) {
        for frame in 0..<25 {
            let cents: Double
            let level: Float
            switch scenario {
            case "tail":
                cents = frame < 12 ? 0 : -20
                level = 0.05 * exp(-Float(frame) / 11)
            case "jitter":
                cents = frame < 6 ? (frame.isMultiple(of: 2) ? 15 : -15) : 0
                level = 0.04
            default:
                cents = scenario == "flat" ? -18 : 18
                level = 0.04
            }
            let hz = TunerPitch.frequency(note, reference: reference) * pow(2, cents / 1200)
            reading = tracker.read(hz: hz, reference: reference, targets: targets, held: note,
                                   time: Double(frame) * 0.024, response: response, pluckLevel: level,
                                   guardsPluckHarmonics: tracksPlucks)
        }
    }
    #endif
    func listen() {
        stop()
        let ticket = generation
        #if DEBUG
        if previewInput == "denied" { status = .denied; return }
        if previewInput == "unavailable" { status = .unavailable; return }
        if previewInput == "waiting" { status = .permission; return }
        if previewReading() { return }
        if silentPreview { status = .listening; return }
        #endif
        let permission = AVAudioApplication.shared.recordPermission
        if permission == .denied { status = .denied; return }
        if permission == .undetermined { status = .permission }
        Task {
            let allowed = permission == .granted ? true : await AVAudioApplication.requestRecordPermission()
            guard generation == ticket else { return }
            guard allowed else { status = .denied; return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
                try session.setActive(true)
                ownsSession = true
                guard session.isInputAvailable, !session.currentRoute.inputs.isEmpty else {
                    stop()
                    status = .unavailable
                    return
                }
                let graph = AVAudioEngine()
                let input = graph.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0 && format.channelCount > 0 else { stop(); status = .unavailable; return }
                // More periods per observation reduce bass and cello flutter on acoustic input.
                let tracksBass = (held ?? .max) <= 36 || targets.contains { $0 <= 36 }
                let analysis = PitchInput(windowDuration: tracksBass ? 0.144 : 0.096,
                                          measuresLevel: !targets.isEmpty, chromatic: isChromatic)
                let sampleRate = format.sampleRate
                let receive: (Double?, Float?) -> Void = { [weak self] hz, level in
                    Task { @MainActor in
                        guard let self, self.generation == ticket else { return }
                        let now = ProcessInfo.processInfo.systemUptime
                        let next = self.tracker.read(hz: hz, reference: self.reference, targets: self.targets,
                                                     held: self.held, time: now, response: self.response,
                                                     pluckLevel: level, guardsPluckHarmonics: self.tracksPlucks,
                                                     chromatic: self.isChromatic)
                        #if DEBUG
                        if self.tracePitch, let hz, let next,
                           self.reading?.note != next.note || self.reading?.state != next.state {
                            print("TUNER \(Date().timeIntervalSince1970) \(sampleRate) \(hz) \(next.note) \(next.cents) \(next.state)")
                        }
                        #endif
                        self.reading = next
                    }
                }
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, timestamp in
                    analysis.consume(buffer, at: timestamp, receive: receive)
                }
                engine = graph
                status = .listening
                try graph.start()
            } catch {
                stop()
                status = .unavailable
            }
        }
    }
    func tone(note: Int) {
        let frequency = TunerPitch.frequency(note, reference: reference)
        if status == .tone, let toneSignal {
            toneSignal.retune(to: frequency)
            return
        }
        #if DEBUG
        if silentPreview, status == .tone { return }
        #endif
        stop()
        #if DEBUG
        if silentPreview { status = .tone; return }
        #endif
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            ownsSession = true
            let graph = AVAudioEngine()
            let rate = session.sampleRate
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { stop(); status = .unavailable; return }
            let signal = TunerToneSignal(frequency: frequency, sampleRate: rate)
            let synth = AVAudioSourceNode(format: format) { _, _, frames, buffers in
                let audio = UnsafeMutableAudioBufferListPointer(buffers)
                guard let dest = audio.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                signal.render(UnsafeMutableBufferPointer(start: dest, count: Int(frames)))
                return noErr
            }
            graph.attach(synth)
            graph.connect(synth, to: graph.mainMixerNode, format: format)
            engine = graph
            try graph.start()
            toneSignal = signal
            status = .tone
        } catch { stop(); status = .unavailable }
    }
}
