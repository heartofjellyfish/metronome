import SwiftUI
import CoreText

/// Music outlines are loaded only when a score is first drawn, independently of audio startup.
private enum MusicFont {
    static let font: CTFont = {
        if let url = Bundle.main.url(forResource: "Bravura", withExtension: "otf", subdirectory: "MusicFont") ?? Bundle.main.url(forResource: "Bravura", withExtension: "otf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return CTFontCreateWithName("Bravura" as CFString, 100, nil)
    }()
    /// SMuFL flags use their glyph origin at the stem tip, not their bounding-box center.
    static func flag(_ code: UInt16, at tip: CGPoint) -> Path {
        var character = code, glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font, &character, &glyph, 1),
              let outline = CTFontCreatePathForGlyph(font, glyph, nil) else { return Path() }
        return Path(outline).applying(CGAffineTransform(a: 0.32, b: 0, c: 0, d: -0.32, tx: tip.x, ty: tip.y))
    }
    static func path(_ code: UInt16, in box: CGRect) -> Path {
        var character = code, glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font, &character, &glyph, 1), let outline = CTFontCreatePathForGlyph(font, glyph, nil) else { return Path() }
        let r = outline.boundingBoxOfPath
        let scale = min(box.width / r.width, box.height / r.height)
        return Path(outline).applying(CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: box.midX - r.midX * scale, ty: box.midY + r.midY * scale))
    }
}

struct RhythmPattern: Identifiable {
    let count: Int
    let mask: Int
    var id: String { "\(count)-\(mask)" }
    static func choices(_ count: Int) -> [Self] {
        // Familiar long/short and syncopated figures first, then the remaining rest
        // combinations. The all-on grid already lives under Even divisions.
        let masks: [Int]
        switch count {
        case 2: masks = [2, 1]
        case 3: masks = [5, 3, 6, 1, 2, 4]
        case 4: masks = [13, 7, 11, 9, 3, 10, 14, 6, 12, 5, 1, 2, 4, 8]
        default: return []
        }
        return masks.map { Self(count: count, mask: $0) }
    }
    func applying(to rhythm: Rhythm) -> Rhythm {
        var result = rhythm; result.setDivision(count, mask: mask); return result
    }
}

/// Engraving and playback share the same onset mask. Common durations are merged
/// for familiar reading; the custom editor shows each slot explicitly.
struct RhythmEngraving {
    struct Note: Equatable { var value: Int; var rest = false; var dotted = false }
    struct Beam: Equatable { var from: Int; var to: Double; var level: Int }
    let notes: [Note]
    init(_ rhythm: Rhythm, singleSlot: Int? = nil, explicitSlots: Bool = false) {
        let n = rhythm.subdivision, mask = rhythm.enabledMask, base = rhythm.divisionNoteValue(rhythm.subdivision)
        if let i = singleSlot { notes = [Note(value: base, rest: mask & (1 << i) == 0)]; return }
        if !explicitSlots {
            if n == 3 && mask == 5 { notes = [Note(value: base / 2), Note(value: base)]; return }
            if n == 3 && mask == 3 { notes = [Note(value: base), Note(value: base / 2)]; return }
            if n == 4 && !rhythm.usesCompoundPulse {
                if mask == 3 { notes = [Note(value: base), Note(value: base / 2, dotted: true)]; return }
                if mask == 9 { notes = [Note(value: base / 2, dotted: true), Note(value: base)]; return }
                if mask == 7 { notes = [Note(value: base), Note(value: base), Note(value: base / 2)]; return }
                if mask == 13 { notes = [Note(value: base / 2), Note(value: base), Note(value: base)]; return }
                if mask == 11 { notes = [Note(value: base), Note(value: base / 2), Note(value: base)]; return }
            }
        }
        notes = (0..<n).map { Note(value: base, rest: mask & (1 << $0) == 0, dotted: rhythm.usesCompoundPulse && n == 1) }
    }
    func depth(_ i: Int) -> Int {
        guard notes.indices.contains(i), !notes[i].rest else { return 0 }
        return max(0, Int(log2(Double(notes[i].value))) - 2)
    }
    func connected(_ i: Int) -> Bool { depth(i) > 0 && (depth(i-1) > 0 || depth(i+1) > 0) }
    var beams: [Beam] {
        var result: [Beam] = []
        for i in notes.indices where connected(i) {
            for level in 0..<depth(i) {
                if depth(i+1) > level { result.append(Beam(from: i, to: Double(i+1), level: level)) }
                else if depth(i-1) <= level {
                    // A partial beam points into its beamed group; it is never a flag.
                    let direction = depth(i+1) > 0 ? 0.38 : -0.38
                    result.append(Beam(from: i, to: Double(i) + direction, level: level))
                }
            }
        }
        return result
    }
}

