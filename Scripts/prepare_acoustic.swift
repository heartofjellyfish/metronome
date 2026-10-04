import Foundation
import AVFoundation
struct Source: Codable { let name: String; let source: String; let url: String; let sha256: String; let local: String }
let sources = try JSONDecoder().decode([Source].self, from: Data(contentsOf: URL(fileURLWithPath: "/tmp/metronome-acoustic-source/manifest.json")))
var manifest: [[String: Any]] = []
for entry in sources {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: entry.local), commonFormat: .pcmFormatFloat32, interleaved: false)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    let frames = Int(buffer.frameLength), channels = Int(buffer.format.channelCount), inputRate = buffer.format.sampleRate
    var mono = [Float](repeating: 0, count: frames)
    for c in 0..<channels { for i in 0..<frames { mono[i] += buffer.floatChannelData![c][i] / Float(channels) } }
    let dc = mono.reduce(0,+) / Float(frames)
    for i in mono.indices { mono[i] -= dc }
    let peak = mono.map { abs($0) }.max()!
    var onset = max(0, (mono.firstIndex(where: { abs($0) > peak * 0.015 }) ?? 0) - Int(inputRate * 0.0007))
    if entry.name.hasPrefix("pedal") {
        let size = max(1, Int((inputRate * 0.001).rounded()))
        let end = min(frames - size, onset + Int(inputRate * 0.1))
        var levels: [Double] = []
        for start in stride(from: onset, to: end, by: size) {
            var energy = 0.0
            for i in start..<(start + size) { energy += Double(mono[i] * mono[i]) }
            levels.append(sqrt(energy / Double(size)))
        }
        let threshold = (levels.max() ?? 0) * 0.65
        if let attack = levels.firstIndex(where: { $0 >= threshold }) {
            onset = max(0, onset + attack * size - size)
        }
    }
    let cap = entry.name.hasPrefix("half") ? 0.60 : entry.name.hasPrefix("shaker") ? 0.28 : 0.23
    let outputRate = 44100.0
    let count = min(Int(cap * outputRate), Int(Double(frames - onset - 1) * outputRate / inputRate))
    var output = [Float](repeating: 0, count: count)
    for i in 0..<count {
        let position = Double(onset) + Double(i) * inputRate / outputRate
        let a = Int(position), mix = Float(position - Double(a))
        output[i] = mono[a] * (1 - mix) + mono[a + 1] * mix
    }
    let window = min(count, Int(outputRate * 0.05))
    let rms = sqrt(output.prefix(window).reduce(0) { $0 + $1 * $1 } / Float(window))
    let gain = min(0.10 / max(0.00001, rms), 0.48 / max(0.00001, output.map { abs($0) }.max()!))
    for i in output.indices {
        let attack = min(1, Float(i) / Float(outputRate * 0.0003))
        let release = min(1, Float(count - 1 - i) / Float(outputRate * 0.020))
        output[i] *= gain * attack * release
    }
    let fmt = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1)!
    let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(count))!; out.frameLength = AVAudioFrameCount(count)
    output.withUnsafeBufferPointer { out.floatChannelData![0].update(from: $0.baseAddress!, count: count) }
    let dest = "TheMetronome/AcousticSamples/ac-\(entry.name).wav"
    let wav = try AVAudioFile(forWriting: URL(fileURLWithPath: dest), settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: outputRate, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
    try wav.write(from: out)
    manifest.append(["file": "ac-\(entry.name).wav", "source": entry.source, "url": entry.url, "sourceSHA256": entry.sha256, "inputRate": inputRate, "removedLeadingFrames": onset, "gain": gain, "outputFrames": count, "outputRate": outputRate])
    print("\(entry.name): \(inputRate) Hz, trim \(onset) frames, \(count) output frames")
}
let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: "TheMetronome/AcousticSamples/sources.json"))
