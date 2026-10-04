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

// Compound meters count dotted-quarter pulses, with subdivisions inside them.
for numerator in [6, 9, 12] {
    var r = Rhythm(); r.bpm = 120
    r.setMeter(beats: numerator, denominator: 8, compound: true)
    check(r.pulseCount == numerator / 3 && r.subdivision == 3, "Compound grouping")
    let c = SampleClock(rate: 48000); c.reset(r)
    var hits: [(Int, Int, Int)] = []
    for frame in 0...Int(24000 * r.pulseCount) {
        if let (e, strength) = c.advance() { hits.append((frame, e.beat, strength)) }
    }
    check(hits.count == numerator + 1 && hits.last!.0 == 24000 * r.pulseCount, "Compound bar duration")
    check(hits[3].1 == 1 && hits[3].0 == 24000, "Dotted quarter at 120 BPM must last 0.5 seconds")
    check(hits[1].2 == 3 && hits[2].2 == 3, "Eighth subdivisions")
    check(r.beatStrength(1) == (numerator == 6 ? 4 : 1), "Compound duple marks the second group as a secondary accent")
    if numerator == 12 { check(r.beatStrength(2) == 4, "12/8 third big beat secondary") }
    r.followsMeter = false; check(r.beatStrength(0) == 5 && r.beatStrength(1) == 5, "Even playback uses uniform gain")
    r.accents[1] = 0; check(r.beatStrength(1) == 0, "Muted big beat")
    r.subdivision = 6; r.sanitize(); check(r.subdivision == 6, "Sixteenth subdivisions survive persistence")
    let restored = try JSONDecoder().decode(Rhythm.self, from: JSONEncoder().encode(r))
    check(restored == r, "Compound roundtrip")
    r.setMeter(beats: numerator, denominator: 8, compound: false)
    check(r.pulseCount == numerator && r.subdivision == 1, "Eighth-note mode")
}
var legacyJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Rhythm())) as! [String: Any]
legacyJSON.removeValue(forKey: "compoundPulse"); legacyJSON["beats"] = 6; legacyJSON["denominator"] = 8
let legacyMeter = try JSONDecoder().decode(Rhythm.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
check(legacyMeter.pulseCount == 6, "Old saved tempos retain eighth-note meaning")
print("PASS: compound meter bar lengths, subdivisions, accents, even/mute and legacy presets.")

// Cross-checked meter matrix: 2 strong/weak, 3 strong/weak/weak,
// 4 strong/weak/secondary/weak. Subdivision-level accents are hierarchical.
for denominator in [2, 4, 8, 16] {
    for (numerator, expected) in [(2,[2,1]), (3,[2,1,1]), (4,[2,1,4,1])] {
        var r = Rhythm(); r.setMeter(beats: numerator, denominator: denominator, compound: false)
        check((0..<numerator).map { r.displayStrength($0) } == expected, "Simple meter visual matrix")
        check(strengths(r, count: numerator) == expected, "Simple meter sound matrix")
        r.followsMeter = false
        check((0..<numerator).map { r.displayStrength($0) } == expected, "EVEN cannot alter meter hierarchy")
        check(strengths(r, count: numerator) == Array(repeating: 5, count: numerator), "EVEN only flattens audio")
    }
}
for denominator in [4, 8, 16] {
    for (numerator, big) in [(6,[2,4]),(9,[2,1,1]),(12,[2,1,4,1])] {
        var r = Rhythm(); r.setMeter(beats: numerator, denominator: denominator, compound: true)
        let expanded = big.flatMap { [$0,3,3] }
        check((0..<r.pulseCount).map { r.displayStrength($0) } == big, "Compound big-beat hierarchy")
        check(strengths(r, count: numerator) == expanded, "Compound subdivisions preserve hierarchy")
        r.setMeter(beats: numerator, denominator: denominator, compound: false)
        check((0..<numerator).map { r.displayStrength($0) } == expanded, "Expanded counting preserves the same meter hierarchy")
        check(strengths(r, count: numerator) == expanded, "Expanded meter sound matrix")
        r.followsMeter = false
        check((0..<numerator).map { r.displayStrength($0) } == expanded, "Expanded EVEN visual hierarchy")
    }
}
for (numerator, grouping, expected) in [(5,[3,2],[2,1,1,4,1]),(5,[2,3],[2,1,4,1,1]),(7,[2,2,3],[2,1,4,1,4,1,1]),(7,[2,3,2],[2,1,4,1,1,4,1]),(7,[3,2,2],[2,1,1,4,1,4,1])] {
    for denominator in [2,4,8,16] {
        var r = Rhythm(); r.setMeter(beats: numerator, denominator: denominator, compound: false, grouping: grouping)
        check(strengths(r, count: numerator) == expected, "Additive grouping boundaries")
        r.accents[1] = 0; r.followsMeter = false
        check(r.displayStrength(1) == 1 && r.beatStrength(1) == 0, "Mute does not rewrite the meter")
        let restored = try JSONDecoder().decode(Rhythm.self, from: JSONEncoder().encode(r))
        check(restored.effectiveGrouping == grouping, "Grouping persistence")
    }
}
var oldSixFour = Rhythm(); oldSixFour.beats = 6; oldSixFour.denominator = 4
check(oldSixFour.pulseCount == 6, "Existing 6/4 presets must not triple speed on upgrade")
print("PASS: every simple /2 /4 /8 /16 meter, compound grouped/expanded hierarchy, all 5/7 groupings, EVEN visuals and legacy speed.")

// Audit regressions: tap the entire supported range, outliers, reset and invalid clocks.
for bpm in [20, 21, 23, 60, 96, 137, 299, 300] {
    var tap = TapTempo()
    check(tap.record(at: 100) == nil, "First tap must not change tempo")
    for i in 1...10 {
        check(tap.record(at: 100 + Double(i) * 60 / Double(bpm)) == bpm, "Tap cannot recover \(bpm) BPM")
    }
    check(tap.count == 6, "Tap window must remain bounded")
}
var tapping = TapTempo()
for t in [0.0, 0.5, 1.0, 1.5, 2.2] { _ = tapping.record(at: t) }
check(tapping.record(at: 2.7) == 120, "One late tap must not pull the estimate off tempo")
check(tapping.record(at: 10) == nil && tapping.count == 1, "Idle tap series must reset")
check(tapping.record(at: 10) == nil && tapping.count == 1, "Duplicate timestamps must be rejected")
check(tapping.record(at: .nan) == nil && tapping.count == 1, "Invalid timestamps must be rejected")
check(tapping.record(at: 10.000000001) == 300, "Accidental double tap must remain bounded")
print("PASS: Tap 20–300 BPM, six-tap window, late-tap filtering, idle reset and invalid timestamps.")

func nextEvent(_ clock: SampleClock) -> ClockEvent {
    for _ in 0..<100000 { if let (event, _) = clock.advance() { return event } }
    fatalError("Expected an event")
}
var live = Rhythm(); live.bpm = 120; live.countIn = 1
live.ramp = true; live.start = 120; live.end = 126; live.every = 1; live.increment = 2
live.gap = true; live.audibleBars = 1; live.silentBars = 1
let liveClock = SampleClock(rate: 1000); liveClock.reset(live)
for _ in 0..<8 { _ = nextEvent(liveClock) }
let prior = nextEvent(liveClock)
check(prior.bar == 1 && prior.bpm == 122 && prior.silent && !prior.countIn, "Regression precondition")
live.subdivision = 3; liveClock.update(live)
let changed = nextEvent(liveClock)
check(changed.beat == 0 && changed.bar == prior.bar && !changed.countIn, "Live division must preserve completed count-in and practice bar")
check(changed.bpm == 122 && changed.silent, "Live division must not double-ramp or lose the gap phase")
live.setMeter(beats: 6, denominator: 8, compound: true); liveClock.update(live)
let meterChanged = nextEvent(liveClock)
check(meterChanged.bar == 1 && meterChanged.bpm == 122 && !meterChanged.countIn, "Live meter must preserve training progress")
live.countIn = 2; liveClock.update(live)
check(!nextEvent(liveClock).countIn, "Count-in edits apply on the next start")
liveClock.reset(live)
check(nextEvent(liveClock).countIn, "Restart must honor new count-in")
print("PASS: live subdivision/meter preserve count-in completion, ramp tempo and gap phase; count-in edits take effect on restart.")

// A UI timer cannot enforce a one-bar preview: prove the scheduler cannot emit a second bar.
for compound in [false, true] {
    for bpm in [20, 96, 160, 300] {
        for division in (compound ? [1,2,3,6] : [1,2,3,4]) {
            var r = Rhythm(); r.setMeter(beats: compound ? 12 : 4, denominator: compound ? 8 : 4, compound: compound)
            r.bpm = bpm; r.subdivision = division
            let c = SampleClock(rate: 1000); c.reset(r, barLimit: 1)
            var count = 0
            for _ in 0..<Int(1000 * (Double(r.pulseCount) * 60 / Double(bpm) + 1)) {
                if c.advance() != nil { count += 1 }
            }
            check(count == r.pulseCount * division, "Preview emitted extra or missing hits")
        }
    }
}
var descending = Rhythm(); descending.ramp = true; descending.start = 120; descending.end = 113
 descending.every = 1; descending.increment = 3; descending.countIn = 2
let downClock = SampleClock(rate: 1000); downClock.reset(descending)
var downTempos: [Int] = []
while downTempos.count < 7 {
    let e = nextEvent(downClock)
    if e.beat == 0 { downTempos.append(e.bpm) }
}
check(downTempos == [120,120,120,117,114,113,113], "Descending ramp must count in and clamp at its target")
print("PASS: exact one-bar audition across simple/compound grids and tempo limits; descending ramp and target clamp.")

// Exhaust all selectable grids, including less usual meters, without claiming a canonical grouping.
for numerator in 1...12 {
    for denominator in [2,4,8,16] {
        for compound in [false,true] {
            for division in [1,2,3,4,6] {
                var r = Rhythm(); r.setMeter(beats: numerator, denominator: denominator, compound: compound)
                r.subdivision = division; r.sanitize(); r.bpm = 300
                let c = SampleClock(rate: 1000); c.reset(r)
                var events = 0
                for _ in 0..<Int(Double(r.pulseCount) * 200) {
                    if let (e, strength) = c.advance() {
                        check((0..<r.pulseCount).contains(e.beat), "Out-of-range beat")
                        check((0...5).contains(strength), "Invalid intensity")
                        events += 1
                    }
                }
                check(events == r.pulseCount * r.subdivision, "Wrong grid length for \(numerator)/\(denominator)")
            }
        }
    }
}
print("PASS: 480 selectable meter/mode/subdivision configurations have valid beat indices and exact bar lengths.")
