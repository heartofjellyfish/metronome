import AVFoundation
import SwiftUI
import os

// Each tap owns its analysis window. The real-time callback only copies the audio.
final class PitchInput {
    struct Observation {
        let hz: Double?
        let measuredFromDecay: Bool
        let level: Float?
        let time: TimeInterval
    }

    private let queue = DispatchQueue(label: "Tuner.pitch", qos: .userInitiated)
    private let available = DispatchSemaphore(value: 1)
    private let activeSegment = OSAllocatedUnfairLock<UUID?>(initialState: UUID())
    private var window: [Float] = []
    private var windowSegment: UUID?
    private let windowDuration: Double
    private let measuresLevel: Bool
    private let chromatic: Bool
    private let pluckedTargets: [Double]
    private var previousPluckLevel: Float = 0
    private var pluckAttackAt: TimeInterval?
    private var lastPluckEvidenceAt: TimeInterval?
    private var nextSample: AVAudioFramePosition?
    private var lastPitch: Double?
    private var chromaticPeak: (hz: Double, peak: Float, time: TimeInterval)?
    private var lastPitchAt: TimeInterval?
    private var framesUntilAnalysis = 0
    private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "TheMetronome", category: "Tuner")
    #if DEBUG
    private let traceInput = ProcessInfo.processInfo.arguments.contains("--tuner-trace-input")
    #endif

    init(windowDuration: Double, measuresLevel: Bool, chromatic: Bool, pluckedTargets: [Double] = []) {
        self.windowDuration = windowDuration
        self.measuresLevel = measuresLevel
        self.chromatic = chromatic
        self.pluckedTargets = pluckedTargets
    }

    func suspend() { activeSegment.withLock { $0 = nil } }
    func resume() { activeSegment.withLock { $0 = UUID() } }
    func accepts(_ segment: UUID) -> Bool { activeSegment.withLock { $0 == segment } }

    func consume(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime, receive: @escaping ([Observation], UUID) -> Void) {
        guard let snapshot = activeSegment.withLockIfAvailable({ $0 }), let segment = snapshot,
              let channel = buffer.floatChannelData?[0], buffer.frameLength > 0,
              available.wait(timeout: .now()) == .success else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let rate = buffer.format.sampleRate
        let sample = time.isSampleTimeValid ? time.sampleTime : nil
        let beganAt = time.isHostTimeValid ? AVAudioTime.seconds(forHostTime: time.hostTime)
            : ProcessInfo.processInfo.systemUptime - Double(samples.count) / rate
        queue.async { [self] in
            guard accepts(segment) else { available.signal(); return }
            #if DEBUG
            if traceInput {
                let gap = sample.flatMap { start in nextSample.map { start - $0 } } ?? 0
                print("TUNER_CAPTURE \(Date().timeIntervalSince1970) frames=\(samples.count) gap=\(gap) level=\(TunerPitch.tailLevel(samples, sampleRate: rate))")
            }
            #endif
            if windowSegment != segment || (sample != nil && nextSample != nil && sample != nextSample) {
                window.removeAll(keepingCapacity: true)
                chromaticPeak = nil
                lastPitch = nil
                lastPitchAt = nil
                previousPluckLevel = 0
                pluckAttackAt = nil
                lastPluckEvidenceAt = nil
                framesUntilAnalysis = 0
            }
            windowSegment = segment
            nextSample = sample.map { $0 + AVAudioFramePosition(samples.count) }
            let observations = analyze(samples, rate: rate, beganAt: beganAt)
            available.signal()
            if !observations.isEmpty { receive(observations, segment) }
        }
    }

    private func analyze(_ samples: [Float], rate: Double, beganAt: TimeInterval) -> [Observation] {
        if !chromatic {
            // Keep the instrument tuner at its existing delivery cadence.
            window.append(contentsOf: samples)
            let size = Int(rate * windowDuration)
            return measure(rate: rate, size: size, capacity: size, at: beganAt + Double(samples.count) / rate)
                .map { [$0] } ?? []
        }

        // The hardware tap can deliver about 100 ms of audio at once. Analyze
        // regular hops inside it so confirmation sees the actual sample times.
        let hop = Int(rate * 0.024)
        let capacity = Int(rate * TunerPitch.lowToneHistoryDuration)
        var observations: [Observation] = []
        var cursor = 0
        while cursor < samples.count {
            if framesUntilAnalysis == 0 { framesUntilAnalysis = hop }
            let count = min(framesUntilAnalysis, samples.count - cursor)
            window.append(contentsOf: samples[cursor..<(cursor + count)])
            cursor += count
            framesUntilAnalysis -= count
            if framesUntilAnalysis == 0 {
                let size = Int(rate * TunerPitch.chromaticWindowDuration(after: lastPitch))
                if let observation = measure(rate: rate, size: size, capacity: capacity,
                                             at: beganAt + Double(cursor) / rate) {
                    if let hz = observation.hz {
                        lastPitch = hz
                        lastPitchAt = observation.time
                    } else if lastPitchAt.map({ observation.time - $0 > 0.12 }) == true {
                        lastPitch = nil
                        lastPitchAt = nil
                    }
                    observations.append(observation)
                }
            }
        }
        return observations
    }

    private func measure(rate: Double, size: Int, capacity: Int, at time: TimeInterval) -> Observation? {
        guard window.count >= size else { return nil }
        if window.count > capacity { window.removeFirst(window.count - capacity) }
        let interval = signposter.beginInterval("Pitch analysis")
        let analyzed = window.count == size ? window : Array(window.suffix(size))
        var pitch = TunerPitch.detect(analyzed, sampleRate: rate, chromatic: chromatic)
        if chromatic, pitch == nil {
            pitch = TunerPitch.sustainedLowTone(window, sampleRate: rate, previous: lastPitch)
        }
        if chromatic, let lastPitch,
           let continuation = TunerPitch.continueChromaticPitch(near: lastPitch, proposed: pitch,
                                                                     samples: analyzed, sampleRate: rate) {
            pitch = continuation
        }
        var measuredFromDecay = false
        if chromatic {
            let level = TunerPitch.tailLevel(analyzed, sampleRate: rate)
            if let hz = pitch {
                var peak = level
                if let prior = chromaticPeak, time - prior.time < 0.24,
                   abs(1200 * log2(hz / prior.hz)) < 45 {
                    peak = max(level, prior.peak)
                }
                chromaticPeak = (hz, peak, time)
            } else if let attack = chromaticPeak, time - attack.time <= 0.24,
                      level < min(0.00075, attack.peak * 0.72) {
                // Measure independent partials again; the old pitch only sets the search region.
                pitch = TunerPitch.pluckedPitch(in: analyzed, sampleRate: rate,
                                                targets: [attack.hz], continuing: nil)
                measuredFromDecay = pitch != nil
            }
        }
        let level = measuresLevel ? TunerPitch.tailLevel(window, sampleRate: rate) : nil
        if !pluckedTargets.isEmpty, let level {
            if level > previousPluckLevel * 1.7, level - previousPluckLevel > 0.00024 {
                lastPitch = nil
                pluckAttackAt = time
            }
            previousPluckLevel = level
            if let hz = pitch, pluckedTargets.contains(where: { abs(1200 * log2(hz / $0)) <= 100 }) {
                lastPitch = hz
                lastPitchAt = time
                lastPluckEvidenceAt = time
            } else {
                let recentEvidence = lastPluckEvidenceAt.map { time - $0 <= 0.21 } == true
                let recentRoot = lastPitchAt.map { time - $0 < 0.95 } == true
                let prior = recentEvidence && recentRoot ? lastPitch : nil
                let attacking = pluckAttackAt.map { time - $0 < 0.32 } == true
                if prior != nil || attacking,
                   let measured = TunerPitch.pluckedPitch(in: analyzed, sampleRate: rate,
                                                          targets: pluckedTargets, continuing: prior) {
                    pitch = measured
                    lastPluckEvidenceAt = time
                    if prior == nil {
                        lastPitch = measured
                        lastPitchAt = time
                    }
                }
            }
        }
        signposter.endInterval("Pitch analysis", interval)
        return Observation(hz: pitch, measuredFromDecay: measuredFromDecay, level: level, time: time)
    }
}

