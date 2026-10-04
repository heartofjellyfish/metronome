import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let rate = 48000.0
var config = Rhythm(); config.bpm = 137; config.subdivision = 3
let clock = SampleClock(rate: rate); clock.reset(config)
var frames: [Int] = []
for frame in 0..<Int(rate * 30) { if clock.advance() != nil { frames.append(frame) } }
for (index, frame) in frames.enumerated() {
    let expected = Double(index) * rate * 60 / Double(137 * 3)
    check(abs(Double(frame) - expected) < 1.001, "Clock drift at tick \(index)")
}
config.bpm = 300; config.beats = 2; config.subdivision = 1; config.countIn = 1
config.ramp = true; config.start = 240; config.end = 250; config.every = 1; config.increment = 5
config.gap = true; config.audibleBars = 1; config.silentBars = 1
clock.reset(config)
var bars: [ClockEvent] = []
for _ in 0..<150000 { if let (event, _) = clock.advance(), event.beat == 0 { bars.append(event) } }
check(bars[0].countIn, "Count-in missing")
check(!bars[1].countIn && bars[1].bpm == 240 && !bars[1].silent, "Practice start incorrect")
check(bars[2].bpm == 245 && bars[2].silent, "Ramp or gap incorrect")
check(bars[3].bpm == 250 && !bars[3].silent, "Ramp target incorrect")
check(bars[4].bpm == 250, "Ramp overshoots target")
config.ramp = false; config.countIn = 0; config.gap = false; config.accents[0] = 0
clock.reset(config)
check(clock.advance()!.1 == 0, "Muted beat still sounds")
config.beats = 7; config.subdivision = 4; clock.update(config)
check(clock.advance()!.0.beat == 0, "Meter change must start a clean bar")
for sound in 0...5 {
    var voice = ClickVoice(); voice.trigger(sound: sound, strength: 2)
    var peak: Float = 0
    for _ in 0..<10000 { let sample = voice.sample(rate: rate); check(sample.isFinite, "Nonfinite audio"); peak = max(peak, abs(sample)) }
    check(peak > 0.1 && peak < 1, "Invalid audio amplitude")
    check(voice.sample(rate: rate) == 0, "Voice must decay to silence")
}
let data = try JSONEncoder().encode(config)
let decoded = try JSONDecoder().decode(Rhythm.self, from: data)
check(decoded == config, "Preset roundtrip failed")
print("PASS: 30-second sample clock drift < 1 frame; subdivision, count-in, ramp, gap, mute, meter changes, audio bounds and persistence.")
var switchConfig = Rhythm(); switchConfig.ramp = true; switchConfig.start = 80; switchConfig.bpm = 120
let switching = SampleClock(rate: rate); switching.reset(switchConfig)
_ = switching.advance(); switchConfig.ramp = false; switching.update(switchConfig)
check(switching.tempo == 120, "Disabling ramp must restore selected tempo")
print("PASS: live ramp disable restores manual tempo.")
check(TempoScale.angle(for: 20) == -135, "Minimum must point to the lower-left stop")
check(TempoScale.angle(for: 300) == 135, "Maximum must point to the lower-right stop")
for bpm in 21...300 { check(TempoScale.angle(for: bpm) > TempoScale.angle(for: bpm - 1), "Dial must be monotonic") }
var dial = DialInteraction()
dial.begin(at: 120, bpm: 96)
check(dial.move(to: 120) == 96, "Grabbing must not jump to finger location")
check(dial.move(to: 120 + TempoScale.degreesPerBPM * 10) == 106, "Finger and pointer must use the same scale")
dial.end(); dial.begin(at: 179, bpm: 100)
check(dial.move(to: -179) == 102, "Crossing angular seam must not jump")
dial.end(); dial.begin(at: 0, bpm: 20)
check(dial.move(to: -100) == 20, "Lower clamp missing")
check(dial.move(to: -99) == 21, "Reversing at lower stop must react immediately")
dial.end(); dial.begin(at: 0, bpm: 300)
check(dial.move(to: 100) == 300, "Upper clamp missing")
check(dial.move(to: 99) == 299, "Reversing at upper stop must react immediately")
dial.end(); dial.begin(at: -135, bpm: 20)
_ = dial.move(to: 0)
check(dial.move(to: 135) == 300, "Full arc must reach maximum")
_ = dial.move(to: 0)
check(dial.move(to: -135) == 20, "Full arc must reach minimum")
print("PASS: rotary endpoints, full sweep, relative grab, monotonic mapping, seam continuity, immediate reversal.")

