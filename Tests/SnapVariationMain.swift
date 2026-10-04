import Foundation
import AVFoundation

@main struct SnapVariationTests {
    static func main() throws {
        for seed: UInt64 in [0,1,42,0x534E4150,UInt64.max] {
            var picker = RecordedTakeSequence(seed: seed)
            var sequence: [Int] = []
            for _ in 0..<1024 { sequence.append(picker.next()) }
            for (a,b) in zip(sequence,sequence.dropFirst()) { precondition(a != b, "Adjacent snap repeated") }
            for start in stride(from: 0, to: sequence.count, by: 4) {
                precondition(Set(sequence[start..<start+4]) == Set(0..<4), "A shuffled bag must contain every real take")
            }
            for meterLength in [4,8,12,16,24] {
                for phase in 0..<meterLength {
                    let values = stride(from: phase, to: sequence.count, by: meterLength).map { sequence[$0] }
                    precondition(Set(values).count == 4, "Snap locked to a metrical position")
                }
            }
        }
        let library = try AcousticLibrary { URL(fileURLWithPath: "TheMetronome/AcousticSamples/\($0).wav") }
        let renderer = AcousticRenderer(library: library)
        var signatures = Set<Double>(), levels: [Double] = []
        for _ in 0..<4 {
            renderer.trigger(sound: 12, strength: 5)
            var energy = 0.0, signature = 0.0
            for i in 0..<22050 {
                let sample = renderer.sample(rate: 44100)
                precondition(sample.isFinite && abs(sample) < 1)
                if i < 2205 { energy += Double(sample*sample) }
                signature += Double(sample) * Double(i % 97)
            }
            signatures.insert(signature); levels.append(10*log10(energy/2205))
        }
        precondition(signatures.count == 4, "All four distinct recordings must reach the output")
        precondition(levels.max()! - levels.min()! < 0.3, "Take variation must not overpower metrical dynamics")
        print("PASS: 5 seeds × 1024 hits; no adjacent repeats; all 4 takes per bag; no metrical lock at 4/8/12/16/24 hits; 4 unique rendered strokes with balanced attacks.")
    }
}
