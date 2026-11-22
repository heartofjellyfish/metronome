import Foundation

struct TunerProfile: Identifiable, Equatable, Codable {
    let id: String
    let family: String
    let title: String
    let strings: [Int]
    // Add to concert MIDI to display the written pitch.
    let writtenOffset: Int
    private let presetInstrument: String?
    private let presetName: String?

    init(_ title: String, _ family: String, _ strings: [Int] = [], offset: Int = 0, id: String? = nil,
         presetInstrument: String? = nil, presetName: String? = nil) {
        self.id = id ?? title
        self.family = family
        self.title = title
        self.strings = strings
        self.writtenOffset = offset
        self.presetInstrument = presetInstrument
        self.presetName = presetName
    }

    static let chromatic = TunerProfile("Chromatic", "")
    static let chineseFamily = "Chinese instruments"
    static let families = ["Guitar & bass", "Bowed strings", "Plucked strings", "Woodwinds", "Brass",
                           "Keys & reeds", "Pitched percussion", chineseFamily, "World instruments", "Voice", "Custom tuning"]
    static let icons = ["guitars", "music.quarternote.3", "guitars.fill", "wind", "music.note",
                        "pianokeys", "tuningfork", "music.note", "globe", "mic", "slider.horizontal.3"]
    static func icon(_ family: String) -> String {
        families.firstIndex(of: family).map { icons[$0] } ?? "circle.dotted"
    }
    static let catalog: [TunerProfile] = {
        let guitar = families[0], bowed = families[1], plucked = families[2], winds = families[3]
        let brass = families[4], keys = families[5], percussion = families[6]
        let world = "World instruments", chinese = chineseFamily
        let instruments: [TunerProfile] = [
            .init("Guitar", guitar, [40,45,50,55,59,64]),
            .init("Guitar · Drop D", guitar, [38,45,50,55,59,64], presetInstrument: "Guitar", presetName: "Drop D"),
            .init("Guitar · DADGAD", guitar, [38,45,50,55,57,62], presetInstrument: "Guitar", presetName: "DADGAD"),
            .init("7-string guitar", guitar, [35,40,45,50,55,59,64]),
            .init("8-string guitar", guitar, [30,35,40,45,50,55,59,64]),
            .init("12-string guitar", guitar, [52,40, 57,45, 62,50, 67,55, 59,59, 64,64]),
            .init("Baritone guitar", guitar, [35,40,45,50,54,59]),
            .init("Bass", guitar, [28,33,38,43]), .init("5-string bass", guitar, [23,28,33,38,43]),
            .init("6-string bass", guitar, [23,28,33,38,43,48]),
            .init("Violin", bowed, [55,62,69,76]), .init("Viola", bowed, [48,55,62,69]),
            .init("Cello", bowed, [36,43,50,57]), .init("Double bass", bowed, [28,33,38,43]),
            .init("Ukulele", plucked, [67,60,64,69]),
            .init("Ukulele · low G", plucked, [55,60,64,69], presetInstrument: "Ukulele", presetName: "Low G"),
            .init("Baritone ukulele", plucked, [50,55,59,64]), .init("Mandolin", plucked, [55,62,69,76]),
            .init("Mandola", plucked, [48,55,62,69]), .init("5-string banjo", plucked, [67,50,55,59,62]),
            .init("Harp", plucked), .init("Lyre", plucked), .init("Dulcimer", plucked),
            .init("Flute", winds), .init("Piccolo", winds, offset: -12), .init("Oboe", winds),
            .init("English horn", winds, offset: 7), .init("Bassoon", winds), .init("Recorder", winds),
            .init("B♭ clarinet", winds, offset: 2), .init("A clarinet", winds, offset: 3),
            .init("Bass clarinet", winds, offset: 14), .init("Soprano sax", winds, offset: 2),
            .init("Alto sax", winds, offset: 9), .init("Tenor sax", winds, offset: 14), .init("Baritone sax", winds, offset: 21),
            .init("B♭ trumpet", brass, offset: 2), .init("C trumpet", brass), .init("Flugelhorn", brass, offset: 2),
            .init("Horn in F", brass, offset: 7), .init("Cornet in B♭", brass, offset: 2),
            .init("Trombone", brass), .init("Euphonium", brass), .init("Tuba", brass),
            .init("Piano", keys), .init("Keyboard", keys), .init("Organ", keys), .init("Accordion", keys), .init("Harmonica", keys),
            .init("Timpani", percussion), .init("Marimba", percussion), .init("Vibraphone", percussion),
            .init("Xylophone", percussion, offset: -12), .init("Glockenspiel", percussion, offset: -24),
            .init("Steel pan", percussion), .init("Handpan", percussion), .init("Kalimba", percussion),
            .init("Erhu", chinese, [62,69]), .init("Yangqin", chinese), .init("Pipa", chinese, [45,50,52,57]),
            .init("Guzheng", chinese, [86,83,81,78,76,74,71,69,66,64,62,59,57,54,52,50,47,45,42,40,38]),
            .init("Guqin", chinese, [36,38,41,43,45,48,50]),
            .init("Dizi", world), .init("Xiao", world), .init("Sheng", world), .init("Suona", world),
            .init("Koto", world, [62,55,57,58,62,63,67,69,70,74,75,79,81]),
            .init("Shamisen", world, [48,53,60]), .init("Shakuhachi", world), .init("Sitar", world, TunerSitar.cSharp),
            .init("Oud · Arabic", world, [36,41,45,50,55,60]),
            .init("Voice", "Voice")
        ]
        return instruments + TunerPresets.alternates(for: instruments)
    }()

