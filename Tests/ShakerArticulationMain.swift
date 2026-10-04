import Foundation
import AVFoundation

@main struct ShakerArticulationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let library = try AcousticLibrary { root.appendingPathComponent("TheMetronome/AcousticSamples/\($0).wav") }
        for rate in [44100.0, 48000.0, 96000.0] {
            // All four takes: preserve slow strokes exactly; dry out before the next fast hit.
            for interval: Double in [0.625, 0.3125, 0.25, 0.125, 60/180/4, 0.0625, 60/300/6] {
                let old = AcousticRenderer(library: library), new = AcousticRenderer(library: library)
                for _ in 0..<4 {
                    old.trigger(sound: 10, strength: 2)
                    new.trigger(sound: 10, strength: 2, hitInterval: interval)
                    var oldTail = 0.0, newTail = 0.0, energy = 0.0
                    for i in 0..<Int(rate * 0.8) {
                        let a = old.sample(rate: rate), b = new.sample(rate: rate)
                        let time = Double(i)/rate
                        precondition(b.isFinite && abs(b) < 1)
                        if interval >= 0.3125 || time < 0.005 { precondition(a == b, "Slow stroke or attack changed") }
                        if interval < 0.3125 && time >= interval * 0.9 + 1/rate { precondition(b == 0, "Tail overlaps next stroke") }
                        if time >= interval * 0.5 { oldTail += Double(a*a); newTail += Double(b*b) }
                        energy += Double(b*b)
                    }
                    precondition(energy > 0, "Fast shaker became silent")
                    if interval < 0.3125 { precondition(newTail < oldTail, "Tail energy not reduced") }
                }
            }
            // Catch an existing long voice when the user suddenly increases speed.
            let live = AcousticRenderer(library: library), reference = AcousticRenderer(library: library)
            live.trigger(sound: 10, strength: 2, hitInterval: 0.625)
            reference.trigger(sound: 10, strength: 2)
            for _ in 0..<Int(rate * 0.8) { _ = reference.sample(rate: rate) }
            for _ in 0..<Int(rate * 0.05) { _ = live.sample(rate: rate) }
            live.trigger(sound: 10, strength: 1, hitInterval: 0.0625)
            reference.trigger(sound: 10, strength: 1, hitInterval: 0.0625)
            for i in 0..<Int(rate * 0.3) {
                let a = live.sample(rate: rate), b = reference.sample(rate: rate)
                if Double(i)/rate > 0.009 { precondition(a == b, "Old stroke survives live speed change") }
            }
            // Tempo-sensitive processing must not touch any other recording.
            for sound in [0,2,5,8,9,11] {
                let a = AcousticRenderer(library: library), b = AcousticRenderer(library: library)
                a.trigger(sound: sound, strength: 2)
                b.trigger(sound: sound, strength: 2, hitInterval: 0.033333)
                for _ in 0..<Int(rate * 0.8) { precondition(a.sample(rate: rate) == b.sample(rate: rate)) }
            }
        }
        // The renderer receives current ramp tempo and subdivision, never stale UI BPM.
        var r = Rhythm(); r.sound = 10; r.subdivision = 4; r.ramp = true
        r.start = 120; r.end = 180; r.increment = 60; r.every = 1
        let clock = SampleClock(rate: 48000); clock.reset(r)
        var tempos = Set<Int>()
        for _ in 0..<192000 {
            if let (e, _) = clock.advance() {
                precondition(abs(e.hitInterval - 60/Double(e.bpm * r.subdivision)) < 1e-12)
                tempos.insert(e.bpm)
            }
        }
        precondition(tempos == [120,180])
        print("PASS: shaker slow identity, all 4 takes × 7 densities × 3 rates, fast tail clearance, live speed change, other instruments unchanged, ramp interval propagation.")
        // Actual renderer comparison: old/new at 180 BPM, then old/new at 240 BPM; four clicks.
        let rate = 48000.0
        var samples: [Float] = []
        for bpm in [180,240] {
            for adaptive in [false,true] {
                var r = Rhythm(); r.sound = 10; r.bpm = bpm; r.subdivision = 4
                let clock = SampleClock(rate: rate); clock.reset(r, barLimit: 2)
                let renderer = AcousticRenderer(library: library)
                for _ in 0..<Int(rate * (8 * 60 / Double(bpm) + 0.5)) {
                    if let (e, strength) = clock.advance() {
                        renderer.trigger(sound: 10, strength: strength, gainScale: e.gainScale,
                            hitInterval: adaptive ? e.hitInterval : .infinity)
                    }
                    samples.append(renderer.sample(rate: rate))
                }
            }
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        let url = root.appendingPathComponent("Design/Audio/shaker-density-before-after.wav")
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        print("AUDITION: \(url.path): 180 BPM old/new, then 240 BPM old/new; two bars each.")
    }
}
