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

    static func chromaticWindowDuration(after hz: Double?) -> Double {
        // A longer window separates the broad correlation peak of bass notes
        // without averaging away the movement of sung or higher notes.
        (hz ?? .infinity) < 70 ? 0.144 : 0.096
    }

    static func detect(_ samples: [Float], sampleRate: Double, chromatic: Bool = false) -> Double? {
        guard sampleRate >= 8000, samples.count >= Int(sampleRate * 0.09) else { return nil }
        let pitch = periodPitch(samples, sampleRate: sampleRate, chromatic: chromatic)
        if !chromatic, (pitch ?? 0) < 76,
           let recovered = periodPitch(samples, sampleRate: sampleRate, chromatic: chromatic, rejectingRumble: true),
           (100...340).contains(recovered) {
            let original = pitch.map { partialAmplitude($0, in: samples, sampleRate: sampleRate) } ?? 0
            let strength = partialAmplitude(recovered, in: samples, sampleRate: sampleRate)
            // Keep a measured low note when its fundamental is clearly present.
            if strength > max(0.00018, original * 2.5) {
                let hasLowerPartial = [recovered / 2, recovered / 3].contains { lower in
                    guard partialAmplitude(lower, in: samples, sampleRate: sampleRate) >= strength * 0.14 else {
                        return false
                    }
                    let (measured, amplitude) = phaseEstimate(near: lower, samples: samples, sampleRate: sampleRate)
                    return amplitude >= strength * 0.12 && abs(1200 * log2(measured / lower)) <= 28
                }
                if !hasLowerPartial { return recovered }
            }
        }
        if chromatic, pitch.map({ $0 < 165 || (420...1650).contains($0) }) ?? true,
           let recovered = quietHighPitch(samples, sampleRate: sampleRate, periodPitch: pitch) {
            return recovered
        }
        return pitch
    }

    // YIN's normalized difference function rejects aperiodic input. Refine the
    // selected lag at the original sample rate for short, high-note periods.
    private static func periodPitch(_ samples: [Float], sampleRate: Double,
                                    chromatic: Bool, rejectingRumble: Bool = false) -> Double? {
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
        let isQuiet = rms <= 0.0012
        guard rms > 0.00018 else { return nil }
        let rate = sampleRate / Double(stride)
        if rejectingRumble {
            removeRumble(from: &decimated, sampleRate: rate)
        } else if chromatic || isQuiet {
            // Room and handling rumble can make the period search favor a
            // subharmonic. Use the original samples to refine and verify pitch.
            let coefficient = Float(exp(-2 * Double.pi * 70 / rate))
            var previous = decimated[0]
            var filtered: Float = 0
            for index in decimated.indices {
                let sample = decimated[index]
                filtered = coefficient * (filtered + sample - previous)
                decimated[index] = filtered
                previous = sample
            }
        }
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
        // Increase the periodicity requirement gradually as the signal falls
        // toward the noise floor. A hard step makes quiet held notes flicker.
        if isQuiet {
            let signal = max(0, min(1, (rms - 0.0006) / 0.0006))
            guard diff[period] < 0.06 + 0.08 * signal else { return nil }
        }
        if rejectingRumble {
            // The raw signal can pull the fit back toward the rejected rumble.
            let left = diff[period - 1], middle = diff[period], right = diff[min(last, period + 1)]
            let curvature = left - 2 * middle + right
            let shift = curvature > 0 ? min(0.5, max(-0.5, (left - right) / (2 * curvature))) : 0
            return rate / (Double(period) + Double(shift))
        }
        let center = period * stride
        let coarseFrequency = rate / Double(period)
        let spacing: Int
        if coarseFrequency < 140 {
            spacing = Int(sampleRate / 2500)
        } else if chromatic && stride == 1 && coarseFrequency < 700 {
            // Noise can trigger full-rate analysis even on a low voice. Fit
            // across more of the broad peak so adjacent samples cannot flip the result.
            spacing = max(1, center / 20)
        } else {
            spacing = 1
        }
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

    private static func removeRumble(from samples: inout [Float], sampleRate: Double) {
        // Fourth-order Butterworth high-pass. The recovery pass can suppress
        // room rumble without also suppressing the first partial of a D string.
        let frequency = 2 * Double.pi * 110 / sampleRate
        let cosine = cos(frequency)
        let sine = sin(frequency)
        for section in [0.5411961, 1.3065630] {
            let scale = 1 / (1 + sine / (2 * section))
            let b0 = Float((1 + cosine) * scale / 2)
            let a1 = Float(-2 * cosine * scale)
            let a2 = Float((2 * scale) - 1)
            var z1 = -b0 * samples[0]
            var z2 = b0 * samples[0]
            for i in samples.indices {
                let input = samples[i]
                let output = b0 * input + z1
                z1 = -2 * b0 * input - a1 * output + z2
                z2 = b0 * input - a2 * output
                samples[i] = output
            }
        }
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
        let frequency = sampleRate / period
        if (120...360).contains(frequency), let octave = octaveBelow(frequency, in: samples, sampleRate: sampleRate, rms: rms) {
            return octave
        }
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
        return frequency
    }

    private static func octaveBelow(_ frequency: Double, in samples: [Float], sampleRate: Double, rms: Float) -> Double? {
        // A bowed string can have a very strong second partial. A lower
        // fundamental and third partial form independent evidence of the
        // longer period even when the correlation minimum is at the octave.
        let lower = frequency / 2
        let first = partialAmplitude(lower, in: samples, sampleRate: sampleRate)
        guard first > Double(rms) * 0.038 else { return nil }
        let third = lower * 3
        let thirdAmplitude = partialAmplitude(third, in: samples, sampleRate: sampleRate)
        guard thirdAmplitude > Double(rms) * 0.026 else { return nil }
        let (peak, amplitude) = phaseEstimate(near: frequency, samples: samples, sampleRate: sampleRate)
        guard amplitude > Double(rms) * 0.65, abs(1200 * log2(peak / frequency)) <= 36 else { return nil }
        let (measured, strength) = phaseEstimate(near: peak * 1.5, samples: samples, sampleRate: sampleRate)
        guard strength > Double(rms) * 0.021, abs(1200 * log2(measured / (peak * 1.5))) <= 30 else { return nil }
        return peak / 2
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

    private static let quietPitchFFT = vDSP_create_fftsetup(12, FFTRadix(kFFTRadix2))

    private static func quietHighPitch(_ samples: [Float], sampleRate: Double, periodPitch: Double?) -> Double? {
        let level = tailLevel(samples, sampleRate: sampleRate)
        let upperLevel: Float = (periodPitch ?? 0) >= 420 ? 0.0016 : 0.003
        guard (0.00016...upperLevel).contains(level), let setup = quietPitchFFT else { return nil }

        // A narrow spectral line can survive low-frequency room noise even
        // when the broadband period search drops out or picks a long lag.
        let count = min(4096, 1 << (Int.bitWidth - 1 - samples.count.leadingZeroBitCount))
        let half = count / 2
        let taper = 2 * Double.pi / Double(count - 1)
        var even = [Float](repeating: 0, count: half)
        var odd = even
        let start = samples.count - count
        for index in 0..<half {
            let frame = 2 * index
            even[index] = samples[start + frame] * Float(0.5 - 0.5 * cos(Double(frame) * taper))
            odd[index] = samples[start + frame + 1] * Float(0.5 - 0.5 * cos(Double(frame + 1) * taper))
        }
        even.withUnsafeMutableBufferPointer { real in
            odd.withUnsafeMutableBufferPointer { imaginary in
                var signal = DSPSplitComplex(realp: real.baseAddress!, imagp: imaginary.baseAddress!)
                vDSP_fft_zrip(setup, &signal, 1, vDSP_Length(count.trailingZeroBitCount), FFTDirection(kFFTDirection_Forward))
            }
        }
        let binWidth = sampleRate / Double(count)
        let first = Int(ceil(430 / binWidth))
        let last = min(half - 2, Int(1600 / binWidth))
        guard first <= last else { return nil }

        func power(_ bin: Int) -> Float { even[bin] * even[bin] + odd[bin] * odd[bin] }
        let peak = (first...last).max { power($0) < power($1) }!
        let localPower = (peak - 1...peak + 1).reduce(Float.zero) { $0 + power($1) }
        let firstBandBin = max(1, Int(230 / binWidth))
        let bandPower = (firstBandBin..<half).reduce(Float.zero) { $0 + power($1) }
        guard localPower > 0, localPower >= bandPower * 0.68 else { return nil }

        let left = log(Double(max(power(peak - 1), 1e-20)))
        let center = log(Double(power(peak)))
        let right = log(Double(max(power(peak + 1), 1e-20)))
        let bend = left - 2 * center + right
        let offset = bend < 0 ? min(0.5, max(-0.5, (left - right) / (2 * bend))) : 0
        let estimate = (Double(peak) + offset) * binWidth
        let (measured, strength) = phaseEstimate(near: estimate, samples: samples, sampleRate: sampleRate)
        guard strength >= 0.00022, abs(measured - estimate) <= min(4, binWidth * 0.35) else { return nil }

        if let periodPitch {
            if periodPitch < 165 {
                // A weak high partial of a real bass note is still a bass note.
                let lowPower = (1...3).reduce(0.0) { total, partial in
                    let amplitude = partialAmplitude(periodPitch * Double(partial), in: samples, sampleRate: sampleRate)
                    return total + amplitude * amplitude
                }
                guard measured > periodPitch * 3.4, sqrt(lowPower) < strength * 0.72 else { return nil }
            } else {
                // Use phase for fine pitch when the two methods hear the same note.
                guard abs(1200 * log2(measured / periodPitch)) < 70 else { return nil }
            }
        }
        // The spectral search starts above the bass range. A clean-looking
        // peak can be the second or third partial of a decaying string whose
        // period was obscured by noise. Verify its fundamental in both halves.
        for harmonic in [3, 2] {
            let expected = measured / Double(harmonic)
            let bin = Int((expected / binWidth).rounded())
            guard power(bin) > power(peak) * 0.04 else { continue }
            let (lower, amplitude) = phaseEstimate(near: expected, samples: samples, sampleRate: sampleRate)
            if amplitude >= strength * 0.24, abs(1200 * log2(lower / expected)) <= 25 {
                return lower
            }
        }
        return measured
    }

    /// Recheck a previously measured tone after a weak dropout or a jump to a
    /// lower subharmonic. Phase measures the current frequency from fresh input.
    static func continueChromaticPitch(near prior: Double, proposed: Double?,
                                           samples: [Float], sampleRate: Double) -> Double? {
        let level = Double(tailLevel(samples, sampleRate: sampleRate))
        guard level >= 0.0006 else { return nil }
        if let proposed {
            guard proposed < prior * 0.6 else { return nil }
            if level > 0.0014 {
                let ratio = prior / proposed
                let multiple = ratio.rounded()
                guard (2...3).contains(multiple), abs(1200 * log2(ratio / multiple)) <= 32 else { return nil }
            }
        } else {
            guard level <= 0.0014 else { return nil }
        }

        let (measured, strength) = phaseEstimate(near: prior, samples: samples, sampleRate: sampleRate)
        guard strength >= level * 0.64 else { return nil }
        if (120...360).contains(measured), octaveBelow(measured, in: samples, sampleRate: sampleRate, rms: Float(level)) != nil {
            return nil
        }
        if let proposed, partialAmplitude(proposed, in: samples, sampleRate: sampleRate) > strength * 0.28 {
            return nil
        }
        guard abs(1200 * log2(measured / prior)) <= 32 else { return nil }
        return measured
    }

    private static func phaseEstimate(near hz: Double, samples: [Float], sampleRate: Double) -> (Double, Double) {
        let half = samples.count / 2
        let radians = 2 * Double.pi * hz / sampleRate
        let taper = 2 * Double.pi / Double(half - 1)
        func projection(from offset: Int) -> (real: Double, imaginary: Double) {
            var real = 0.0
            var imaginary = 0.0
            for index in 0..<half {
                let frame = offset + index
                let angle = Double(frame) * radians
                let weighted = Double(samples[frame]) * (0.5 - 0.5 * cos(Double(index) * taper))
                real += weighted * cos(angle)
                imaginary -= weighted * sin(angle)
            }
            return (real, imaginary)
        }

        let early = projection(from: 0)
        let late = projection(from: half)
        let strength = min(hypot(early.real, early.imaginary), hypot(late.real, late.imaginary)) * 4 / Double(half)
        let advance = atan2(late.imaginary * early.real - late.real * early.imaginary,
                            late.real * early.real + late.imaginary * early.imaginary)
        return (hz + advance * sampleRate / (2 * .pi * Double(half)), strength)
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

struct TunerReading: Equatable {
    var hz: Double
    var note: Int
    var cents: Double
    var state: IntonationState
    var centeredDuration: TimeInterval
    var isFresh = true
    var confirmedReplayDetuning = false
    var measuredAt: TimeInterval? = nil

    var displayedCents: Double { state == .centered ? 0 : max(-50, min(50, cents)) }
    var signedCents: String {
        Self.formatCents(state == .centered ? 0 : cents)
    }

    static func formatCents(_ cents: Double) -> String {
        let value = cents.rounded()
        return value == 0 ? "0¢" : String(format: "%+.0f¢", value).replacingOccurrences(of: "-", with: "−")
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
    private var chromaticCenter = ChromaticCenter()
    private var waitsForStringAttack = false
    private var chromaticPitch = ChromaticPitchStabilizer()

    mutating func reset(preservingEnvelope: Bool = false, waitsForStringAttack: Bool = false) {
        resetReading()
        lastLevel = nil
        confirmedPluck = nil
        self.waitsForStringAttack = waitsForStringAttack
        if preservingEnvelope { stringRecheck.finishAttack() }
        else { stringRecheck = TunerStringRecheck() }
    }

    private mutating func resetReading() {
        previous = nil
        centeredSince = nil
        lastValidAt = nil
        lastCenteredSampleAt = nil
        chromaticCenter = ChromaticCenter()
        chromaticPitch = ChromaticPitchStabilizer()
    }
    mutating func read(hz: Double?, reference: Int, targets: [Int], held: Int?, time: TimeInterval,
                       response: TunerResponse = .balanced, pluckLevel: Float? = nil,
                       guardsPluckHarmonics: Bool = true, chromatic: Bool = false,
                       stabilizeChromaticPitch: Bool = false) -> TunerReading? {
        if let pluckLevel {
            let newAttack = stringRecheck.measure(level: pluckLevel, at: time)
            if waitsForStringAttack {
                guard newAttack else { return nil }
                waitsForStringAttack = false
            }
        }
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
        if let held, !chromatic {
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
        var stablePitch: Double?
        if chromatic && stabilizeChromaticPitch {
            guard let pitch = chromaticPitch.observe(exact * 100, at: time, elapsed: elapsed, response: response) else {
                // Hold the display through an isolated jump and pause confirmation evidence.
                return missingSample(at: time)
            }
            stablePitch = pitch
        } else if chromatic {
            chromaticPitch = ChromaticPitchStabilizer()
        }
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
        let cents = stablePitch.map { $0 - Double(note) * 100 } ?? (prior + (raw - prior) * weight)
        if chromatic {
            if !same { chromaticCenter = ChromaticCenter() }
            let center = chromaticCenter.observe(raw, displayedCents: cents, at: time, response: response)
            let state: IntonationState = center.locked ? .centered : Self.uncenteredState(cents)
            let value = TunerReading(hz: hz, note: note, cents: cents, state: state,
                                     centeredDuration: center.duration, measuredAt: time)
            previous = value
            return value
        }
        // Display smoothing must not turn a pitch passing through zero into a confirmation.
        let withinEntry = abs(raw) <= 3 && abs(cents) <= 3
        if !same || !withinEntry { centeredSince = nil }
        if withinEntry && centeredSince == nil { centeredSince = time }
        let locked = (same && previous?.state == .centered && abs(cents) <= 5 && abs(raw) <= 5)
            || centeredSince.map { time - $0 >= response.dwell } == true
        if locked, pluckLevel != nil, guardsPluckHarmonics { confirmedPluck = note }
        let state: IntonationState = locked ? .centered : Self.uncenteredState(cents)
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

    private static func uncenteredState(_ cents: Double) -> IntonationState {
        abs(cents) <= 3 ? .settling : cents < -12 ? .flat : cents > 12 ? .sharp : cents < 0 ? .nearFlat : .nearSharp
    }

    private static func isUpperPartial(_ hz: Double, of note: Int, reference: Int) -> Bool {
        let ratio = hz / TunerPitch.frequency(note, reference: reference)
        let harmonic = ratio.rounded()
        return (2...3).contains(harmonic) && abs(1200 * log2(ratio / harmonic)) <= 50
    }

    private mutating func missingSample(at time: TimeInterval) -> TunerReading? {
        centeredSince = nil
        lastCenteredSampleAt = nil
        chromaticCenter.pause()
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

/// Light display damping for small wobbles. Confirmation uses the accepted raw samples.
private struct ChromaticPitchStabilizer {
    private struct Jump {
        let pitch: Double
        let time: TimeInterval
    }

    private var previousPitch: Double?
    private var display: Double?
    private var pendingJump: Jump?

    mutating func observe(_ pitch: Double, at time: TimeInterval, elapsed: TimeInterval,
                          response: TunerResponse) -> Double? {
        guard let previousPitch, let display else { return start(at: pitch) }
        // Reject a single register jump without holding normal slides or note changes.
        if abs(pitch - previousPitch) > 600 {
            if let pendingJump, time - pendingJump.time <= 0.080, abs(pitch - pendingJump.pitch) <= 40 {
                return start(at: pitch)
            }
            pendingJump = Jump(pitch: pitch, time: time)
            return nil
        }
        pendingJump = nil
        let delta = pitch - display
        if abs(delta) >= 60 { return start(at: pitch) }

        self.previousPitch = pitch
        let steadyWeight = 1 - exp(-elapsed * response.damping / 0.065)
        let movement = min(1, max(0, (abs(delta) - 10) / 18))
        let weight = steadyWeight + (0.88 - steadyWeight) * movement
        let next = display + delta * weight
        self.display = next
        return next
    }

    private mutating func start(at pitch: Double) -> Double {
        previousPitch = pitch
        display = pitch
        pendingJump = nil
        return pitch
    }
}

// Confirmation for sustained pitch. Keep the live cents estimate separate so a
// natural vibrato can confirm without freezing or zeroing the measured offset.
private struct ChromaticCenter {
    private static let entryOffset = 10.5
    private static let exitOffset = 12.0
    private static let immediateExitOffset = 18.0

    private struct Sample {
        let time: TimeInterval
        let cents: Double
    }

    private var samples: [Sample] = []
    private var locked = false
    private var duration: TimeInterval = 0
    private var awaySince: TimeInterval?
    private var lastStableAt: TimeInterval?
    private var lastOnCenterAt: TimeInterval?

    mutating func observe(_ cents: Double, displayedCents: Double, at time: TimeInterval,
                          response: TunerResponse) -> (locked: Bool, duration: TimeInterval) {
        // A large departure overrides the hold for brief, near-center fluctuations.
        if abs(cents) >= Self.immediateExitOffset || abs(displayedCents) >= Self.immediateExitOffset {
            self = ChromaticCenter()
            return (false, 0)
        }
        let start = time - response.dwell
        if let last = samples.last, time <= last.time { return (locked, duration) }
        samples.append(Sample(time: time, cents: cents))
        while samples.count > 1 && samples[1].time <= start { samples.removeFirst() }

        // Integrate by time, since audio callbacks need not arrive at a fixed interval.
        var sum = 0.0
        var squareSum = 0.0
        var peak = abs(cents)
        var variation = 0.0
        var firstCents: Double?
        for (earlier, later) in zip(samples, samples.dropFirst()) {
            let clippedStart = max(start, earlier.time)
            let fraction = (clippedStart - earlier.time) / (later.time - earlier.time)
            let first = earlier.cents + (later.cents - earlier.cents) * fraction
            let span = later.time - clippedStart
            sum += (first + later.cents) * 0.5 * span
            let last = later.cents
            squareSum += (first * first + first * last + last * last) * span / 3
            peak = max(peak, abs(first), abs(later.cents))
            variation += abs(later.cents - first)
            if firstCents == nil { firstCents = first }
        }
        let fullWindow = samples.count >= 3 && samples[0].time <= start
        let mean = sum / response.dwell
        // Measure steadiness around the sung pitch, independently of its tuning offset.
        let spread = sqrt(max(0, squareSum / response.dwell - mean * mean))
        let drift = abs(cents - (firstCents ?? cents))
        let gliding = drift > 5 && drift > variation * 0.75
        let onCenter = fullWindow && abs(mean) < Self.entryOffset && spread <= 6.5 && peak <= 17 && !gliding
        if locked {
            let unstable = fullWindow && (abs(mean) >= Self.exitOffset || spread > 8.5)
            if fullWindow && !unstable { lastStableAt = time }
            if unstable {
                awaySince = awaySince ?? time
            } else {
                awaySince = nil
            }
            let driftingAway = awaySince.map { time - $0 >= 0.10 } ?? false
            let noStableWindow = lastStableAt.map { time - $0 > response.dwell + 0.16 } ?? false
            if driftingAway || noStableWindow {
                locked = false
                duration = 0
            }
        } else if onCenter {
            locked = true
            awaySince = nil
            lastStableAt = time
        }
        if locked && onCenter {
            if let lastOnCenterAt { duration += time - lastOnCenterAt }
            lastOnCenterAt = time
        } else {
            lastOnCenterAt = nil
        }
        return (locked, duration)
    }

    mutating func pause() {
        samples.removeAll(keepingCapacity: true)
        awaySince = nil
        lastOnCenterAt = nil
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

    mutating func measure(level: Float, at time: TimeInterval) -> Bool {
        if level <= 0.0012, quietSince == nil { quietSince = time }
        let rest = quietSince.map { time - $0 >= 0.09 } ?? false
        let rising = level > previousLevel * 1.5 && level - previousLevel >= 0.0012
        let newAttack = level >= minimumLevel && (rising || rest)
        if newAttack {
            attackAt = time
            peak = level
            evidence = nil
        }
        if level >= minimumLevel { quietSince = nil }
        previousLevel = level
        self.level = level
        peak = max(peak, level)
        return newAttack
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
