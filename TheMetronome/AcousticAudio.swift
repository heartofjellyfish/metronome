import Foundation
import AVFoundation

/// Decoded once off the render thread. All clips remain alive for the engine's lifetime.
final class AcousticClip {
    let samples: UnsafeMutablePointer<Float>
    let count: Int
    let rate: Double
    init(url: URL) throws {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard file.processingFormat.channelCount == 1, file.length > 1 else { throw AcousticError.invalidFile }
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        count = Int(buffer.frameLength); rate = buffer.format.sampleRate
        samples = .allocate(capacity: count)
        samples.initialize(from: buffer.floatChannelData![0], count: count)
    }
    deinit { samples.deallocate() }
}
enum AcousticError: LocalizedError {
    case missingFile(String), invalidFile
    var errorDescription: String? {
        switch self {
        case .missingFile(let name): return "Acoustic sound file is missing: \(name)."
        case .invalidFile: return "An acoustic sound file could not be loaded."
        }
    }
}
final class AcousticLibrary {
    static let names: [String] = ["closed-v2", "closed-v3", "half-v2", "pedal-v2", "stick", "shaker", "rimshot", "wood"].flatMap { name in (1...4).map { "ac-\(name)-\($0)" } } + ["ac-bell"]
    let clips: [AcousticClip]
    let naturalHatGains: [Float]
    let balancedGains: [Float]
    init(resolve: (String) -> URL?) throws {
        clips = try Self.names.map { name in
            guard let url = resolve(name) else { throw AcousticError.missingFile(name) }
            return try AcousticClip(url: url)
        }
        // Match attack energy once, before rendering. Peak-normalized recordings can
        // otherwise vary more than the intended metrical accents.
        let rms = clips.map { clip -> Float in
            let count = min(clip.count, Int(clip.rate * 0.05))
            var energy: Double = 0
            for i in 0..<count { energy += Double(clip.samples[i]) * Double(clip.samples[i]) }
            return Float(sqrt(energy / Double(count)))
        }
        let reference = rms.prefix(4).min() ?? 0
        naturalHatGains = rms.map { $0 > 0 ? min(1, reference / $0) : 0 }
        var gains = Array(repeating: Float(1), count: clips.count)
        for group in [0..<8, 8..<12, 12..<16, 16..<20, 20..<24, 24..<28, 28..<32, 32..<33] {
            let level = group.map { rms[$0] }.min() ?? 0
            for i in group { gains[i] = rms[i] > 0 ? min(1, level / rms[i]) : 0 }
        }
        balancedGains = gains
    }
    static func bundled() throws -> AcousticLibrary {
        try AcousticLibrary { name in
            Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "AcousticSamples")
                ?? Bundle.main.url(forResource: name, withExtension: "wav")
        }
    }
}
private struct AcousticVoice {
    var clip: AcousticClip?
    var position = 0.0
    var gain: Float = 0
    var hat = false
    var shaker = false
    var chokeDuration = 0.003
    var chokeTime = -1.0
    var limit = Double.infinity
    mutating func sample(rate: Double) -> Float {
        guard let clip, position < Double(clip.count - 1) else { return 0 }
        let i = Int(position), fraction = Float(position - Double(i))
        let time = position / clip.rate
        if time >= limit { self.clip = nil; return 0 }
        let release = shaker ? min(0.060, limit * 0.65) : 0.020
        let remaining = limit.isFinite ? min(1, max(0, (limit - time) / release)) : 1
        // Smooth endpoints preserve the attack and avoid a chopped-off grain tail.
        let tail = Float(shaker ? remaining * remaining * (3 - 2 * remaining) : remaining)
        let envelope: Float = (chokeTime < 0 ? 1 : Float(max(0, 1 - chokeTime / chokeDuration))) * tail
        if chokeTime >= 0 { chokeTime += 1 / rate }
        position += clip.rate / rate
        return (clip.samples[i] * (1 - fraction) + clip.samples[i + 1] * fraction) * gain * envelope
    }
}

/// Tonal/level articulation only: the sample clock remains perfectly straight.
struct HatArticulation {
    let gain: Float
    let air: Bool
    static func resolve(strength: Int, beat: Int, beats: Int, denominator: Int, counting: Bool = false) -> Self {
        // Strength is resolved once by SampleClock, including grouping and EVEN.
        // Never infer a second, potentially conflicting meter inside an instrument.
        Self(gain: BeatIntensity.gain(strength), air: false)
    }
}
/// Fixed voice pool and immutable sample buffers; no loading or resampling allocations in the callback.
final class AcousticRenderer {
    let library: AcousticLibrary
    private var voices = Array(repeating: AcousticVoice(), count: 8)
    private var cursor = 0
    private var repetitions = Array(repeating: 0, count: 9)
    init(library: AcousticLibrary) { self.library = library }
    func chokeHats() {
        for i in voices.indices where voices[i].hat && voices[i].chokeTime < 0 { voices[i].chokeTime = 0 }
    }
    func trigger(sound: Int, strength: Int, beat: Int = 0, beats: Int = 4, denominator: Int = 4, counting: Bool = false, gainScale: Float = 1, hitInterval: Double = .infinity) {
        guard sound == 0 || sound == 2 || sound == 5 || (6...11).contains(sound), strength > 0 else { return }
        let group = sound == 0 ? 7 : sound == 2 ? 8 : sound == 5 ? 6 : sound - 6
        let repetition = repetitions[group] % 4; repetitions[group] = (repetition + 1) % 4
        if sound == InstrumentSound.naturalHiHat.rawValue {
            let hit = HatArticulation.resolve(strength: strength, beat: beat, beats: beats, denominator: denominator, counting: counting)
            let closed = (strength == 2 || strength == 4) ? 4 + repetition : repetition
            add(offset: closed, gain: hit.gain * gainScale * library.naturalHatGains[closed], hat: true)
            return
        }
        let offset: Int
        switch sound {
        case 0: offset = 28
        case 2: offset = 32
        case 5: offset = 24
        case 6: offset = strength == 2 ? 4 : 0
        case 7: offset = strength == 3 ? 0 : 8
        case 8: offset = 12
        case 9: offset = 16
        default: offset = 20
        }
        let clipIndex = offset + (sound == 2 ? 0 : repetition)
        let shaker = sound == InstrumentSound.acousticShaker.rawValue
        var limit = Double.infinity
        if shaker && hitInterval.isFinite && hitInterval > 0 {
            let duration = Double(library.clips[clipIndex].count) / library.clips[clipIndex].rate
            if hitInterval * 0.9 < duration { limit = hitInterval * 0.9 }
            // Catch residual long strokes after a live tempo/division change.
            for i in voices.indices where voices[i].shaker && voices[i].chokeTime < 0 {
                voices[i].chokeDuration = 0.008
                voices[i].chokeTime = 0
            }
        }
        add(offset: clipIndex, gain: BeatIntensity.gain(strength) * gainScale * library.balancedGains[clipIndex], hat: (6...8).contains(sound), limit: limit, shaker: shaker)
    }
    private func add(offset: Int, gain: Float, hat: Bool, limit: Double = .infinity, shaker: Bool = false) {
        voices[cursor] = AcousticVoice(clip: library.clips[offset], position: 0, gain: gain, hat: hat, shaker: shaker, chokeTime: -1, limit: limit)
        cursor = (cursor + 1) % voices.count
    }
    func sample(rate: Double) -> Float {
        var result: Float = 0
        for i in voices.indices { result += voices[i].sample(rate: rate) }
        return result
    }
}
