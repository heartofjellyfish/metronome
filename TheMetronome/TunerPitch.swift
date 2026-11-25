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
        let level = tailLevel(samples, sampleRate: sampleRate)
        let canRecoverQuietHigh = chromatic && level >= 0.00016
            && level <= ((pitch ?? 0) >= 420 ? 0.0016 : 0.003)
            && (pitch.map { $0 < 165 || (420...1650).contains($0) } ?? true)
        if canRecoverQuietHigh || (pitch == nil && level >= 0.0003),
           let spectrum = spectrum(of: samples, sampleRate: sampleRate) {
            if pitch == nil, let recovered = harmonicPitch(in: samples, sampleRate: sampleRate, spectrum: spectrum) {
                return recovered
            }
            if canRecoverQuietHigh,
               let recovered = quietHighPitch(samples, sampleRate: sampleRate, periodPitch: pitch, spectrum: spectrum) {
                return recovered
            }
        }
        if let pitch, (pitch < 145 || pitch > 550),
           pitch * Double(samples.count) >= sampleRate * 10 {
            // At short periods even a fraction of a sample biases the cents
            // reading. Check the phase advance of the measured fundamental.
            let (refined, strength) = phaseEstimate(near: pitch, samples: samples, sampleRate: sampleRate)
            let phaseLimit = 0.75 * sampleRate / Double(samples.count)
            if strength > Double(level) * 0.32, abs(refined - pitch) < phaseLimit,
               abs(1200 * log2(refined / pitch)) < 7 { return refined }
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
        return fundamental(near: lag, in: samples, sampleRate: sampleRate, rms: rms, chromatic: chromatic)
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

    private static func fundamental(near period: Double, in samples: [Float], sampleRate: Double,
                                    rms: Float, chromatic: Bool) -> Double {
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
        if (120...1100).contains(frequency), let octave = octaveBelow(frequency, in: samples, sampleRate: sampleRate, rms: rms, chromatic: chromatic) {
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

    private static func octaveBelow(_ frequency: Double, in samples: [Float], sampleRate: Double,
                                    rms: Float, chromatic: Bool = false) -> Double? {
        // A bowed string can have a very strong second partial. A lower
        // fundamental and third partial form independent evidence of the
        // longer period even when the correlation minimum is at the octave.
        let lower = frequency / 2
        let first = partialAmplitude(lower, in: samples, sampleRate: sampleRate)
        let weakRoot = first <= Double(rms) * 0.038
        let lowRegister = frequency <= 360
        if lowRegister && weakRoot && !chromatic { return nil }
        let third = lower * 3
        let thirdAmplitude = partialAmplitude(third, in: samples, sampleRate: sampleRate)
        let minimumThird = lowRegister ? 0.026 : 0.10
        guard thirdAmplitude > Double(rms) * minimumThird else { return nil }
        if weakRoot {
            // Confirm the missing root independently of the loud octave. For bass
            // notes the root itself can also emerge when measured over shorter windows.
            let (fifth, strength) = phaseEstimate(near: lower * 5, samples: samples, sampleRate: sampleRate)
            let minimumFifth = lowRegister ? max(0.00006, Double(rms) * 0.030) : Double(rms) * 0.042
            let hasFifth = strength > minimumFifth
                && abs(1200 * log2(fifth / (lower * 5))) < 26
            if !hasFifth {
                guard lowRegister else { return nil }
                let (root, strength) = phaseEstimate(near: lower, samples: samples, sampleRate: sampleRate)
                guard strength > max(0.00006, Double(rms) * 0.028), abs(1200 * log2(root / lower)) < 24 else { return nil }
            }
        }
        let (peak, amplitude) = phaseEstimate(near: frequency, samples: samples, sampleRate: sampleRate)
        let minimumCarrier = lowRegister && weakRoot ? 0.43 : 0.65
        guard amplitude > Double(rms) * minimumCarrier, abs(1200 * log2(peak / frequency)) <= 36 else { return nil }
        let (measured, strength) = phaseEstimate(near: peak * 1.5, samples: samples, sampleRate: sampleRate)
        guard strength > Double(rms) * 0.021, abs(1200 * log2(measured / (peak * 1.5))) <= 30 else { return nil }
        return peak / 2
    }

    private static func partialAmplitude(_ hz: Double, in samples: [Float], sampleRate: Double) -> Double {
        let result = projection(of: samples, from: 0, count: samples.count, hz: hz, sampleRate: sampleRate)
        return 4 * hypot(result.real, result.imaginary) / Double(samples.count - 1)
    }

    private static func projection(of samples: [Float], from offset: Int, count: Int, hz: Double,
                                   sampleRate: Double) -> (real: Double, imaginary: Double) {
        let step = 2 * Double.pi * hz / sampleRate
        let taper = 2 * Double.pi / Double(count - 1)
        var real = 0.0
        var imaginary = 0.0
        for index in 0..<count {
            let frame = offset + index
            let angle = Double(frame) * step
            let weighted = Double(samples[frame]) * (0.5 - 0.5 * cos(Double(index) * taper))
            real += weighted * cos(angle)
            imaginary -= weighted * sin(angle)
        }
        return (real, imaginary)
    }

    private static let pitchFFT = vDSP_create_fftsetup(12, FFTRadix(kFFTRadix2))

    private struct Spectrum {
        let power: [Float]
        let binWidth: Double

        // This fallback is for a nearly pure tone. Motors and playing instruments
        // with several strong lines need independent evidence for their root.
        var isolatedBassPeak: Double? {
            let first = max(2, Int(40 / binWidth))
            let last = min(power.count - 2, Int(82 / binWidth))
            guard first <= last, let bin = (first...last).max(by: { power[$0] < power[$1] }),
                  power[bin] > power[bin - 1], power[bin] >= power[bin + 1] else { return nil }
            let local = power[bin - 1] + power[bin] + power[bin + 1]
            let band = max(1, Int(36 / binWidth))...min(power.count - 1, Int(1800 / binWidth))
            let upper = (2 * bin - 2)...min(power.count - 1, Int(1100 / binWidth))
            guard local > power[band].reduce(0, +) * 0.40,
                  (power[upper].max() ?? 0) < power[bin] * 0.025 else { return nil }
            return frequency(atPeak: bin)
        }

        func frequency(atPeak bin: Int) -> Double {
            let left = log(Double(max(power[bin - 1], 1e-20)))
            let center = log(Double(max(power[bin], 1e-20)))
            let right = log(Double(max(power[bin + 1], 1e-20)))
            let bend = left - 2 * center + right
            let shift = bend < 0 ? min(0.5, max(-0.5, (left - right) / (2 * bend))) : 0
            return (Double(bin) + shift) * binWidth
        }
    }

    private static func spectrum(of samples: [Float], sampleRate: Double) -> Spectrum? {
        guard let setup = pitchFFT else { return nil }
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
        var power = [Float](repeating: 0, count: half)
        for bin in 1..<half { power[bin] = even[bin] * even[bin] + odd[bin] * odd[bin] }
        return Spectrum(power: power, binWidth: sampleRate / Double(count))
    }

    /// When noise masks the repeating waveform, two independently measurable
    /// partials can still identify a string. Derive the pitch from their peaks,
    /// regardless of the note or tuning the user has selected.
    private static func harmonicPitch(in samples: [Float], sampleRate: Double, spectrum: Spectrum) -> Double? {
        let power = spectrum.power
        let width = spectrum.binWidth
        let first = max(2, Int(24 / width))
        let last = min(power.count - 2, Int(4800 / width))
        guard first < last else { return nil }
        let band = power[first...last]
        guard let peak = band.max(), peak > 0 else { return nil }
        let energy = band.reduce(0, +)
        var peaks: [(hz: Double, energy: Float)] = []
        for bin in first...last where power[bin] >= peak * 0.012 {
            guard power[bin] > power[bin - 1], power[bin] >= power[bin + 1] else { continue }
            let energy = power[bin - 1] + power[bin] + power[bin + 1]
            peaks.append((spectrum.frequency(atPeak: bin), energy))
        }
        guard let dominant = peaks.max(by: { $0.energy < $1.energy }) else { return nil }
        // The loudest peak can be a partial of an almost inaudible fundamental.
        // Compare explanations of that same peak, favouring only extra harmonics
        // which a higher candidate cannot explain.
        var best: (pitch: Double, anchor: Int, other: Int, score: Float)?
        for anchor in 1...6 {
            let pitch = dominant.hz / Double(anchor)
            guard (24...1500).contains(pitch) else { continue }
            var score = dominant.energy
            var other: (order: Int, energy: Float)?
            var orders = [anchor]
            for peak in peaks where peak.hz != dominant.hz {
                let order = Int((peak.hz / pitch).rounded())
                guard (1...12).contains(order), !orders.contains(order),
                      abs(1200 * log2(peak.hz / (pitch * Double(order)))) < 24 else { continue }
                orders.append(order)
                score += peak.energy
                if peak.energy > (other?.energy ?? 0) { other = (order, peak.energy) }
            }
            guard let other, score > energy * 0.60, other.energy > score * 0.045 else { continue }
            // Hum plus an unrelated high note can resemble the first and
            // tenth harmonics. Two peaks alone need to be low-order neighbours.
            if orders.count == 2 && max(anchor, other.order) > 4 { continue }
            if !orders.contains(1) {
                guard orders.count >= 3, (2...6).allSatisfy({ divisor in
                    orders.contains { !$0.isMultiple(of: divisor) }
                }) else { continue }
            }
            if score > (best?.score ?? 0) * 1.055 {
                best = (pitch, anchor, other.order, score)
            }
        }
        guard let best else { return nil }
        let anchorOrder = Double(best.anchor)
        let otherOrder = Double(best.other)
        let (anchorHz, amplitude) = phaseEstimate(near: best.pitch * anchorOrder, samples: samples, sampleRate: sampleRate)
        let (otherHz, partialLevel) = phaseEstimate(near: best.pitch * otherOrder, samples: samples, sampleRate: sampleRate)
        guard amplitude > 0.00015, partialLevel > 0.000055,
              abs(1200 * log2(anchorHz / anchorOrder / best.pitch)) < 22,
              abs(1200 * log2(otherHz / otherOrder / (anchorHz / anchorOrder))) < 15 else { return nil }
        return (anchorHz / anchorOrder * amplitude + otherHz / otherOrder * partialLevel) / (amplitude + partialLevel)
    }

    // The normal detector still handles attacks. Use this extra history only
    // on a dropout to distinguish a new low tone from a stationary room sound.
    static let lowToneHistoryDuration = 0.74

    static func sustainedLowTone(_ history: [Float], sampleRate: Double, previous: Double?) -> Double? {
        guard sampleRate >= 8000, history.count >= Int(sampleRate * 0.44),
              (0.00035...0.012).contains(tailLevel(history, sampleRate: sampleRate)) else { return nil }

        let factor = max(1, Int(sampleRate / 6000))
        let rate = sampleRate / Double(factor)
        let count = Int(sampleRate * 0.30) / factor
        let start = history.count - count * factor
        var signal = [Float](repeating: 0, count: count)
        for index in signal.indices {
            let first = start + index * factor
            var sum: Float = 0
            for frame in first..<(first + factor) { sum += history[frame] }
            signal[index] = sum / Float(factor)
        }
        guard let coarse = spectrum(of: signal, sampleRate: rate)?.isolatedBassPeak else { return nil }

        // An oscillator has predictable phase advance across three separate
        // intervals. Check the end again so a fading note cannot keep scoring.
        func measure(from offset: Int, count: Int) -> (angle: Double, strength: Double) {
            let value = projection(of: signal, from: offset, count: count, hz: coarse, sampleRate: rate)
            return (atan2(value.imaginary, value.real), 4 * hypot(value.real, value.imaginary) / Double(count))
        }
        func wrapped(_ angle: Double) -> Double { atan2(sin(angle), cos(angle)) }
        let length = count / 3
        let first = measure(from: 0, count: length)
        let middle = measure(from: length, count: length)
        let last = measure(from: 2 * length, count: length)
        let amplitude = min(first.strength, middle.strength, last.strength)
        let advance = wrapped(last.angle - first.angle)
        let hz = coarse + advance * rate / (4 * .pi * Double(length))
        guard amplitude > 0.00022, amplitude > max(first.strength, middle.strength, last.strength) * 0.36,
              (45...70).contains(hz), abs(wrapped(middle.angle - first.angle - advance / 2)) < 0.66 else { return nil }

        let tailCount = Int(rate * 0.055)
        let tail = measure(from: count - tailCount, count: tailCount)
        let distance = Double(count - tailCount / 2) - Double(length) / 2
        let expectedAngle = first.angle + advance * distance / Double(2 * length)
        guard tail.strength > max(amplitude * 0.50, 0.00021),
              abs(wrapped(tail.angle - expectedAngle)) < 0.72 else { return nil }

        if previous.map({ abs(1200 * log2($0 / hz)) > 40 }) ?? true {
            let interval = Int(rate * 0.13)
            var background = Double.infinity
            for offset in stride(from: 0, through: start - factor * interval, by: interval * factor) {
                let prior = (0..<interval).map { history[offset + $0 * factor] }
                background = min(background, partialAmplitude(hz, in: prior, sampleRate: rate))
            }
            guard amplitude > max(0.00032, background * 2.6) else { return nil }
        }
        for partial in [hz / 2, hz * 1.5] {
            let (measured, strength) = phaseEstimate(near: partial, samples: signal, sampleRate: rate)
            if strength > amplitude * 0.18 && abs(1200 * log2(measured / partial)) < 19 { return nil }
        }
        return hz
    }

    private static func quietHighPitch(_ samples: [Float], sampleRate: Double, periodPitch: Double?, spectrum: Spectrum) -> Double? {
        let binWidth = spectrum.binWidth
        let first = Int(ceil(430 / binWidth))
        let half = spectrum.power.count
        let last = min(half - 2, Int(1600 / binWidth))
        guard first <= last else { return nil }
        func power(_ bin: Int) -> Float { spectrum.power[bin] }
        let peak = (first...last).max { power($0) < power($1) }!
        let localPower = (peak - 1...peak + 1).reduce(Float.zero) { $0 + power($1) }
        let firstBandBin = max(1, Int(230 / binWidth))
        let bandPower = (firstBandBin..<half).reduce(Float.zero) { $0 + power($1) }
        guard localPower > 0, localPower >= bandPower * 0.68 else { return nil }

        let estimate = spectrum.frequency(atPeak: peak)
        let (measured, strength) = phaseEstimate(near: estimate, samples: samples, sampleRate: sampleRate)
        guard strength >= 0.00022, abs(measured - estimate) <= min(4, binWidth * 0.35) else { return nil }

        if (360...1100).contains(measured),
           let lower = octaveBelow(measured, in: samples, sampleRate: sampleRate, rms: Float(strength * 0.7071)) {
            return lower
        }
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

    /// A pluck can outlast a broadband pitch estimate. Measure its actual
    /// partials above their local noise floors, even if the room is louder
    /// elsewhere in the spectrum. Starting a note requires independent partials.
    static func pluckedPitch(in samples: [Float], sampleRate: Double,
                             targets: [Double], continuing previous: Double?) -> Double? {
        let level = Double(tailLevel(samples, sampleRate: sampleRate))
        guard (0.000075...0.004).contains(level),
              let spectrum = spectrum(of: samples, sampleRate: sampleRate) else { return nil }
        let width = spectrum.binWidth
        let upper = min(spectrum.power.count - 2, Int(4000 / width))
        var best: (frequency: Double, power: Float)?
        for root in previous.map({ [$0] }) ?? targets where (48...1600).contains(root) {
            let first = max(1, Int(max(65, root * 0.72) / width))
            guard first < upper else { continue }
            let total = spectrum.power[first...upper].reduce(0, +)
            var partials: [(order: Int, hz: Double, power: Float)] = []
            for order in 1...6 {
                let expected = Double(order) * root
                let radius = max(1, Int(ceil(expected * 0.036 / width)))
                let center = Int((expected / width).rounded())
                let low = max(2, center - radius), high = min(upper, center + radius)
                guard low <= high, let peak = (low...high).max(by: { spectrum.power[$0] < spectrum.power[$1] }),
                      spectrum.power[peak] > spectrum.power[peak-1], spectrum.power[peak] >= spectrum.power[peak+1] else { continue }
                let power = spectrum.power[peak-1...peak+1].reduce(0, +)
                let neighbors = (max(1, peak-7)...min(spectrum.power.count-1, peak+7))
                    .filter { abs($0 - peak) >= 3 }.map { spectrum.power[$0] }.sorted()
                guard power > total * 0.024, spectrum.power[peak] > neighbors[neighbors.count/2] * 12 else { continue }
                let coarse = spectrum.frequency(atPeak: peak)
                let (hz, strength) = phaseEstimate(near: coarse, samples: samples, sampleRate: sampleRate)
                guard strength >= max(0.000032, level * 0.095), abs(hz - coarse) <= width * 0.30,
                      abs(1200 * log2(hz / expected)) <= 60 else { continue }
                partials.append((order, hz / Double(order), power))
            }
            guard let strongest = partials.max(by: { $0.power < $1.power }) else { continue }
            let agreeing = partials.filter { abs(1200 * log2($0.hz / strongest.hz)) <= 12 }
            let power = agreeing.reduce(Float.zero) { $0 + $1.power }
            if previous == nil {
                // Two or more components must establish this root, rather than
                // just the even harmonics of a different string.
                guard agreeing.count >= 2, power > total * 0.35,
                      !(2...6).contains(where: { divisor in agreeing.allSatisfy { $0.order.isMultiple(of: divisor) } }) else { continue }
            } else if power <= total * 0.095 {
                continue
            }
            if power > (best?.power ?? 0) {
                let measured = agreeing.reduce(0) { $0 + $1.hz * Double($1.power) } / Double(power)
                best = (measured, power)
            }
        }
        return best?.frequency
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
        if (120...1100).contains(measured), octaveBelow(measured, in: samples, sampleRate: sampleRate, rms: Float(level), chromatic: true) != nil {
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
        let early = projection(of: samples, from: 0, count: half, hz: hz, sampleRate: sampleRate)
        let late = projection(of: samples, from: half, count: half, hz: hz, sampleRate: sampleRate)
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

enum ChromaticTuningRange: String, CaseIterable {
    case relaxed, standard, precise

    static let preferenceKey = "tuner.chromaticRange"

    var cents: Double {
        switch self {
        case .relaxed: 10
        case .standard: 6
        case .precise: 2
        }
    }

    var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .standard: "Standard"
        case .precise: "Precise"
        }
    }
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
                       stabilizeChromaticPitch: Bool = false,
                       chromaticRange: ChromaticTuningRange = .standard, measuredFromDecay: Bool = false) -> TunerReading? {
        if let pluckLevel {
            let newAttack = stringRecheck.measure(level: pluckLevel, unpitched: hz == nil, at: time)
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
            let center = chromaticCenter.observe(raw, displayedCents: cents, at: time,
                                                 dwell: response.dwell, tolerance: chromaticRange.cents,
                                                 measuredFromDecay: measuredFromDecay)
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
        chromaticCenter.pause(at: time)
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
                          dwell: TimeInterval, tolerance: Double, measuredFromDecay: Bool) -> (locked: Bool, duration: TimeInterval) {
        // A large departure overrides the hold for brief, near-center fluctuations.
        let immediateExit = tolerance + 8
        if abs(cents) >= immediateExit || abs(displayedCents) >= immediateExit {
            self = ChromaticCenter()
            return (false, 0)
        }
        if measuredFromDecay {
            // A fading string still has a measurable pitch. It cannot earn
            // a new confirmation or extend the sustain lamp by itself.
            let recentlyMeasured = samples.last.map { time - $0.time < 0.096 } == true
            if !recentlyMeasured || abs(cents) > tolerance || abs(displayedCents) > tolerance {
                self = ChromaticCenter()
            } else {
                pause(at: time)
            }
            return (locked, duration)
        }
        let start = time - dwell
        if let last = samples.last, time <= last.time { return (locked, duration) }
        samples.append(Sample(time: time, cents: cents))
        while samples.count > 1 && samples[1].time <= start { samples.removeFirst() }

        // Integrate by time, since audio callbacks need not arrive at a fixed interval.
        var sum = 0.0
        var squareSum = 0.0
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
            variation += abs(later.cents - first)
            if firstCents == nil { firstCents = first }
        }
        let fullWindow = samples.count >= 3 && samples[0].time <= start
        let mean = sum / dwell
        // Measure steadiness around the sung pitch, independently of its tuning offset.
        let spread = sqrt(max(0, squareSum / dwell - mean * mean))
        let drift = abs(cents - (firstCents ?? cents))
        let gliding = drift > 1.5 && drift > variation * 0.75
        // Allow round-off at an exact mathematical boundary.
        let limit = tolerance + 1e-8
        let meanInRange = abs(mean) <= limit
        let slotInRange = abs(displayedCents) <= limit
        let onCenter = fullWindow && meanInRange && slotInRange && spread <= 6.5 && !gliding
        if locked {
            // A transient excursion can hold the existing lamp, but sustained
            // drift must leave green at the chosen limit in either direction.
            let unstable = fullWindow && (!meanInRange || spread > 8.5 || gliding && !slotInRange)
            if fullWindow && !unstable { lastStableAt = time }
            if unstable {
                awaySince = awaySince ?? time
            } else {
                awaySince = nil
            }
            let driftingAway = awaySince.map { time - $0 >= 0.10 } ?? false
            let noStableWindow = lastStableAt.map { time - $0 > dwell + 0.16 } ?? false
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

    mutating func pause(at time: TimeInterval) {
        // An already confirmed note can survive one missing analysis hop.
        // No new lock or sustain time can be earned during that interruption.
        let briefGap = samples.last.map { time - $0.time <= 0.05 } ?? false
        if !locked || !briefGap {
            samples.removeAll(keepingCapacity: true)
            awaySince = nil
        }
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

    private var background: Float = 0.00012
    private var onsetLevel: Float { max(0.00055, background * 3) }
    private var previousLevel: Float = 0
    private var quietSince: TimeInterval?
    private var level: Float = 0
    private var peak: Float = 0
    private var attackAt: TimeInterval?
    private var evidence: Evidence?

    mutating func measure(level: Float, unpitched: Bool, at time: TimeInterval) -> Bool {
        // Learn the room between notes. A missed attack must not immediately
        // become the new noise floor, particularly for soft bowed notes.
        let nearAttack = attackAt.map { time - $0 <= 0.90 } ?? false
        if unpitched && !nearAttack {
            background += 0.08 * (min(level, background * 2) - background)
        }
        if level <= max(0.00032, background * 1.6), quietSince == nil { quietSince = time }
        let rest = quietSince.map { time - $0 >= 0.09 } ?? false
        let rising = level > previousLevel * 1.5 && level - previousLevel >= max(0.00035, background * 1.5)
        let newAttack = level >= onsetLevel && (rising || rest)
        if newAttack {
            attackAt = time
            peak = 0
            evidence = nil
        }
        if level >= onsetLevel { quietSince = nil }
        previousLevel = level
        self.level = level
        return newAttack
    }

    mutating func observe(note: Int, rawCents: Double, centered: Bool, at time: TimeInterval) -> Bool {
        guard let attackAt else { return false }
        let attackAge = time - attackAt
        // Judge decay against the pitched part of this attack. The click of
        // the pick or a nearby impact can be much louder than the note.
        peak = max(peak, level)
        let completing = evidence.map { time - $0.last <= 0.145 } ?? false
        if attackAge > 0.90 || (attackAge > 0.65 && !completing) || level < max(background * 2, peak * 0.33) {
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
        // A device can deliver nominal 100 ms buffers just over 100 ms apart.
        // Still require an uninterrupted run of consistent, same-sided pitch.
        if var evidence, evidence.note == note, time - evidence.last <= 0.145,
           abs(rawCents - evidence.cents) <= 11 {
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