    static func parseNotes(_ text: String, maximumCount: Int = 24, range: ClosedRange<Int> = 20...108) -> [Int]? {
        let tokens = text.uppercased().replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "B").split(whereSeparator: { $0.isWhitespace || $0 == "," })
        guard !tokens.isEmpty, tokens.count <= maximumCount else { return nil }
        let naturals: [Character: Int] = ["C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11]
        var result: [Int] = []
        for token in tokens {
            guard let first = token.first, let natural = naturals[first] else { return nil }
            var suffix = token.dropFirst()
            var pitch = natural
            if suffix.first == "#" { pitch += 1; suffix = suffix.dropFirst() }
            else if suffix.first == "B" { pitch -= 1; suffix = suffix.dropFirst() }
            guard let octave = Int(suffix), (-1...10).contains(octave) else { return nil }
            let midi = (octave+1)*12 + pitch
            guard range.contains(midi) else { return nil }
            result.append(midi)
        }
        return result
    }
}

func tunerText(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: L10n.text(key), table: "Tuner")
}

extension TunerProfile {
    var instrumentName: String { presetInstrument ?? title }
    var instrumentID: String { family == "Custom tuning" ? id : instrumentName }

    func playingPrompt(hasStrings: Bool) -> String {
        if hasStrings {
            return family == "Bowed strings" || instrumentName == "Erhu" ? "Play an open string" : "Pluck a string"
        }
        switch instrumentName {
        case "Voice": return "Sing a note"
        case "Dizi", "Xiao", "Sheng", "Suona", "Shakuhachi": return "Play a long note"
        case "Timpani": return "Strike the drum"
        case "Kalimba": return "Pluck a tine"
        case "Handpan": return "Tap a note"
        case "Piano", "Keyboard", "Organ": return "Play one key"
        default:
            switch family {
            case "Brass", "Woodwinds": return "Play a long note"
            case "Pitched percussion": return "Strike a note"
            default: return "Play a note"
            }
        }
    }

    var tuningHint: String? {
        switch instrumentName {
        case "12-string guitar", "Mandolin", "Mandola":
            return "Tune one string at a time within each pair."
        default:
            return nil
        }
    }

    var hasStringSetup: Bool {
        !strings.isEmpty || ["Harp", "Lyre", "Dulcimer", "Yangqin", "Koto", "Shamisen", "Sitar"].contains(id)
    }

    var diagramName: String {
        let name = family == "Custom tuning" ? "Custom tuning" : instrumentName
        let words = name.lowercased().replacingOccurrences(of: "♭", with: "b")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return "tuner-" + words.joined(separator: "-")
    }

    var tuningArtworkName: String {
        switch family {
        case "Woodwinds", "Brass", "Keys & reeds", "Pitched percussion", Self.chineseFamily, "World instruments", "Voice":
            return diagramName + "-face"
        case "Plucked strings" where ["Harp", "Lyre", "Dulcimer"].contains(instrumentName):
            return diagramName + "-face"
        default:
            return diagramName
        }
    }

    var tunings: [TunerProfile] {
        if family == "Custom tuning" { return [self] }
        return Self.catalog.filter { $0.instrumentName == instrumentName }
    }

    var tuningName: String {
        if let presetName { return presetName }
        switch id {
        case "Guzheng": return "D major pentatonic"
        case "Guqin": return "Zhengdiao"
        case "Koto": return "Hirajōshi"
        case "Shamisen": return "Honchōshi"
        case "Sitar": return "Sa = C♯"
        case "5-string banjo": return "Open G"
        case "Ukulele": return "High G"
        default: return "Standard"
        }
    }
}
