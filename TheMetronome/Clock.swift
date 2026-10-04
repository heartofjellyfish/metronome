import Foundation

enum InstrumentSound: Int, CaseIterable {
    case wood, click, bell, hiHat, shaker, rim, acousticClosed, acousticOpen, acousticPedal, acousticStick, acousticShaker, naturalHiHat
    // Retired raw values remain decodable for existing presets.
    static let allCases: [InstrumentSound] = [.wood, .click, .bell, .rim, .acousticPedal, .acousticStick, .acousticShaker, .naturalHiHat]
    static let recommended: [InstrumentSound] = [.naturalHiHat, .wood, .click]
    var title: String { ["WOOD", "CLICK", "BELL", "SYNTH HAT", "SHAKER", "RIMSHOT", "CLOSED", "OPEN", "PEDAL", "STICK", "SHAKER", "HI-HAT"][rawValue] }
    var illustration: Int { [0,1,2,3,4,5,3,3,3,6,4,3][rawValue] }
    var detail: String {
        ["REAL WOODBLOCK / DRY & FOCUSED", "SHORT / CLEAR / PRECISE", "REAL HAND BELL / ROUND & RINGING",
         "CLOSED HAT / DYNAMIC STROKES", "SOFT GRAIN / LIGHT SUBDIVISIONS", "REAL SNARE / HEAD & RIM",
         "REAL CLOSED HI-HAT / FOUR TAKES", "HALF-OPEN ACCENT / CLOSED SUBDIVISIONS",
         "REAL PEDAL CHICK / FOUR TAKES", "REAL DRUMSTICKS / FOUR HITS",
         "REAL SHAKER / FOUR TAKES", "CLOSED STROKES / NATURAL ACCENTS"][rawValue]
    }
}

/// Shared musical levels for every renderer, with an audible three-step hierarchy.
enum BeatIntensity {
    static func gain(_ strength: Int) -> Float {
        switch strength {
        case 2: return 1
        case 4: return 0.30
        case 5: return 0.60
        case 3: return 0.18
        case 1: return 0.25
        default: return 0
        }
    }
}

/// Performance dynamics are separate from metrical roles and sample scheduling.
/// Tiny, reproducible level variation never moves a hit or reverses the hierarchy.
struct DynamicHumanizer {
    private var seed: UInt64 = 0x48554D414E
    mutating func nextGain() -> Float {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let unit = Double(UInt32(truncatingIfNeeded: seed >> 32)) / Double(UInt32.max)
        return Float(0.98 + unit * 0.04) // ±2% amplitude; preserve even the 5% context steps.
    }
}

struct Rhythm: Codable, Equatable {
    var bpm = 96
    var beats = 4
    var denominator = 4
    var compoundPulse: Bool? = true
    var compoundMeterVersion: Int?
    var isCompound: Bool { [4, 8, 16].contains(denominator) && [6, 9, 12].contains(beats) }
    var usesCompoundPulse: Bool { isCompound && (compoundPulse ?? false) && (denominator == 8 || compoundMeterVersion == 2) }
    var pulseCount: Int { usesCompoundPulse ? beats / 3 : beats }
    var beatUnit: String {
        usesCompoundPulse ? [4: "𝅗𝅥.", 8: "♩.", 16: "♪."][denominator]!
            : [2: "𝅗𝅥", 4: "♩", 8: "♪", 16: "𝅘𝅥𝅯"][denominator, default: "♩"]
    }
    func divisionNoteValue(_ count: Int) -> Int {
        if usesCompoundPulse { return count == 1 ? denominator / 2 : count == 6 ? denominator * 2 : denominator }
        return denominator * (count == 3 ? 2 : count)
    }
    func divisionTitle(_ count: Int) -> String {
        guard usesCompoundPulse else { return [1: "ONE", 2: "TWO", 3: "TRIPLET", 4: "FOUR"][count, default: "ONE"] }
        if count == 1 { return "BIG BEAT" }
        if count == 2 { return "DUPLET" }
        return [2: "HALVES", 4: "QUARTERS", 8: "EIGHTHS", 16: "SIXTEENTHS", 32: "32ND NOTES"][divisionNoteValue(count), default: "DIVISIONS"]
    }
    var grouping: [Int]?
    static func groupingOptions(_ numerator: Int) -> [[Int]] {
        numerator == 5 ? [[3, 2], [2, 3]] : numerator == 7 ? [[2, 2, 3], [2, 3, 2], [3, 2, 2]] : []
    }
    var effectiveGrouping: [Int] {
        let options = Self.groupingOptions(beats)
        if let grouping, options.contains(grouping) { return grouping }
        return options.first ?? []
    }
    // Meter hierarchy is independent of the audible accent switch and manual mutes.
    func metricalStrength(_ beat: Int) -> Int {
        if beat == 0 { return 2 }
        if usesCompoundPulse { return (pulseCount == 2 && beat == 1) || (pulseCount == 4 && beat == 2) ? 4 : 1 }
        if isCompound {
            if beat % 3 != 0 { return 3 }
            return (beats == 6 && beat == 3) || (beats == 12 && beat == 6) ? 4 : 1
        }
        if beats == 4 { return beat == 2 ? 4 : 1 }
        var boundary = 0
        for group in effectiveGrouping.dropLast() {
            boundary += group
            if beat == boundary { return 4 }
        }
        return 1
    }
    func displayStrength(_ beat: Int) -> Int { metricalStrength(beat) }

