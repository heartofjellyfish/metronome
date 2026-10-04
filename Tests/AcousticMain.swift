import Foundation
import AVFoundation
@main struct AcousticTests {
    static func check(_ value: Bool, _ message: String) { precondition(value, message) }
    static func main() throws {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("TheMetronome/AcousticSamples")
        let library = try AcousticLibrary { directory.appendingPathComponent($0 + ".wav") }
        check(library.clips.count == 33, "All recorded variants must be bundled")
        let pattern = [2, 1, 1, 1].enumerated().map {
            HatArticulation.resolve(strength: $0.element, beat: $0.offset, beats: 4, denominator: 4)
        }
        check(pattern.map(\.air) == [false, false, false, false], "All beats must stay closed, including the downbeat")
        check(pattern[0].gain > pattern[2].gain && pattern[2].gain > pattern[1].gain && pattern[1].gain == pattern[3].gain, "4/4 must be strong / weak / secondary / weak")
        check(pattern[0].gain / pattern[1].gain > 2, "The first beat must have a clearly audible level advantage")
        check(!HatArticulation.resolve(strength: 1, beat: 0, beats: 4, denominator: 4).air, "An unaccented downbeat stays closed")
        check(!HatArticulation.resolve(strength: 2, beat: 2, beats: 4, denominator: 4).air, "A manual accent away from one stays closed")
        check(!HatArticulation.resolve(strength: 2, beat: 0, beats: 4, denominator: 4, counting: true).air, "Count-in stays closed")
        check(HatArticulation.resolve(strength: 0, beat: 2, beats: 4, denominator: 4).gain == 0, "A muted secondary beat stays silent")
        check(!HatArticulation.resolve(strength: 3, beat: 0, beats: 4, denominator: 4).air, "Subdivisions stay closed")
        let compound = (0..<6).map { HatArticulation.resolve(strength: 1, beat: $0, beats: 6, denominator: 8).gain }
        check(compound[3] > compound[2] && compound[3] > compound[4], "6/8 gently marks the second group")
        let odd = (0..<7).map { HatArticulation.resolve(strength: 1, beat: $0, beats: 7, denominator: 8).gain }
        check(Set(odd).count == 1, "Irregular meters must retain the user's own grouping")
        // Measure real rendered attacks across every round-robin phase, including
        // the stronger closed recordings; nominal gains alone do not guarantee dynamics.
        for rate in [44100.0, 48000.0, 96000.0] {
            for phase in 0..<4 {
                let renderer = AcousticRenderer(library: library)
                for _ in 0..<phase {
                    renderer.trigger(sound: 11, strength: 1)
                    for _ in 0..<Int(rate * 0.3) { _ = renderer.sample(rate: rate) }
                }
                var levels: [Double] = []
                for beat in 0..<4 {
                    renderer.chokeHats()
                    renderer.trigger(sound: 11, strength: beat == 0 ? 2 : 1, beat: beat)
                    var energy = 0.0
                    for frame in 0..<Int(rate * 0.3) {
                        let sample = Double(renderer.sample(rate: rate))
                        if frame < Int(rate * 0.05) { energy += sample * sample }
                    }
                    levels.append(10 * log10(energy / Double(Int(rate * 0.05))))
                }
                check(levels[0] - levels[2] > 3.5, "Rendered beat one must exceed beat three")
                check((2.2...3.2).contains(levels[2] - max(levels[1], levels[3])), "Secondary beat should sit about 2.7 dB above the weak beats")
                check(abs(levels[1] - levels[3]) < 0.3, "Round-robin recordings must not disturb the weak-beat balance")
                if rate == 44100 { print("4/4 attack dB, take phase \(phase): \(levels.map { String(format: "%.2f", $0) })") }
            }
        }
        for sound in [0,2,5,8,9,10,11] {
            for even in [false, true] {
                let renderer = AcousticRenderer(library: library)
                var levels: [Double] = []
                for beat in 0..<4 {
                    renderer.chokeHats()
                    renderer.trigger(sound: sound, strength: even ? 5 : [2,1,4,1][beat], beat: beat)
                    var energy = 0.0
                    for frame in 0..<30000 {
                        let sample = Double(renderer.sample(rate: 48000))
                        if frame < 2400 { energy += sample * sample }
                    }
                    levels.append(10 * log10(energy / 2400))
                }
                if even { check(levels.max()! - levels.min()! < 0.3, "Every acoustic sound must have even rendered attacks") }
                else { check(levels[0] > levels[2] + 1.8 && levels[2] > max(levels[1], levels[3]) + 2.2, "Every acoustic sound must render the meter hierarchy") }
            }
        }
        var largest: Float = 0
        for rate in [44100.0, 48000.0, 96000.0] {
            for sound in [0,2,5,8,9,10,11] {
                let renderer = AcousticRenderer(library: library)
                var rhythm = Rhythm(); rhythm.bpm = 300; rhythm.subdivision = 4; rhythm.sound = sound
                let clock = SampleClock(rate: rate); clock.reset(rhythm)
                var energy: Double = 0
                for frame in 0..<Int(rate * 2) {
                    if frame < Int(rate), let (event, strength) = clock.advance(), strength > 0 {
                        renderer.chokeHats(); renderer.trigger(sound: sound, strength: strength, beat: event.beat, beats: rhythm.beats, denominator: rhythm.denominator, counting: event.countIn)
                    }
                    let sample = renderer.sample(rate: rate)
                    check(sample.isFinite && abs(sample) < 1, "Recorded mix clips or contains invalid samples")
                    energy += Double(sample * sample); largest = max(largest, abs(sample))
                    if frame > Int(rate * 1.8) { check(sample == 0, "Recorded tails must terminate") }
                }
                check(energy > 0.1, "Recorded sound is silent")
            }
        }
        let hats = AcousticRenderer(library: library); hats.trigger(sound: 7, strength: 2)
        for _ in 0..<2000 { _ = hats.sample(rate: 48000) }
        hats.chokeHats()
        for _ in 0..<150 { _ = hats.sample(rate: 48000) }
        check(hats.sample(rate: 48000) == 0, "Acoustic hats must choke in 3 ms")
        let rounds = AcousticRenderer(library: library)
        var signatures: [Double] = []
        for _ in 0..<4 {
            rounds.trigger(sound: 6, strength: 1)
            var signature = 0.0
            for _ in 0..<11000 { let s = Double(rounds.sample(rate: 44100)); signature += s*s }
            signatures.append(signature)
        }
        check(Set(signatures).count == 4, "Round robin must use four different recordings")
        print("PASS: all 33 recordings load; seven acoustic sounds at 44.1/48/96 kHz; 300 BPM subdivisions; peak \(largest); tail termination; choke; four distinct takes.")
        for (sound, name) in [(0,"acoustic-wood"),(2,"acoustic-bell"),(5,"acoustic-rimshot"),(8,"acoustic-pedal"),(9,"acoustic-stick"),(10,"acoustic-shaker"),(11,"recommended-hi-hat")] {
            let renderer = AcousticRenderer(library: library)
            let rate = 44100.0; var rhythm = Rhythm(); rhythm.bpm = 96; rhythm.subdivision = 2
            let clock = SampleClock(rate: rate); clock.reset(rhythm)
            let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
            let count = Int(rate * 5.65)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!; buffer.frameLength = AVAudioFrameCount(count)
            for frame in 0..<count {
                if frame < Int(rate * 5), let (event, strength) = clock.advance(), strength > 0 {
                    renderer.chokeHats(); renderer.trigger(sound: sound, strength: strength, beat: event.beat, beats: rhythm.beats, denominator: rhythm.denominator, counting: event.countIn)
                }
                buffer.floatChannelData![0][frame] = renderer.sample(rate: rate)
            }
            let file = try AVAudioFile(forWriting: URL(fileURLWithPath: "Design/Audio/\(name).wav"), settings: format.settings)
            try file.write(from: buffer)
        }
        // Same runtime clock and acoustic renderer: two EVEN bars, then two METER bars.
        let abRate = 44100.0
        let abFormat = AVAudioFormat(standardFormatWithSampleRate: abRate, channels: 1)!
        let barFrames = Int(abRate * 2.5)
        let abCount = barFrames * 4 + Int(abRate * 0.3)
        let abBuffer = AVAudioPCMBuffer(pcmFormat: abFormat, frameCapacity: AVAudioFrameCount(abCount))!
        abBuffer.frameLength = AVAudioFrameCount(abCount)
        let abRenderer = AcousticRenderer(library: library)
        var abRhythm = Rhythm(); abRhythm.sound = 11; abRhythm.subdivision = 2; abRhythm.followsMeter = false
        let abClock = SampleClock(rate: abRate); abClock.reset(abRhythm)
        for frame in 0..<abCount {
            if frame == barFrames * 2 { abRhythm.followsMeter = true; abClock.update(abRhythm) }
            if frame < barFrames * 4, let (event, strength) = abClock.advance() {
                abRenderer.chokeHats(); abRenderer.trigger(sound: 11, strength: strength, beat: event.beat)
            }
            abBuffer.floatChannelData![0][frame] = abRenderer.sample(rate: abRate)
        }
        try AVAudioFile(forWriting: URL(fileURLWithPath: "Design/Audio/dynamics-comparison.wav"), settings: abFormat.settings).write(from: abBuffer)
        print("Rendered seven previews using the exact runtime sample engine.")
    }
}
