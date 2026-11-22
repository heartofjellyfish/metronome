import Foundation
import Accelerate

struct TunerPitchNotation {
    let writtenOffset: Int
    let prefersWritten: Bool

    var hasTransposition: Bool { writtenOffset != 0 }
    var primaryOffset: Int { prefersWritten ? writtenOffset : 0 }
    var secondaryOffset: Int { prefersWritten ? 0 : writtenOffset }
    var primaryTitle: String { prefersWritten ? "Written pitch" : "Concert pitch" }
    var secondaryTitle: String { prefersWritten ? "Concert pitch" : "Written pitch" }
}

enum TunerPitch {
    static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private static let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static func name(_ note: Int) -> String { name(note, flats: false) }
    static func name(_ note: Int, flats: Bool) -> String {
        (flats ? flatNames : names)[(note % 12 + 12) % 12]
    }
    static func octave(_ note: Int) -> Int { Int(floor(Double(note) / 12)) - 1 }
    static func label(_ note: Int) -> String { label(note, flats: false) }
    static func label(_ note: Int, flats: Bool) -> String { name(note, flats: flats) + String(octave(note)) }
    static func frequency(_ note: Int, reference: Int) -> Double {
        Double(reference) * pow(2, Double(note - 69) / 12)
    }
    static func fractionalNote(_ hz: Double, reference: Int) -> Double {
        69 + 12 * log2(hz / Double(reference))
    }

    static func tailLevel(_ samples: [Float], sampleRate: Double) -> Float {
        let count = min(samples.count, Int(sampleRate * 0.044))
        guard count > 0 else { return 0 }
        var rms: Float = 0
        samples.withUnsafeBufferPointer { buffer in
            vDSP_rmsqv(buffer.baseAddress! + (samples.count - count), 1, &rms, vDSP_Length(count))
        }
        return rms
    }

    // YIN's normalized difference function rejects aperiodic input. Refine the
    // selected lag at the original sample rate for short, high-note periods.
    static func detect(_ samples: [Float], sampleRate: Double) -> Double? {
        guard sampleRate >= 8000, samples.count >= Int(sampleRate * 0.09) else { return nil }
        // High registers need several samples per period even with strong overtones.
        // A short rising-edge count only chooses the analysis rate, never the note.
        let probe = samples.suffix(min(512, samples.count))
        var risingEdges = 0
        var prior = probe.first ?? 0
        for value in probe {
            if prior <= 0 && value > 0 { risingEdges += 1 }
            prior = value
        }
        let edgeRate = Double(risingEdges) * sampleRate / Double(probe.count)
        let stride = edgeRate > 1300 ? 1 : max(1, Int(sampleRate / 12000))
        let n = samples.count / stride
        var decimated = [Float](repeating: 0, count: n)
        for i in 0..<n {
            var sum: Float = 0
            for j in 0..<stride { sum += samples[i * stride + j] }
            decimated[i] = sum / Float(stride)
        }
        var rms: Float = 0
        vDSP_rmsqv(decimated, 1, &rms, vDSP_Length(n))
        guard rms > 0.0012 else { return nil }
        let rate = sampleRate / Double(stride)
        let last = min(n / 2 - 1, Int(rate / 24))
        let first = max(2, Int(rate / 4300))
        let count = n - last
        var diff = [Float](repeating: 1, count: last + 1)
        var total: Float = 0
        decimated.withUnsafeBufferPointer { buffer in
            let base = buffer.baseAddress!
            for lag in 1...last {
                var distance: Float = 0
                vDSP_distancesq(base, 1, base + lag, 1, &distance, vDSP_Length(count))
                total += distance
                diff[lag] = total > 0 ? distance * Float(lag) / total : 1
                if lag > first + 1 && diff[lag-1] < 0.14 && diff[lag] >= diff[lag-1] { break }
            }
        }
        guard var period = (first..<last).first(where: { diff[$0] < 0.14 }) else { return nil }
        while period < last && diff[period+1] < diff[period] { period += 1 }
        let center = period * stride
        // At bass pitches, one-sample differences near the broad peak are dominated by noise.
        let spacing = rate / Double(period) < 140 ? Int(sampleRate / 2500) : 1
        let low = max(2, center - stride)
        let high = min(samples.count / 2, center + stride)
        let length = vDSP_Length(samples.count - max(high + 1, center + spacing))
        let lag = samples.withUnsafeBufferPointer { buffer -> Double in
            let p = buffer.baseAddress!
            var earlyEnergy: Float = 0
            vDSP_svesq(p, 1, &earlyEnergy, length)
            func distance(_ k: Int) -> Double {
                // Compare the shape of each period independently of the decaying amplitude.
                var product: Float = 0
                var lateEnergy: Float = 0
                vDSP_dotpr(p, 1, p + k, 1, &product, length)
                vDSP_svesq(p + k, 1, &lateEnergy, length)
                let energy = sqrt(Double(earlyEnergy) * Double(lateEnergy))
                return 1 - Double(product) / max(1e-12, energy)
            }
            let best = spacing > 1 ? center : (low...high).min { distance($0) < distance($1) }!
            let a = distance(best - spacing), b = distance(best), c = distance(best + spacing)
            let bend = a - 2 * b + c
            let offset = bend > 0 ? min(0.5, max(-0.5, (a - c) / (2 * bend))) : 0
            return Double(best) + offset * Double(spacing)
        }
        let hz = sampleRate / lag
        guard (24...4300).contains(hz) else { return nil }
        return fundamental(near: lag, in: samples, sampleRate: sampleRate, rms: rms)
    }

