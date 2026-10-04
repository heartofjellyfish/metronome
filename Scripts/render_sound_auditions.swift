import Foundation
import AVFoundation

@main struct SoundAuditions {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("Design/Audio/curated-acoustic")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let library = try AcousticLibrary { root.appendingPathComponent("TheMetronome/AcousticSamples/\($0).wav") }
        let names = ["01-classic", "02-click", "03-bell", "04-synth-hat", "05-synth-shaker", "06-rimshot", "07-acoustic-closed", "08-acoustic-open", "09-pedal", "10-sticks", "11-acoustic-shaker", "12-hi-hat"]
        let rate = 48000.0
        let activeFrames = Int(rate * 10) // Four bars at 96 BPM, 4/4.
        let count = activeFrames + Int(rate * 0.65)
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        for sound in InstrumentSound.allCases {
            var rhythm = Rhythm()
            rhythm.sound = sound.rawValue; rhythm.followsMeter = true
            rhythm.bpm = 96; rhythm.beats = 4; rhythm.denominator = 4; rhythm.subdivision = 1
            rhythm.countIn = 0; rhythm.ramp = false; rhythm.gap = false
            let clock = SampleClock(rate: rate); clock.reset(rhythm)
            let acoustic = AcousticRenderer(library: library)
            var voices = Array(repeating: ClickVoice(), count: 4)
            var cursor = 0
            var ticks = 0
            var peak: Float = 0
            var strengths: [Int] = []
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
            buffer.frameLength = AVAudioFrameCount(count)
            for frame in 0..<count {
                if frame < activeFrames, let (event, strength) = clock.advance() {
                    ticks += 1; strengths.append(strength)
                    for i in voices.indices { voices[i].chokeHat() }
                    acoustic.chokeHats()
                    if sound != .click {
                        acoustic.trigger(sound: sound.rawValue, strength: strength, beat: event.beat, beats: 4, denominator: 4)
                    } else {
                        voices[cursor].trigger(sound: sound.rawValue, strength: strength)
                        cursor = (cursor + 1) % voices.count
                    }
                }
                var value = acoustic.sample(rate: rate)
                for i in voices.indices { value += voices[i].sample(rate: rate) }
                precondition(value.isFinite && abs(value) < 1, "Invalid audio")
                peak = max(peak, abs(value))
                buffer.floatChannelData![0][frame] = value
            }
            precondition(ticks == 16 && strengths == Array(repeating: [2,1,4,1], count: 4).flatMap { $0 })
            precondition(peak > 0 && buffer.floatChannelData![0][count - 1] == 0)
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
            let url = output.appendingPathComponent(names[sound.rawValue] + ".wav")
            do {
                let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
                try file.write(from: buffer)
            }
            let readback = try AVAudioFile(forReading: url)
            precondition(readback.length == count && readback.processingFormat.sampleRate == rate)
            print("\(url.lastPathComponent): 16 beats, 4/4, 96 BPM, peak \(peak), verified PCM16")
        }
    }
}
