import Foundation

struct TunerPresetSection: Identifiable {
    let title: String?
    let options: [TunerProfile]
    var id: String { title ?? "" }
}

extension TunerProfile {
    var tuningSections: [TunerPresetSection] {
        let options = tunings
        guard instrumentName == "Guitar" else { return [.init(title: nil, options: options)] }
        let common = ["Standard", "Drop D", "Half step down", "Whole step down", "Open D", "Open G", "DADGAD"]
        let groups: [(String, [TunerProfile])] = [
            ("Common tunings", common.compactMap { name in options.first { $0.tuningName == name } }),
            ("Drop tunings", options.filter { !common.contains($0.tuningName) &&
                ($0.tuningName.hasPrefix("Drop ") || $0.tuningName == "Double drop D") }),
            ("Open tunings", options.filter { !common.contains($0.tuningName) && $0.tuningName.hasPrefix("Open ") }),
        ]
        let shown = Set(groups.flatMap { $0.1.map(\.id) })
        return (groups + [("Other tunings", options.filter { !shown.contains($0.id) })])
            .filter { !$0.1.isEmpty }.map { .init(title: $0.0, options: $0.1) }
    }
}

enum TunerPresets {
    static func alternates(for instruments: [TunerProfile]) -> [TunerProfile] {
        instruments.filter { $0.id == $0.instrumentName && !$0.strings.isEmpty }.flatMap { instrument in
            // Keep the existing preset IDs stable for UI automation and stored preferences.
            options(for: instrument).map { name, notes in
                TunerProfile(instrument.id + " · " + name, instrument.family, notes, offset: instrument.writtenOffset,
                             presetInstrument: instrument.id, presetName: name)
            }
        }
    }