    private static func fundamental(near period: Double, in samples: [Float], sampleRate: Double, rms: Float) -> Double {
        let maxPeriod = min(sampleRate / 24, Double(samples.count) / 2)
        let multiples = [2, 3].filter { period * Double($0) < maxPeriod }
        guard let longest = multiples.last else { return sampleRate / period }

        // Use the same samples for each comparison so the attack or decay
        // cannot change the result simply by changing the comparison window.
        let end = samples.count - Int(ceil(period * Double(longest))) - 2
        let start = end / 6
        func mismatch(at delay: Double) -> Float {
            let offset = Int(delay)
            let fraction = Float(delay - Double(offset))
            var product: Float = 0
            var earlyEnergy: Float = 0
            var lateEnergy: Float = 0
            for i in start..<end {
                let a = samples[i]
                let next = i + offset
                let b = samples[next] + fraction * (samples[next + 1] - samples[next])
                product += a * b
                earlyEnergy += a * a
                lateEnergy += b * b
            }
            return max(0, 1 - product / max(1e-12, sqrt(earlyEnergy * lateEnergy)))
        }

        let shortMismatch = mismatch(at: period)
        // A pure higher note also repeats after two or three periods. Switch
        // only if the longer period explains additional signal energy.
        for multiple in multiples {
            let longerPeriod = period * Double(multiple)
            let longMismatch = mismatch(at: longerPeriod)
            guard shortMismatch - longMismatch > 0.002, longMismatch < shortMismatch * 0.42 else { continue }
            let candidate = sampleRate / longerPeriod
            // Interpolated comparisons can favor a longer delay at some high
            // pitches. Verify a partial the shorter period cannot explain.
            let supported = (1..<(multiple * 2)).contains { partial in
                guard !partial.isMultiple(of: multiple) else { return false }
                let hz = candidate * Double(partial)
                return hz < sampleRate / 2 && partialAmplitude(hz, in: samples, sampleRate: sampleRate) > Double(rms) * 0.036
            }
            if supported { return candidate }
        }
        return sampleRate / period
    }

    private static func partialAmplitude(_ hz: Double, in samples: [Float], sampleRate: Double) -> Double {
        let step = 2 * Double.pi * hz / sampleRate
        let windowStep = 2 * Double.pi / Double(samples.count - 1)
        var real = 0.0
        var imaginary = 0.0
        for index in samples.indices {
            let frame = Double(index)
            let weighted = Double(samples[index]) * (0.5 - 0.5 * cos(frame * windowStep))
            real += weighted * cos(frame * step)
            imaginary += weighted * sin(frame * step)
        }
        return 4 * hypot(real, imaginary) / Double(samples.count - 1)
    }
}