// Render state is owned by the audio callback. Main-thread controls use a nonblocking read.
final class TunerToneSignal {
    private struct Output {
        var frequency: Double
        var gain: Double = 0.16
    }
    private let outputState: OSAllocatedUnfairLock<Output>
    private let radiansPerHz: Double
    private let smoothing: Double
    private var step: Double
    private var phase = 0.0
    private var gain = 0.0
    private var targetStep: Double
    private var targetGain: Double

    init(frequency hz: Double, sampleRate: Double, muted: Bool = false) {
        let output = Output(frequency: hz, gain: muted ? 0 : 0.16)
        outputState = OSAllocatedUnfairLock(initialState: output)
        radiansPerHz = 2 * Double.pi / sampleRate
        smoothing = 1 - exp(-1 / (sampleRate * 0.004))
        step = hz * radiansPerHz
        targetStep = step
        targetGain = output.gain
    }

    func retune(to hz: Double) {
        outputState.withLock { $0 = Output(frequency: hz) }
    }

    func fadeOut() { outputState.withLock { $0.gain = 0 } }

    func render(_ output: UnsafeMutableBufferPointer<Float>) {
        // A competing update can wait until the next buffer. The render callback never waits.
        if let state = outputState.withLockIfAvailable({ $0 }) {
            targetStep = state.frequency * radiansPerHz
            targetGain = state.gain
        }
        if targetGain == 0 && gain < 0.000001 {
            output.update(repeating: 0)
            gain = 0
            return
        }
        for index in output.indices {
            step += (targetStep - step) * smoothing
            gain += (targetGain - gain) * smoothing
            output[index] = Float(sin(phase) * gain)
            phase += step
            if phase >= 2 * .pi { phase -= 2 * .pi }
        }
    }
}