/// Includes both bracket hooks and flag extents in its bounds, even in home controls.
struct RhythmScore: View {
    let rhythm: Rhythm
    var color: Color = .primary
    var singleSlot: Int? = nil
    var explicitSlots = false
    var alignsTrailingInk = false
    private var tuplet: String? {
        guard singleSlot == nil else { return nil }
        let n = rhythm.subdivision
        if rhythm.usesCompoundPulse {
            return [1,3,6].contains(n) ? nil : n == 2 ? "2" : "\(n):\(n >= 4 ? 6 : 3)"
        }
        return [3,5,6,7].contains(n) ? String(n) : nil
    }
    var body: some View {
        Canvas { context, size in
            let engraving = RhythmEngraving(rhythm, singleSlot: singleSlot, explicitSlots: explicitSlots)
            let items = engraving.notes
            let heightScale = min(1, size.height / 54)
            let step = max(16, min(25, (size.width / max(0.01, heightScale) - 36) / CGFloat(max(1, items.count - 1))))
            let maxWidth = CGFloat(items.count - 1) * step + 36
            let scale = max(0.01, min(heightScale, size.width / maxWidth))
            let width = size.width / scale, height = size.height / scale
            context.scaleBy(x: scale, y: scale)
            let start = (width - CGFloat(items.count - 1) * step) / 2
            let bottom = (height + 35) / 2, stemTop = bottom - 28
            var outlines: [Path] = []
            func fill(_ path: Path) {
                if alignsTrailingInk { outlines.append(path) }
                else { context.fill(path, with: .color(color)) }
            }
            var stems = Path()
            for i in items.indices {
                let note = items[i], x = start + CGFloat(i) * step
                if note.rest {
                    let restCode: UInt16 = note.value <= 2 ? 0xE4E4 : note.value == 4 ? 0xE4E5 : note.value == 8 ? 0xE4E6 : note.value == 16 ? 0xE4E7 : note.value == 32 ? 0xE4E8 : note.value == 64 ? 0xE4E9 : 0xE4EA
                    fill(MusicFont.path(restCode, in: CGRect(x: x-6, y: bottom-27, width: 12, height: 27)))
                    continue
                }
                fill(MusicFont.path(note.value <= 2 ? 0xE0A3 : 0xE0A4, in: CGRect(x:x-6,y:bottom-6,width:11,height:8)))
                stems.move(to:CGPoint(x:x+4,y:bottom-3)); stems.addLine(to:CGPoint(x:x+4,y:stemTop))
                if note.dotted { fill(Path(ellipseIn:CGRect(x:x+9,y:bottom-5,width:3,height:3))) }
                if note.value >= 8 && !engraving.connected(i) {
                    let code: UInt16 = note.value == 8 ? 0xE240 : note.value == 16 ? 0xE242 : note.value == 32 ? 0xE244 : note.value == 64 ? 0xE246 : 0xE248
                    fill(MusicFont.flag(code, at: CGPoint(x: x+4, y: stemTop)))
                }
            }
            fill(stems.strokedPath(StrokeStyle(lineWidth: 1.5)))
            for beam in engraving.beams {
                let x1 = start + CGFloat(beam.from) * step + 4
                let x2 = start + CGFloat(beam.to) * step + 4
                fill(Path(CGRect(x: min(x1, x2), y: stemTop + CGFloat(beam.level) * 5,
                                         width: abs(x2-x1) + 0.75, height: 2.8)))
            }
            if let tuplet {
                let characters = Array(tuplet)
                let digitsWidth = CGFloat(characters.count) * 9
                let y = stemTop-9
                // Stem-side brackets terminate at the outer stems; rests use their
                // visible edge. Keep both hooks inside the same notation footprint.
                let left = start + (items.first?.rest == true ? -5 : 4)
                let right = start + CGFloat(items.count-1)*step + (items.last?.rest == true ? 5 : 4)
                let center = (left + right) / 2
                var bracket=Path()
                bracket.addLines([CGPoint(x:left,y:y+5),CGPoint(x:left,y:y),CGPoint(x:center-digitsWidth/2-3,y:y)])
                bracket.addLines([CGPoint(x:center+digitsWidth/2+3,y:y),CGPoint(x:right,y:y),CGPoint(x:right,y:y+5)])
                fill(bracket.strokedPath(StrokeStyle(lineWidth: max(1.5, 1 / scale), lineCap: .square, lineJoin: .miter)))
                for (index,ch) in characters.enumerated() {
                    let x=center-digitsWidth/2+CGFloat(index)*9
                    if let number=ch.wholeNumberValue { fill(MusicFont.path(UInt16(0xE880+number),in:CGRect(x:x,y:y-5,width:8,height:10))) }
                    else { for dy in [-2.0,2.0] { fill(Path(ellipseIn:CGRect(x:x+3,y:y+dy,width:1.5,height:1.5))) } }
                }
            }
            if alignsTrailingInk, let edge = outlines.filter({ !$0.isEmpty }).map({ $0.boundingRect.maxX }).max() {
                context.translateBy(x: width - edge, y: 0)
                for outline in outlines { context.fill(outline, with: .color(color)) }
            }
        }.accessibilityHidden(true)
    }
}

extension Rhythm {
    var performanceCopy: Rhythm {
        var value = self; value.ramp = false; value.gap = false; value.countIn = 0
        value.crossRhythm = nil; value.polyrhythmPrimary = nil; value.sanitize(); return value
    }
    var hasPracticeEffects: Bool { ramp || gap || countIn > 0 || crossCount > 0 }
}