enum IntonationState: Equatable {
    case flat, nearFlat, settling, centered, nearSharp, sharp
    var label: String {
        switch self {
        case .flat: return "Flat"
        case .sharp: return "Sharp"
        case .nearFlat: return "Almost · flat"
        case .nearSharp: return "Almost · sharp"
        case .settling: return "Settling"
        case .centered: return "In tune"
        }
    }
}

struct TunerReading {
    var hz: Double
    var note: Int
    var cents: Double
    var state: IntonationState
    var centeredDuration: TimeInterval
    var isFresh = true
    var confirmedReplayDetuning = false

    var displayedCents: Double { state == .centered ? 0 : max(-50, min(50, cents)) }
    var signedCents: String {
        String(format: "%+.0f¢", state == .centered ? 0 : cents).replacingOccurrences(of: "-", with: "−")
    }
}

enum TunerResponse: String, CaseIterable {
    case balanced, steady

    var title: String { self == .balanced ? "Balanced" : "Steady" }
    var dwell: TimeInterval { self == .balanced ? 0.18 : 0.24 }
    var damping: Double { self == .balanced ? 1 : 0.72 }
}

struct TunerTracker {
    private var previous: TunerReading?
    private var centeredSince: TimeInterval?
    private var lastValidAt: TimeInterval?
    private var lastCenteredSampleAt: TimeInterval?
    private var lastLevel: Float?
    private var confirmedPluck: Int?
    private var stringRecheck = TunerStringRecheck()

    mutating func reset(preservingEnvelope: Bool = false) {
        resetReading()
        lastLevel = nil
        confirmedPluck = nil
        if preservingEnvelope { stringRecheck.finishAttack() }
        else { stringRecheck = TunerStringRecheck() }
    }

    private mutating func resetReading() {
        previous = nil
        centeredSince = nil
        lastValidAt = nil
        lastCenteredSampleAt = nil
    }
    mutating func read(hz: Double?, reference: Int, targets: [Int], held: Int?, time: TimeInterval,
                       response: TunerResponse = .balanced, pluckLevel: Float? = nil,
                       guardsPluckHarmonics: Bool = true) -> TunerReading? {
        if let pluckLevel { stringRecheck.measure(level: pluckLevel, at: time) }
        if let pluckLevel, guardsPluckHarmonics {
            if pluckLevel <= 0.0012 && (lastValidAt.map { time - $0 >= 0.10 } ?? true) {
                confirmedPluck = nil
            }
            if let lastLevel, pluckLevel > lastLevel * 1.5, pluckLevel - lastLevel > 0.0012,
               confirmedPluck != nil {
                // A new attack can be a real octave or fifth even when the
                // preceding string is still ringing in the analysis window.
                confirmedPluck = nil
                resetReading()
            }
            lastLevel = pluckLevel
        }
        guard let hz, hz.isFinite, hz > 0 else { return missingSample(at: time) }
        let exact = TunerPitch.fractionalNote(hz, reference: reference)
        let nearest = targets.min(by: { abs(Double($0) - exact) < abs(Double($1) - exact) })
        if let held {
            if Self.isUpperPartial(hz, of: held, reference: reference) {
                // A held string needs a measured fundamental, not just a
                // plausible higher partial that sends the needle to its stop.
                return missingSample(at: time)
            }
        } else if let nearest {
            if abs(Double(nearest) - exact) > 1 { return missingSample(at: time) }
            if guardsPluckHarmonics, pluckLevel != nil, let confirmedPluck, nearest != confirmedPluck,
               Self.isUpperPartial(hz, of: confirmedPluck, reference: reference) {
                return missingSample(at: time)
            }
        }
        if let lastValidAt, time - lastValidAt > 0.12 { resetReading() }
        let elapsed = lastValidAt.map { max(0.008, min(0.050, time - $0)) } ?? 0.024
        lastValidAt = time
        var note = held ?? nearest ?? Int(exact.rounded())
        if held == nil, let old = previous, old.note != note,
           abs(Double(old.note)-exact) < abs(Double(note)-exact) + 0.06 { note = old.note }
        let raw = (exact - Double(note)) * 100
        let same = previous?.note == note
        let prior = same ? previous?.cents ?? raw : raw
        let error = abs(raw - prior)
        let gain = min(0.76, 0.26 + error / 37)
        let weight = 1 - pow(1 - gain * response.damping, min(1.2, elapsed / 0.024))
        let cents = prior + (raw - prior) * weight
        // Display smoothing must not turn a pitch passing through zero into a confirmation.
        let withinEntry = abs(raw) <= 3 && abs(cents) <= 3
        if !same || !withinEntry { centeredSince = nil }
        if withinEntry && centeredSince == nil { centeredSince = time }
        let locked = (same && previous?.state == .centered && abs(cents) <= 5 && abs(raw) <= 5)
            || centeredSince.map { time - $0 >= response.dwell } == true
        if locked, pluckLevel != nil, guardsPluckHarmonics { confirmedPluck = note }
        let state: IntonationState = locked ? .centered : (abs(cents) <= 3 ? .settling : cents < -12 ? .flat : cents > 12 ? .sharp : cents < 0 ? .nearFlat : .nearSharp)
        let duration: TimeInterval
        if locked, same, let previous, previous.state == .centered {
            duration = previous.centeredDuration + (lastCenteredSampleAt.map { max(0, time - $0) } ?? 0)
        } else {
            duration = 0
        }
        lastCenteredSampleAt = locked ? time : nil
        let detunedReplay = pluckLevel != nil && nearest == note && abs(raw) <= 100
            && stringRecheck.observe(note: note, rawCents: raw, centered: locked, at: time)
        let value = TunerReading(hz: hz, note: note, cents: cents, state: state, centeredDuration: duration,
                                 confirmedReplayDetuning: detunedReplay)
        previous = value
        return value
    }