    var subdivision = 1
    var accents = [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    var sound = 0
    // Optional storage decodes older saved rhythms without resetting their other settings.
    var dynamics: Bool? = true
    var followsMeter: Bool {
        get { dynamics ?? true }
        set { dynamics = newValue }
    }
    var countIn = 0
    var ramp = false
    var start = 60
    var end = 90
    var every = 8
    var increment = 2
    var gap = false
    var audibleBars = 2
    var silentBars = 2

    func displayedAccent(_ beat: Int) -> Int {
        let value = accents[beat]
        return value > 0 && beat == 0 ? 2 : value
    }
    func beatStrength(_ beat: Int, counting: Bool = false) -> Int {
        let accent = counting ? (beat == 0 ? 2 : 1) : accents[beat]
        if accent == 0 { return 0 }
        if !followsMeter { return 5 }
        if accent == 2 || beat == 0 { return 2 }
        return metricalStrength(beat)
    }

    /// Scale the existing role gain; main beats retain their established nominal levels.
    /// Expanded compound note units descend one level further than big-beat counting.
    func subdivisionGainScale(beat: Int, division: Int, counting: Bool = false) -> Float {
        guard followsMeter else { return 1 }
        let main = beatStrength(beat, counting: counting)
        guard main != 0 else { return 0 }
        let expanded = isCompound && !usesCompoundPulse
        let parent = expanded && main != 2 ? beatStrength(beat - beat % 3, counting: counting) : main
        // A muted neighbouring group start must not silence independently enabled note units.
        let role = parent == 0 ? metricalStrength(beat - beat % 3) : parent
        let context: Float = role == 2 ? 1 : role == 4 ? 0.945 : 0.89
        if division == 0 { return expanded && main == 3 ? context : 1 }
        let light: Bool = subdivision == 4 ? division % 2 == 1
            : usesCompoundPulse && subdivision == 6 ? division % 2 == 1 : false
        let level: Float = expanded ? (light ? 0.065 : 0.105) : (light ? 0.105 : 0.18)
        return level * context / BeatIntensity.gain(3)
    }

    mutating func setMeter(beats: Int, denominator: Int, compound: Bool, grouping: [Int]? = nil) {
        let oldCompound = usesCompoundPulse
        let changed = self.beats != beats || self.denominator != denominator
        self.beats = beats; self.denominator = denominator; compoundPulse = compound; compoundMeterVersion = 2
        self.grouping = grouping
        if changed || oldCompound != usesCompoundPulse {
            accents = [2] + Array(repeating: 1, count: 11)
            subdivision = usesCompoundPulse ? 3 : 1
        }
    }
    mutating func sanitize() {
        bpm = min(300, max(20, bpm)); beats = min(12, max(1, beats))
        denominator = [2, 4, 8, 16].contains(denominator) ? denominator : 4
        subdivision = usesCompoundPulse ? ([1, 2, 3, 6].contains(subdivision) ? subdivision : 3) : min(4, max(1, subdivision))
        accents = Array((accents + Array(repeating: 1, count: 12)).prefix(12)).map { min(2, max(0, $0)) }
        if let grouping, !Self.groupingOptions(beats).contains(grouping) { self.grouping = nil }
        switch sound {
        case 3, 6, 7: sound = 11
        case 4: sound = 10
        default: if InstrumentSound(rawValue: sound) == nil { sound = 0 }
        }
         countIn = min(2, max(0, countIn))
        start = min(300, max(20, start)); end = min(300, max(20, end))
        every = min(32, max(1, every)); increment = min(20, max(1, increment))
        audibleBars = min(16, max(1, audibleBars)); silentBars = min(16, max(1, silentBars))
    }
}

struct ClockEvent {
    let beat: Int
    let bar: Int
    let bpm: Int
    let countIn: Bool
    let silent: Bool
    var gainScale: Float = 1
}

/// Driven by audio sample frames, never a UI timer. Owned exclusively by the render thread.
final class SampleClock {
    var rhythm = Rhythm()
    private(set) var tempo = 96
    private(set) var tick = -1
    private var framesUntilTick: Double = 0
    private var first = true
    private var lastRampBar = -1
    private var countInBars = 0
    private var barLimit: Int?
    private var humanizer = DynamicHumanizer()
    let rate: Double
    init(rate: Double) { self.rate = rate }

