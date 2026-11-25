// swiftc -O TheMetronome/TunerPitch.swift Tests/TunerAccuracy/main.swift -o /tmp/tuner-accuracy
// /tmp/tuner-accuracy > accuracy.csv
import Foundation

enum Wave: String, CaseIterable {
    case sine, triangle, saw, square

    func wavetable(harmonics: Int) -> [Double] {
        let size = 2048
        var table = [Double](repeating: 0, count: size + 1)
        for harmonic in 1...harmonics {
            let n = Double(harmonic)
            let gain: Double
            switch self {
            case .sine: gain = harmonic == 1 ? 1 : 0
            case .saw: gain = 1 / n
            case .square: gain = harmonic.isMultiple(of: 2) ? 0 : 1 / n
            case .triangle: gain = harmonic.isMultiple(of: 2) ? 0 : (harmonic % 4 == 1 ? 1 : -1) / (n * n)
            }
            guard gain != 0 else { continue }
            for i in 0..<size {
                table[i] += gain * sin(2 * .pi * Double(i) * n / Double(size))
            }
        }
        let rms = sqrt(table.prefix(size).reduce(0) { $0 + $1 * $1 } / Double(size))
        for i in 0..<size { table[i] /= rms }
        table[size] = table[0]
        return table
    }
}

func samples(wavetable: [Double], hz: Double, rate: Double, count: Int, level: Double) -> [Float] {
    let length = Double(wavetable.count - 1)
    return (0..<count).map { frame in
        let phase = (0.137 + Double(frame) * hz / rate).truncatingRemainder(dividingBy: 1) * length
        let i = Int(phase)
        let fraction = phase - Double(i)
        return Float(level * (wavetable[i] + (wavetable[i + 1] - wavetable[i]) * fraction))
    }
}

var absoluteErrors: [String: [Double]] = [:]
var caseCounts: [String: Int] = [:]
print("mode,wave,sample_rate,midi,detune_cents,rms,error_cents")
for wave in Wave.allCases {
    let tables = (1...24).map { wave.wavetable(harmonics: $0) }
    for rate in [44_100.0, 48_000.0] {
        for note in 23...96 {
            for detune in [-17.0, 0, 17] {
                let hz = TunerPitch.frequency(note, reference: 440) * pow(2, detune / 1200)
                let harmonics = min(tables.count, Int(rate / (2 * hz)))
                for level in [0.0007, 0.025] {
                    let count = Int(rate * (hz < 70 ? 0.144 : 0.096))
                    let pcm = samples(wavetable: tables[harmonics - 1], hz: hz, rate: rate, count: count, level: level)
                    for chromatic in [true, false] {
                        let mode = chromatic ? "chromatic" : "instrument"
                        caseCounts[mode, default: 0] += 1
                        let measured = TunerPitch.detect(pcm, sampleRate: rate, chromatic: chromatic)
                        let error = measured.map { 1200 * log2($0 / hz) }
                        if let error { absoluteErrors[mode, default: []].append(abs(error)) }
                        let value = error.map { String(format: "%.4f", $0) } ?? ""
                        print("\(mode),\(wave.rawValue),\(Int(rate)),\(note),\(detune),\(level),\(value)")
                    }
                }
            }
        }
    }
}

// A missed note cannot disappear from the denominator. The precision and
// coverage gates apply to these generated signals with known frequencies.
var passed = true
for mode in caseCounts.keys.sorted() {
    let errors = absoluteErrors[mode, default: []].sorted()
    let total = caseCounts[mode, default: 0]
    let index = max(0, Int(ceil(0.95 * Double(errors.count))) - 1)
    let p95 = errors.isEmpty ? Double.infinity : errors[index]
    let worst = errors.last ?? Double.infinity
    let report = String(format: "%@: %d/%d reads, P95 %.3f cents, worst %.3f cents\n", mode, errors.count, total, p95, worst)
    FileHandle.standardError.write(Data(report.utf8))
    if errors.count != total || p95 > 1 || worst > 5 { passed = false }
}
if !passed { exit(1) }