    private static func isUpperPartial(_ hz: Double, of note: Int, reference: Int) -> Bool {
        let ratio = hz / TunerPitch.frequency(note, reference: reference)
        let harmonic = ratio.rounded()
        return (2...3).contains(harmonic) && abs(1200 * log2(ratio / harmonic)) <= 50
    }

    private mutating func missingSample(at time: TimeInterval) -> TunerReading? {
        centeredSince = nil
        lastCenteredSampleAt = nil
        if var previous, let lastValidAt, time - lastValidAt < 0.10 {
            // A momentary dropout may hold the picture, but cannot confirm a string.
            previous.isFresh = false
            previous.confirmedReplayDetuning = false
            return previous
        }
        resetReading()
        return nil
    }
}

private struct TunerStringRecheck {
    private struct Evidence {
        let note: Int
        let cents: Double
        let start: TimeInterval
        var last: TimeInterval
    }

    private let minimumLevel: Float = 0.002
    private var previousLevel: Float = 0
    private var quietSince: TimeInterval?
    private var level: Float = 0
    private var peak: Float = 0
    private var attackAt: TimeInterval?
    private var evidence: Evidence?

    mutating func measure(level: Float, at time: TimeInterval) {
        if level <= 0.0012, quietSince == nil { quietSince = time }
        let rest = quietSince.map { time - $0 >= 0.09 } ?? false
        let rising = level > previousLevel * 1.5 && level - previousLevel >= 0.0012
        if level >= minimumLevel, rising || rest {
            attackAt = time
            peak = level
            evidence = nil
        }
        if level >= minimumLevel { quietSince = nil }
        previousLevel = level
        self.level = level
        peak = max(peak, level)
    }

    mutating func observe(note: Int, rawCents: Double, centered: Bool, at time: TimeInterval) -> Bool {
        guard let attackAt else { return false }
        let attackAge = time - attackAt
        if attackAge > 0.65 || level < max(minimumLevel, peak * 0.38) {
            finishAttack()
            return false
        }
        if centered {
            // Level looks at a shorter window than pitch. Give old ringing
            // through the first frames of this attack time to leave the window.
            if attackAge >= 0.14 { finishAttack() }
            evidence = nil
            return false
        }
        guard abs(rawCents) >= 9 else {
            evidence = nil
            return false
        }
        if var evidence, evidence.note == note, time - evidence.last <= 0.10,
           abs(rawCents - evidence.cents) <= 5 {
            if time - evidence.start >= 0.22 {
                finishAttack()
                return true
            }
            evidence.last = time
            self.evidence = evidence
        } else {
            evidence = Evidence(note: note, cents: rawCents, start: time, last: time)
        }
        return false
    }

    mutating func finishAttack() {
        attackAt = nil
        evidence = nil
    }
}
