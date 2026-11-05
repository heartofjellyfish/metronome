import Foundation
import AVFoundation

@main struct StageClickAudition {
    static func main() throws {
        let rate = 48000.0
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        var rhythm = Rhythm(); rhythm.bpm = 120; rhythm.sound = 16; rhythm.followsMeter = true
        let clock = SampleClock(rate: rate); clock.reset(rhythm, barLimit: 2)
        var voices = Array(repeating: ClickVoice(), count: 4), cursor = 0
        let count = Int(rate * 4.5)
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        var peak: Float = 0
        for frame in 0..<count {
            if let (event, strength) = clock.advance(), strength > 0 {
                voices[cursor % 4].trigger(sound: 16, strength: strength, gainScale: event.gainScale); cursor += 1
            }
            var sample: Float = 0
            for i in voices.indices { sample += voices[i].sample(rate: rate) }
            precondition(sample.isFinite && abs(sample) < 1)
            peak = max(peak, abs(sample)); buffer.floatChannelData![0][frame] = sample
        }
        precondition(cursor == 8)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false).write(from: buffer)
        print("\(output.lastPathComponent): 120 BPM, two bars, peak \(peak), original playback gain")
    }
}
