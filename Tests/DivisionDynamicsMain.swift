import Foundation
import AVFoundation

/// Uses the same clock, recordings and electronic voice as the phone renderer.
@main struct DivisionDynamicsTests {
    static func patterns() -> [(String, Rhythm)] {
        var result: [(String, Rhythm)] = []
        for division in [1,2,3,4] {
            var r = Rhythm(); r.subdivision = division
            result.append(("4-4 division \(division)", r))
        }
        for division in [1,2,3,6] {
            var r = Rhythm(); r.setMeter(beats: 6, denominator: 8, compound: true); r.subdivision = division
            result.append(("6-8 big beats division \(division)", r))
        }
        for division in [1,2,3,4] {
            var r = Rhythm(); r.setMeter(beats: 6, denominator: 8, compound: false); r.subdivision = division
            result.append(("6-8 note units division \(division)", r))
        }
        return result
    }
    static func render(_ r: Rhythm, rate: Double, library: AcousticLibrary, oldDynamics: Bool = false) -> [Float] {
        let clock = SampleClock(rate: rate); clock.reset(r, barLimit: 1)
        let acoustic = AcousticRenderer(library: library)
        var voices = Array(repeating: ClickVoice(), count: 4), cursor = 0
        let length = Int(ceil(rate * (Double(r.pulseCount) * 60 / Double(r.bpm) + 0.8)))
        var result = Array(repeating: Float(0), count: length), hits = 0
        for frame in 0..<length {
            if let (e, strength) = clock.advance() {
                hits += 1
                if strength > 0 {
                    let gain: Float = oldDynamics ? 1 : e.gainScale
                    acoustic.chokeHats()
                    if r.sound == 1 {
                        voices[cursor % 4].trigger(sound: 1, strength: strength, gainScale: gain); cursor += 1
                    } else {
                        acoustic.trigger(sound: r.sound, strength: strength, beat: e.beat, beats: r.pulseCount,
                            denominator: r.denominator, counting: e.countIn, gainScale: gain)
                    }
                }
            }
            var sample = acoustic.sample(rate: rate)
            for i in voices.indices { sample += voices[i].sample(rate: rate) }
            precondition(sample.isFinite && abs(sample) < 1, "Invalid or clipping audio: \(r.sound), \(r.subdivision)")
            result[frame] = sample
        }
        precondition(hits == r.pulseCount * r.subdivision)
        precondition(result.suffix(Int(rate * 0.05)).allSatisfy { $0 == 0 }, "Unfinished sample tail")
        return result
    }
    static func write(_ samples: [Float], to url: URL, rate: Double) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        do { try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false).write(from: buffer) }
        let readback = try AVAudioFile(forReading: url)
        precondition(readback.length == samples.count)
    }
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let library = try AcousticLibrary { root.appendingPathComponent("TheMetronome/AcousticSamples/\($0).wav") }
        // Assert the actual renderer applies level scaling to every sample, not just the model.
        for sound in InstrumentSound.allCases {
            for rate in [44100.0,48000.0,96000.0] {
                let a = AcousticRenderer(library: library), b = AcousticRenderer(library: library)
                var clickA = ClickVoice(), clickB = ClickVoice()
                for strength in [2,1,4,3,5] {
                    for scale: Float in [0.35,0.5833333,0.89,0.945,1.02] {
                        if sound == .click {
                            clickA.trigger(sound: 1, strength: strength)
                            clickB.trigger(sound: 1, strength: strength, gainScale: scale)
                        } else {
                            a.trigger(sound: sound.rawValue, strength: strength)
                            b.trigger(sound: sound.rawValue, strength: strength, gainScale: scale)
                        }
                        for _ in 0..<Int(rate * 0.8) {
                            let x = sound == .click ? clickA.sample(rate: rate) : a.sample(rate: rate)
                            let y = sound == .click ? clickB.sample(rate: rate) : b.sample(rate: rate)
                            precondition(abs(y - x * scale) < 0.000001, "Gain not propagated to \(sound.title)")
                        }
                    }
                }
            }
        }
        var count = 0, peak: Float = 0
        for sound in InstrumentSound.allCases {
            for rate in [44100.0,48000.0,96000.0] {
                for (_, pattern) in patterns() {
                    for accent in [true,false] {
                        var r = pattern; r.sound = sound.rawValue; r.bpm = 300; r.followsMeter = accent
                        let audio = render(r, rate: rate, library: library)
                        peak = max(peak, audio.map(abs).max() ?? 0); count += 1
                    }
                }
            }
        }
        print("PASS: gain applied sample-by-sample to all 8 instruments, 5 roles × 5 scales × 3 sample rates.")
        print("PASS: \(count) dense rendered bars across 8 instruments, 12 grids, ACCENT/EVEN and 44.1/48/96 kHz; peak \(peak); exact hit counts; no clipping; complete tails.")
        guard CommandLine.arguments.contains("--auditions") else { return }
        let output = root.appendingPathComponent("Design/Audio/division-dynamics")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let rate = 48000.0
        var chapters: [[String: Any]] = []
        for sound in InstrumentSound.allCases {
            var samples: [Float] = []
            for (name, pattern) in patterns().prefix(8) {
                var r = pattern; r.sound = sound.rawValue
                if sound == .wood { chapters.append(["name":name,"seconds":Double(samples.count)/rate]) }
                samples += render(r, rate: rate, library: library)
            }
            let filename = "\(sound.rawValue)-\(sound.title.lowercased()).wav"
            try write(samples, to: output.appendingPathComponent(filename), rate: rate)
            print("AUDITION: \(filename), \(Double(samples.count)/rate) seconds")
        }
        var ab: [Float] = []
        for index in [3,7] {
            var r = patterns()[index].1; r.sound = 11
            ab += render(r, rate: rate, library: library, oldDynamics: true)
            ab += render(r, rate: rate, library: library)
        }
        try write(ab, to: output.appendingPathComponent("hi-hat-before-after.wav"), rate: rate)
        try JSONSerialization.data(withJSONObject: chapters, options: [.prettyPrinted,.sortedKeys]).write(to: output.appendingPathComponent("chapters.json"))
    }
}