for sampleRate in [44100.0, 48000.0, 96000.0] {
    for sound in 3...5 {
        for strength in 1...3 {
            var voice = ClickVoice(); voice.trigger(sound: sound, strength: strength)
            var energy = 0.0
            for _ in 0..<Int(sampleRate * 0.25) {
                let sample = voice.sample(rate: sampleRate)
                check(sample.isFinite && abs(sample) < 1, "Percussion must remain bounded")
                energy += Double(sample * sample)
            }
            check(energy > 0.01, "Percussion unexpectedly silent")
            check(voice.sample(rate: sampleRate) == 0, "Percussion tail did not finish")
        }
    }
}
var hat = ClickVoice(); hat.trigger(sound: 3, strength: 2)
for _ in 0..<480 { _ = hat.sample(rate: rate) }
hat.chokeHat()
for _ in 0..<150 { _ = hat.sample(rate: rate) }
check(hat.sample(rate: rate) == 0, "Closed hat must choke previous open hat")
for sound in InstrumentSound.allCases.map(\.rawValue) {
    var saved = Rhythm(); saved.sound = sound; saved.sanitize()
    let restored = try JSONDecoder().decode(Rhythm.self, from: JSONEncoder().encode(saved))
    check(restored.sound == sound, "New sound must survive sanitize and restore")
}
print("PASS: six sound presets, percussion at 44.1/48/96 kHz, hi-hat choke and sound persistence.")
for sound in 3...5 {
    var dense = Rhythm(); dense.bpm = 300; dense.subdivision = 4; dense.sound = sound
    dense.accents = Array(repeating: 2, count: 12)
    let clock = SampleClock(rate: rate); clock.reset(dense)
    var voices = Array(repeating: ClickVoice(), count: 4), voiceIndex = 0
    for _ in 0..<Int(rate * 3) {
        if let (_, strength) = clock.advance(), strength > 0 {
            for i in voices.indices { voices[i].chokeHat() }
            voices[voiceIndex % 4].trigger(sound: sound, strength: strength); voiceIndex += 1
        }
        var sample: Float = 0
        for i in voices.indices { sample += voices[i].sample(rate: rate) }
        check(sample.isFinite && abs(sample) < 1, "Dense percussion mix clips")
    }
}
print("PASS: 300 BPM sixteenth-note percussion mix remains below full scale.")

func strengths(_ rhythm: Rhythm, count: Int) -> [Int] {
    let clock = SampleClock(rate: 1000); clock.reset(rhythm)
    var result: [Int] = []
    while result.count < count { if let (_, strength) = clock.advance() { result.append(strength) } }
    return result
}
var dynamics = Rhythm()
check(dynamics.followsMeter, "Dynamics must default on")
for sound in InstrumentSound.allCases {
    dynamics.sound = sound.rawValue; dynamics.followsMeter = true
    check(strengths(dynamics, count: 4) == [2,1,4,1], "Every sound follows 4/4 hierarchy")
    dynamics.followsMeter = false
    check(strengths(dynamics, count: 4) == [5,5,5,5], "Even mode must suppress accents")
}
dynamics.subdivision = 2
check(strengths(dynamics, count: 8) == Array(repeating: 5, count: 8), "Even subdivisions must stay even")
dynamics.accents[2] = 0
check(strengths(dynamics, count: 8) == [5,5,5,5,0,0,5,5], "Even mode must preserve muted beats")
let evenData = try JSONEncoder().encode(dynamics)
let evenDecoded = try JSONDecoder().decode(Rhythm.self, from: evenData)
check(!evenDecoded.followsMeter, "Even mode must persist")
var legacy = try JSONSerialization.jsonObject(with: evenData) as! [String: Any]
legacy.removeValue(forKey: "dynamics")
let old = try JSONDecoder().decode(Rhythm.self, from: JSONSerialization.data(withJSONObject: legacy))
check(old.followsMeter && old.sound == dynamics.sound && old.accents == dynamics.accents, "Old settings must migrate without losing values")
print("PASS: dynamics default/migration/persistence; all sounds; even subdivisions and mute preservation.")
for sound in 0...5 {
    func level(_ strength: Int) -> Double {
        var voice = ClickVoice(); voice.trigger(sound: sound, strength: strength)
        var energy = 0.0
        for _ in 0..<2400 { let value = Double(voice.sample(rate: 48000)); energy += value * value }
        return 10 * log10(energy / 2400)
    }
    let strong = level(2), secondary = level(4), weak = level(1)
    check(strong > secondary + 1 && secondary > weak + 2, "Synthesized sound must render three distinct metrical levels")
}
print("PASS: rendered metrical intensity across all six synthesized sounds.")

var unmarked = Rhythm(); unmarked.accents = Array(repeating: 1, count: 12)
check(strengths(unmarked, count: 4) == [2,1,4,1], "Accent mode must supply the meter even when all pads were normal")
unmarked.accents[0] = 0
check(strengths(unmarked, count: 4) == [0,1,4,1], "Automatic downbeat must respect mute")

check(InstrumentSound.allCases.count == 8, "Catalog must not contain duplicate synthesized instruments")
for (old, new) in [(3,11),(4,10),(6,11),(7,11)] {
    var saved = Rhythm(); saved.sound = old; saved.sanitize()
    check(saved.sound == new, "Retired preset must migrate to its acoustic equivalent")
}
