import Foundation

struct TunerCheckGroup: Identifiable {
    let title: String
    let notes: [Int]
    var id: String { title }
}

extension TunerProfile {
    var checkGroups: [TunerCheckGroup] {
        guard strings.isEmpty else { return [] }
        return TunerCheckNotes.groups(for: instrumentName)
    }

    var checkGroupLabel: String {
        switch instrumentName {
        case "Timpani": return "Drum size"
        case "Kalimba", "Handpan": return "Layout"
        default: return "Note set"
        }
    }
}

enum TunerCheckNotes {
    // All targets are sounding MIDI pitches, including those for transposing instruments.
    private static let common: [String: [Int]] = [
        "Flute": [69, 70, 65, 72],
        "Piccolo": [81, 82, 77, 84],
        "Oboe": [69, 70, 65, 72],
        "English horn": [69, 65, 62, 60],
        "Bassoon": [57, 58, 53, 60],
        "Recorder": [69, 72, 67, 77],
        "B♭ clarinet": [70, 65, 69, 58],
        "A clarinet": [69, 64, 67, 57],
        "Bass clarinet": [58, 53, 57, 70],
        "Soprano sax": [70, 69, 65, 72],
        "Alto sax": [69, 58, 65, 70],
        "Tenor sax": [58, 57, 53, 65],
        "Baritone sax": [57, 58, 53, 46],
        "B♭ trumpet": [70, 65, 69, 58],
        "C trumpet": [69, 70, 67, 72],
        "Flugelhorn": [70, 65, 69, 58],
        "Horn in F": [53, 58, 60, 65],
        "Cornet in B♭": [70, 65, 69, 58],
        "Trombone": [58, 53, 46, 65],
        "Euphonium": [58, 53, 46, 65],
        "Tuba": [41, 46, 34, 53],
        "Piano": [69, 60, 21, 36, 48, 72, 84, 96, 108],
        "Keyboard": [69, 60, 48, 72, 84],
        "Organ": [69, 60, 48, 72],
        "Accordion": [69, 60, 55, 72],
        "Marimba": [69, 48, 60, 72, 84],
        "Vibraphone": [69, 60, 65, 72, 84],
        "Xylophone": [72, 77, 81, 84, 96],
        "Glockenspiel": [84, 89, 93, 96, 105],
        "Steel pan": [60, 62, 67, 72, 76, 79, 84],
        "Yangqin": [69, 60, 62, 67, 72],
        "Dizi": [62, 64, 65, 67, 69, 72],
        "Xiao": [62, 65, 67, 69, 72],
        "Sheng": [69, 60, 62, 65, 67, 72],
        "Suona": [62, 65, 67, 69, 74],
        "Shakuhachi": [62, 65, 67, 69, 72, 74],
        "Sitar": [60, 61, 62, 67, 68, 69],
        "Voice": [48, 52, 55, 60, 64, 67, 69, 72],
        "Harp": [48, 60, 67, 69, 72],
        "Lyre": [57, 60, 62, 64, 67, 69],
        "Dulcimer": [55, 60, 62, 67, 72],
    ]

    private static let kettles: [(String, ClosedRange<Int>)] = [
        ("32″", 38...46), ("29″", 41...49), ("26″", 45...53), ("23″", 48...56), ("20″", 52...60),
    ]

    static func groups(for instrument: String) -> [TunerCheckGroup] {
        switch instrument {
        case "Harmonica":
            return [.init(title: "C diatonic", notes: [60, 62, 64, 67, 71, 72, 77])]
        case "Timpani":
            return kettles.map { TunerCheckGroup(title: $0.0, notes: Array($0.1)) }
        case "Handpan":
            return [
                .init(title: "D Kurd", notes: [50, 57, 58, 60, 62, 64, 65, 67, 69]),
                .init(title: "Common notes", notes: [48, 52, 53, 55, 57, 60, 62]),
            ]
        case "Kalimba":
            return [
                .init(title: "C major, 17 keys", notes: [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84, 86, 88]),
                .init(title: "Common notes", notes: [55, 57, 59, 60, 62, 64, 67]),
            ]
        default:
            let pitchChecks = ["Piano", "Keyboard", "Organ", "Accordion", "Marimba", "Vibraphone", "Xylophone", "Glockenspiel", "Steel pan"]
            let title = pitchChecks.contains(instrument) ? "Pitch checks" : "Common notes"
            return common[instrument].map { [.init(title: title, notes: $0)] } ?? []
        }
    }
}