struct TunerReferenceTone: Equatable {
    let note: Int
    var wire: Int? = nil
    let sustained: Bool
}

@MainActor
final class TunerAudio: ObservableObject {
    enum Status { case idle, permission, listening, denied, unavailable, tone }
    @Published private(set) var status: Status = .idle
    @Published private(set) var reading: TunerReading?
    @Published private(set) var referenceTone: TunerReferenceTone?
    private var engine: AVAudioEngine?
    private var pitchInput: PitchInput?
    private var toneSignal: TunerToneSignal?
    private var referenceTask: Task<Void, Never>?
    private var generation = UUID()
    private var ownsSession = false
    private var tracker = TunerTracker()
    #if DEBUG
    private let tracePitch = ProcessInfo.processInfo.arguments.contains("--tuner-trace-pitch")
    private let traceInput = ProcessInfo.processInfo.arguments.contains("--tuner-trace-input")
    private let silentPreview = ProcessInfo.processInfo.arguments.contains("--tuner-test-silent")
    private let previewInput = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--tuner-test-input=") }
        .map { String($0.dropFirst("--tuner-test-input=".count)) }
    private let previewReplay = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--tuner-test-replay=") }
        .map { String($0.dropFirst("--tuner-test-replay=".count)) }
    private var previewSelections: [Int: Int] = [:]
    var playsReferenceInPreview: Bool {
        previewReplay == nil && (ProcessInfo.processInfo.arguments.contains("--tuner-test-reference")
            || !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--tuner-test-cents=") })
    }
    #endif
    var targets: [Int] = []
    var held: Int?
    var reference = 440
    var response = TunerResponse.balanced
    var tracksPlucks = false
    var isChromatic = false
    var chromaticRange = ChromaticTuningRange.standard

    func ownsGraph(_ object: Any?) -> Bool {
        guard let engine, let changedGraph = object as? AVAudioEngine else { return false }
        return engine === changedGraph
    }

    func clearReading(preservingEnvelope: Bool = false, waitsForStringAttack: Bool = false) {
        tracker.reset(preservingEnvelope: preservingEnvelope, waitsForStringAttack: waitsForStringAttack)
        reading = nil
    }
    func stop() {
        referenceTask?.cancel()
        referenceTask = nil
        referenceTone = nil
        generation = UUID()
        pitchInput?.suspend()
        if let engine {
            engine.stop()
            if pitchInput != nil { engine.inputNode.removeTap(onBus: 0) }
        }
        pitchInput = nil
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
                                 time: Double(step) * 0.1, response: response, chromatic: isChromatic,
                                 stabilizeChromaticPitch: isChromatic, chromaticRange: chromaticRange)
            }
            reading = tracker.read(hz: pitch, reference: reference, targets: targets, held: held,
                                   time: Double(sampleCount) * 0.1, response: response, chromatic: isChromatic,
                                   stabilizeChromaticPitch: isChromatic, chromaticRange: chromaticRange)
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
                let pluckedTargets = tracksPlucks ? Set(targets).map { TunerPitch.frequency($0, reference: reference) } : []
                let analysis = PitchInput(windowDuration: tracksBass ? 0.144 : 0.096,
                                          measuresLevel: !targets.isEmpty, chromatic: isChromatic,
                                          pluckedTargets: pluckedTargets)
                let sampleRate = format.sampleRate
                let receive: ([PitchInput.Observation], UUID) -> Void = { [weak self] observations, segment in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == ticket, analysis.accepts(segment) else { return }
                        var next: TunerReading?
                        for observation in observations {
                            next = self.tracker.read(hz: observation.hz, reference: self.reference, targets: self.targets,
                                held: self.held, time: observation.time, response: self.response,
                                pluckLevel: observation.level, guardsPluckHarmonics: self.tracksPlucks,
                                chromatic: self.isChromatic, stabilizeChromaticPitch: self.isChromatic,
                                chromaticRange: self.chromaticRange, measuredFromDecay: observation.measuredFromDecay)
                        }
                        #if DEBUG
                        if self.traceInput {
                            let summary = observations.map { "\($0.time):\($0.hz ?? 0)" }.joined(separator: ",")
                            print("TUNER_INPUT \(Date().timeIntervalSince1970) \(summary) state=\(String(describing: next?.state))")
                        }
                        if self.tracePitch, let hz = observations.last?.hz, let next,
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
                pitchInput = analysis
                if isChromatic {
                    let outputRate = graph.outputNode.outputFormat(forBus: 0).sampleRate
                    toneSignal = attachReference(to: graph, frequency: Double(reference), rate: outputRate, muted: true)
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
    func audition(_ tone: TunerReferenceTone) {
        if referenceTone == tone, !tone.sustained {
            finishReference()
            return
        }
        playReference(note: tone.note)
        guard status == .tone else {
            finishReference()
            return
        }
        referenceTask?.cancel()
        referenceTone = tone
        if !tone.sustained {
            referenceTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                self?.finishReference()
            }
        }
    }

    func finishReference() {
        referenceTask?.cancel()
        referenceTone = nil
        toneSignal?.fadeOut()
        referenceTask = Task { [weak self] in
            // Start a new input window after the output fade and speaker tail.
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            guard let self else { return }
            if let pitchInput = self.pitchInput {
                self.referenceTask = nil
                pitchInput.resume()
                self.status = .listening
            } else {
                self.listen()
            }
        }
    }

    private func playReference(note: Int) {
        let frequency = TunerPitch.frequency(note, reference: reference)
        if let toneSignal {
            if status == .listening {
                pitchInput?.suspend()
                clearReading()
                status = .tone
            }
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
            guard let signal = attachReference(to: graph, frequency: frequency, rate: session.sampleRate, muted: false) else {
                stop()
                status = .unavailable
                return
            }
            engine = graph
            try graph.start()
            toneSignal = signal
            status = .tone
        } catch { stop(); status = .unavailable }
    }

    private func attachReference(to graph: AVAudioEngine, frequency: Double, rate: Double, muted: Bool) -> TunerToneSignal? {
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return nil }
        let signal = TunerToneSignal(frequency: frequency, sampleRate: rate, muted: muted)
        let synth = AVAudioSourceNode(format: format) { _, _, frames, buffers in
            let audio = UnsafeMutableAudioBufferListPointer(buffers)
            guard let dest = audio.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            signal.render(UnsafeMutableBufferPointer(start: dest, count: Int(frames)))
            return noErr
        }
        graph.attach(synth)
        graph.connect(synth, to: graph.mainMixerNode, format: format)
        return signal
    }
}