    private static let definitions: [String: [(String, [Int])]] = [
        "Guitar": [
            ("Half step down", [39,44,49,54,58,63]), ("Whole step down", [38,43,48,53,57,62]),
            ("C standard", [36,41,46,51,55,60]), ("B standard", [35,40,45,50,54,59]),
            ("Drop C♯", [37,44,49,54,58,63]), ("Drop C", [36,43,48,53,57,62]),
            ("Drop B", [35,42,47,52,56,61]), ("Drop A", [33,40,45,50,54,59]),
            ("Double drop D", [38,45,50,55,59,62]),
            ("Open D", [38,45,50,54,57,62]), ("Open D minor", [38,45,50,53,57,62]),
            ("Open E", [40,47,52,56,59,64]), ("Open G", [38,43,50,55,59,62]),
            ("Open G minor", [38,43,50,55,58,62]), ("Open A", [40,45,52,57,61,64]),
            ("Open C", [36,43,48,55,60,64]), ("Open C minor", [36,43,48,55,60,63]),
            ("DGDGCD", [38,43,50,55,60,62]), ("Orkney", [36,43,50,55,57,62]),
            ("All fourths", [40,45,50,55,60,65]), ("New standard", [36,43,50,57,64,67]),
            ("Nashville", [52,57,62,67,59,64]),
            ("D♭ standard", [37,42,47,52,56,61]), ("A standard", [33,38,43,48,52,57]),
            ("Drop B♭", [34,41,46,51,55,60]), ("Drop G", [31,38,43,48,52,57]),
            ("Open E♭", [39,46,51,55,58,63]), ("Open D♭", [37,44,49,53,56,61]),
            ("Open E minor", [40,47,52,55,59,64]), ("Open A minor", [40,45,52,57,60,64]),
            ("DADGAD down a whole step", [36,43,48,53,55,60]),
            ("EGDGBE", [40,43,50,55,59,64]),
        ],
        "7-string guitar": [
            ("Half step down", [34,39,44,49,54,58,63]), ("Whole step down", [33,38,43,48,53,57,62]),
            ("Drop A", [33,40,45,50,55,59,64]), ("Drop G♯", [32,39,44,49,54,58,63]),
            ("Drop G", [31,38,43,48,53,57,62]),
            ("Drop F♯", [30,37,42,47,52,56,61]), ("All fourths", [35,40,45,50,55,60,65]),
        ],
        "8-string guitar": [
            ("Half step down", [29,34,39,44,49,54,58,63]),
            ("Drop E", [28,35,40,45,50,55,59,64]), ("Whole step down", [28,33,38,43,48,53,57,62]),
        ],
        "12-string guitar": [
            ("Half step down", [51,39,56,44,61,49,66,54,58,58,63,63]),
            ("Whole step down", [50,38,55,43,60,48,65,53,57,57,62,62]),
            ("Drop D", [50,38,57,45,62,50,67,55,59,59,64,64]),
            ("Open D", [50,38,57,45,62,50,66,54,57,57,62,62]),
            ("Open G", [50,38,55,43,62,50,67,55,59,59,62,62]),
            ("DADGAD", [50,38,57,45,62,50,67,55,57,57,62,62]),
            ("Double drop D", octaveCourses([38,45,50,55,59,62])),
            ("Open C", octaveCourses([36,43,48,55,60,64])),
            ("Open E", octaveCourses([40,47,52,56,59,64])),
            ("Open G minor", octaveCourses([38,43,50,55,58,62])),
        ],
        "Baritone guitar": [
            ("A standard", [33,38,43,48,52,57]), ("Drop A", [33,40,45,50,54,59]),
            ("B♭ standard", [34,39,44,49,53,58]),
        ],
        "Bass": [
            ("Drop D", [26,33,38,43]), ("Half step down", [27,32,37,42]),
            ("Whole step down", [26,31,36,41]), ("BEAD", [23,28,33,38]),
            ("Drop C♯", [25,32,37,42]), ("Drop C", [24,31,36,41]), ("Drop B", [23,30,35,40]),
            ("Fifths", [24,31,38,45]),
        ],
        "5-string bass": [
            ("Drop A", [21,28,33,38,43]), ("High C", [28,33,38,43,48]),
            ("Half step down", [22,27,32,37,42]), ("Whole step down", [21,26,31,36,41]),
            ("Drop B♭", [22,28,33,38,43]),
        ],
        "6-string bass": [
            ("Half step down", [22,27,32,37,42,47]), ("Whole step down", [21,26,31,36,41,46]),
            ("Drop A", [21,28,33,38,43,48]), ("E-to-E", [28,33,38,43,47,52]),
        ],
        "Ukulele": [
            ("D tuning", [69,62,66,71]), ("Open C", [67,60,64,67]),
            ("Low A D tuning", [57,62,66,71]), ("B♭ tuning", [65,58,62,67]),
            ("Open D", [69,62,66,69]), ("Open C minor", [67,60,63,67]),
        ],
        "Baritone ukulele": [
            ("Open G", [50,55,59,62]), ("High D", [62,55,59,64]),
            ("Open D", [50,57,62,66]), ("Open G minor", [50,55,58,62]),
        ],
        "Violin": [
            ("Cross tuning", [57,64,69,76]), ("Cajun", [53,60,67,74]),
            ("Cross tuning in G", [55,62,67,74]), ("Calico", [57,64,69,73]),
            ("GDAD", [55,62,69,74]),
        ],
        "Viola": [
            ("Half step down", [47,54,61,68]), ("Whole step down", [46,53,60,67]),
            ("Mozart scordatura", [49,56,63,70]),
        ],
        "Cello": [
            ("Low B♭", [34,43,50,57]), ("Bach Suite No. 5", [36,43,50,55]),
            ("Kodály Sonata", [35,42,50,57]), ("Whole step down", [34,41,48,55]),
        ],
        "Double bass": [
            ("Solo tuning", [30,35,40,45]), ("Low C", [24,33,38,43]),
            ("Drop D", [26,33,38,43]), ("Fifths", [24,31,38,45]),
        ],
        "Mandolin": [
            ("Cross tuning", [57,64,69,76]), ("GDGD", [55,62,67,74]), ("GDAD", [55,62,69,74]),
            ("Open G", [55,62,67,71]), ("Whole step down", [53,60,67,74]),
        ],
        "Mandola": [
            ("Cross tuning", [50,57,62,69]), ("Whole step down", [46,53,60,67]),
        ],
        "5-string banjo": [
            ("Double C", [67,48,55,60,62]), ("Drop C", [67,48,55,59,62]),
            ("Sawmill", [67,50,55,60,62]), ("Open D", [66,50,54,57,62]),
            ("Open C", [67,48,55,60,64]), ("Open D with A drone", [69,50,54,57,62]),
        ],
        "Erhu": [
            ("Whole step down", [60,67]), ("Half step down", [61,68]),
            ("Half step up", [63,70]),
        ],
        "Pipa": [
            ("Whole step down", [43,48,50,55]), ("Half step down", [44,49,51,56]),
            ("Half step up", [46,51,53,58]),
        ],
        "Guqin": [
            ("Ruibin diao", [36,38,41,43,46,48,50]), ("Manjiao diao", [36,38,40,43,45,48,50]),
        ],
        "Koto": [
            ("Hirajōshi, low first string", [50,55,57,58,62,63,67,69,70,74,75,79,81]),
            ("Hirajōshi in C", [60,53,55,56,60,61,65,67,68,72,73,77,79]),
            ("Hirajōshi in E", [64,57,59,60,64,65,69,71,72,76,77,81,83]),
        ],
        "Shamisen": [
            ("Niagari", [48,55,60]), ("Sansagari", [48,53,58]),
            ("Honchōshi in D", [50,55,62]), ("Niagari in D", [50,57,62]), ("Sansagari in D", [50,55,60]),
        ],
        "Oud · Arabic": [("High F", [41,45,50,55,60,65]), ("Low D", [38,41,45,50,55,60])],
        "Sitar": [
            ("Sa = C", TunerSitar.cSharp.map { $0 - 1 }),
            ("Sa = D", TunerSitar.cSharp.map { $0 + 1 }),
            ("Sa = C♯ · 11 taraf", Array(TunerSitar.cSharp.prefix(18)))
        ],
    ]

    private static func options(for instrument: TunerProfile) -> [(String, [Int])] {
        guard instrument.id == "Guzheng" else { return definitions[instrument.id] ?? [] }
        // The bridge changes keep the standard string numbers and registers.
        let configurations: [(String, [Int: Int])] = [
            ("G major pentatonic", [6: 1]),
            ("C major pentatonic", [6: 1, 11: 1]),
            ("A major pentatonic", [2: -1]),
            ("F major pentatonic", [4: 1, 6: 1, 11: 1]),
        ]
        return configurations.map { name, changes in
            (name, instrument.strings.map { $0 + changes[$0 % 12, default: 0] })
        }
    }

    private static func octaveCourses(_ lowToHigh: [Int]) -> [Int] {
        lowToHigh.enumerated().flatMap { index, pitch in
            [index < 4 ? pitch + 12 : pitch, pitch]
        }
    }
}