    func update(_ value: Rhythm) {
        if value.bpm != rhythm.bpm { tempo = value.bpm }
        if value.ramp != rhythm.ramp {
            tempo = value.ramp ? value.start : value.bpm
            first = value.ramp
            lastRampBar = -1
        }
        // Changes to the pulse grid restart at a clean bar, never index stale accents.
        if value.beats != rhythm.beats || value.denominator != rhythm.denominator || value.usesCompoundPulse != rhythm.usesCompoundPulse || value.subdivision != rhythm.subdivision {
            // Restart this bar's grid, preserving completed count-in and practice progress.
            let bar = max(0, tick / (rhythm.pulseCount * rhythm.subdivision))
            tick = bar * value.pulseCount * value.subdivision - 1; framesUntilTick = 0
        }
        rhythm = value
    }
    func reset(_ value: Rhythm, barLimit: Int? = nil) {
        rhythm = value; tempo = value.ramp ? value.start : value.bpm
        tick = -1; framesUntilTick = 0; first = true
        lastRampBar = -1; countInBars = value.countIn; self.barLimit = barLimit
        humanizer = DynamicHumanizer()
    }
    func advance() -> (ClockEvent, Int)? {
        defer { framesUntilTick -= 1 }
        guard framesUntilTick <= 0 else { return nil }
        let ticksPerBar = rhythm.pulseCount * rhythm.subdivision
        // Stop scheduling hits at the exact boundary; renderers may finish their tails.
        if let barLimit, tick + 1 >= ticksPerBar * barLimit { return nil }
        tick += 1
        let bar = tick / ticksPerBar
        let beat = (tick / rhythm.subdivision) % rhythm.pulseCount
        let primary = tick % rhythm.subdivision == 0
        let counting = bar < countInBars
        let practiceBar = max(0, bar - countInBars)
        if primary && beat == 0 && !counting && rhythm.ramp && practiceBar != lastRampBar {
            lastRampBar = practiceBar
            if first { tempo = rhythm.start; first = false }
            else if practiceBar > 0 && practiceBar % rhythm.every == 0 {
                let direction = rhythm.end >= rhythm.start ? 1 : -1
                let next = tempo + direction * rhythm.increment
                tempo = direction > 0 ? min(rhythm.end, next) : max(rhythm.end, next)
            }
        }
        let silent = !counting && rhythm.gap && practiceBar % (rhythm.audibleBars + rhythm.silentBars) >= rhythm.audibleBars
        framesUntilTick += rate * 60 / Double(tempo * rhythm.subdivision)
        let mainStrength = rhythm.beatStrength(beat, counting: counting)
        let strength = silent || mainStrength == 0 ? 0 : !rhythm.followsMeter ? 5
            : primary ? mainStrength : 3
        let variation = humanizer.nextGain()
        let gainScale: Float = strength == 0 ? 0 : !rhythm.followsMeter ? 1
            : rhythm.subdivisionGainScale(beat: beat, division: tick % rhythm.subdivision, counting: counting) * variation
        return (ClockEvent(beat: beat, bar: practiceBar, bpm: tempo, countIn: counting, silent: silent, gainScale: gainScale), strength)
    }
}

/// A short decaying, band-limited voice. Zero attack sample and short release avoid discontinuities.
struct ClickVoice {
    var age = 1.0
    var frequency = 1200.0
    var strength = 0.0
    var sound = 0
    private var accent = 1
    private var duration = 0.12
    private var chokeTime = -1.0
    private var seed: UInt64 = 0x484154
    private var lowNoise = 0.0
    private var highNoise = 0.0
    private var cachedRate = 0.0
    private var lowCoefficient = 0.0
    private var highCoefficient = 0.0
    mutating func chokeHat() {
        if sound == InstrumentSound.hiHat.rawValue && age < duration && chokeTime < 0 { chokeTime = 0 }
    }
    mutating func trigger(sound: Int, strength: Int, gainScale: Float = 1) {
        age = 0; self.sound = sound; accent = strength
        chokeTime = -1; lowNoise = 0; highNoise = 0
        duration = sound == 3 ? 0.06 : sound == 4 ? 0.10 : 0.12
        self.strength = 0.65 * Double(BeatIntensity.gain(strength) * gainScale)
        frequency = (sound == 0 ? 1050 : sound == 1 ? 1800 : 1450) * (strength == 2 ? 1.35 : 1)
    }
    mutating func sample(rate: Double) -> Float {
        guard age < duration else { return 0 }
        if cachedRate != rate {
            cachedRate = rate
            lowCoefficient = exp(-2 * .pi * 3500 / rate)
            highCoefficient = exp(-2 * .pi * min(10500, rate * 0.40) / rate)
        }
        let t = age; age += 1 / rate
        let attack = min(1, t / 0.0008)
        let wave: Double
        switch sound {
        case 0: wave = (sin(2 * .pi * frequency * t) + 0.35 * sin(2 * .pi * frequency * 1.47 * t)) * exp(-t * 115) / 1.35
        case 1: wave = sin(2 * .pi * frequency * t) * exp(-t * 190)
        case 2: wave = (sin(2 * .pi * frequency * t) + 0.3 * sin(2 * .pi * frequency * 2.76 * t)) * exp(-t * 48) / 1.3
        case 3, 4:
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(UInt32(truncatingIfNeeded: seed >> 32)) / Double(UInt32.max) * 2 - 1
            lowNoise = lowCoefficient * lowNoise + (1 - lowCoefficient) * noise
            highNoise = highCoefficient * highNoise + (1 - highCoefficient) * noise
            let band = highNoise - lowNoise
            if sound == 3 {
                // Inharmonic, band-limited metal modes under a bright filtered noise attack.
                let metal = (sin(2 * .pi * 4211 * t) + sin(2 * .pi * 5873 * t)
                    + sin(2 * .pi * 7331 * t) + sin(2 * .pi * 9479 * t)) / 4
                let decay = accent == 3 ? 0.007 : 0.011
                wave = (band * 1.65 + metal * 0.24) * exp(-t / decay)
            } else {
                let swell = min(1, t / 0.003)
                wave = band * 1.9 * swell * exp(-t / (accent == 2 ? 0.019 : 0.013))
            }
        default:
            let body = (sin(2 * .pi * 1730 * t) + 0.45 * sin(2 * .pi * 2890 * t)
                + 0.20 * sin(2 * .pi * 4130 * t)) / 1.65
            wave = body * exp(-t * 135)
        }
        let release = min(1, max(0, (duration - t) / 0.004))
        let choke = chokeTime < 0 ? 1 : max(0, 1 - chokeTime / 0.003)
        if chokeTime >= 0 { chokeTime += 1 / rate }
        return Float(wave * attack * strength * release * choke)
    }
}
