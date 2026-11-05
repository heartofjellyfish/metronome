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
        let masks = count == 2 ? [2, 1] : count == 3 ? [5, 6, 3, 1, 2, 4] : [7, 13, 11, 9, 10, 5, 14, 6]
        return masks.map { Self(count: count, mask: $0) }
    }
    func applying(to rhythm: Rhythm) -> Rhythm {
        var result = rhythm; result.setDivision(count, mask: mask); return result
    }
}

/// A compact one-pulse engraving. Values follow the actual beat unit, including compound meters.
struct RhythmScore: View {
    let rhythm: Rhythm
    var color: Color = .primary
    var singleSlot: Int? = nil
    private struct Note { var value: Int; var rest = false; var dotted = false }
    private var notes: [Note] {
        let n = rhythm.subdivision, mask = rhythm.enabledMask
        if let i = singleSlot { return [Note(value: rhythm.divisionNoteValue(n), rest: mask & (1 << i) == 0)] }
        let base = rhythm.divisionNoteValue(n)
        if n == 3 && mask == 5 { return [Note(value: base / 2), Note(value: base)] }
        if n == 4 && !rhythm.usesCompoundPulse {
            if mask == 9 { return [Note(value: base / 2, dotted: true), Note(value: base)] }
            if mask == 7 { return [Note(value: base), Note(value: base), Note(value: base / 2)] }
            if mask == 13 { return [Note(value: base / 2), Note(value: base), Note(value: base)] }
            if mask == 11 { return [Note(value: base), Note(value: base / 2), Note(value: base)] }
        }
        return (0..<n).map { Note(value: base, rest: mask & (1 << $0) == 0, dotted: rhythm.usesCompoundPulse && n == 1) }
    }
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
            let items = notes
            let maxWidth = CGFloat(max(1, items.count - 1)) * 25 + 22
            let scale = min(1, min(size.width / maxWidth, size.height / 54))
            let width = size.width / scale, height = size.height / scale
            context.scaleBy(x: scale, y: scale)
            let step: CGFloat = 25, start = (width - CGFloat(items.count - 1) * step) / 2
            let bottom = (height + 39) / 2, stemTop = bottom - 28
            let beamable = items.count > 1 && items.allSatisfy { $0.value >= 8 }
            var stems = Path()
            for i in items.indices {
                let note = items[i], x = start + CGFloat(i) * step
                if note.rest {
                    let restCode: UInt16 = note.value <= 2 ? 0xE4E4 : note.value == 4 ? 0xE4E5 : note.value == 8 ? 0xE4E6 : note.value == 16 ? 0xE4E7 : note.value == 32 ? 0xE4E8 : note.value == 64 ? 0xE4E9 : 0xE4EA
                    context.fill(MusicFont.path(restCode, in: CGRect(x: x-6, y: bottom-27, width: 12, height: 27)), with: .color(color))
                    continue
                }
                context.fill(MusicFont.path(note.value <= 2 ? 0xE0A3 : 0xE0A4, in: CGRect(x:x-6,y:bottom-6,width:11,height:8)),with:.color(color))
                stems.move(to:CGPoint(x:x+4,y:bottom-3)); stems.addLine(to:CGPoint(x:x+4,y:stemTop))
                if note.dotted { context.fill(Path(ellipseIn:CGRect(x:x+9,y:bottom-5,width:3,height:3)),with:.color(color)) }
                if note.value >= 8 && !beamable {
                    let code: UInt16 = note.value == 8 ? 0xE240 : note.value == 16 ? 0xE242 : note.value == 32 ? 0xE244 : note.value == 64 ? 0xE246 : 0xE248
                    context.fill(MusicFont.path(code,in:CGRect(x:x+4,y:stemTop,width:11,height:24)),with:.color(color))
                }
            }
            context.stroke(stems,with:.color(color),lineWidth:1.5)
            if beamable {
                let sounding = items.indices.filter { !items[$0].rest }
                for i in sounding {
                    let beams = max(0, Int(log2(Double(items[i].value))) - 2)
                    for level in 0..<beams {
                        let next = i+1 < items.count && !items[i+1].rest && Int(log2(Double(items[i+1].value)))-2 > level
                        let previous = i > 0 && !items[i-1].rest && Int(log2(Double(items[i-1].value)))-2 > level
                        if next {
                            context.fill(Path(CGRect(x:start+CGFloat(i)*step+4,y:stemTop+CGFloat(level)*5,width:step+1,height:2.8)),with:.color(color))
                        } else if !previous {
                            // Isolated notes keep their proper flag, not a beam across a rest.
                            let flag = Path { p in
                                let x = start+CGFloat(i)*step+4, y = stemTop+CGFloat(level)*5
                                p.move(to:CGPoint(x:x,y:y)); p.addQuadCurve(to:CGPoint(x:x+8,y:y+12),control:CGPoint(x:x+13,y:y+3))
                            }
                            context.stroke(flag,with:.color(color),lineWidth:2)
                        }
                    }
                }
            }
            if let tuplet {
                let characters = Array(tuplet)
                let digitsWidth = CGFloat(characters.count) * 9
                let y = stemTop-9
                var bracket=Path()
                bracket.addLines([CGPoint(x:start-9,y:y+4),CGPoint(x:start-9,y:y),CGPoint(x:width/2-digitsWidth/2-4,y:y)])
                bracket.addLines([CGPoint(x:width/2+digitsWidth/2+4,y:y),CGPoint(x:start+CGFloat(items.count-1)*step+13,y:y),CGPoint(x:start+CGFloat(items.count-1)*step+13,y:y+4)])
                context.stroke(bracket,with:.color(color),lineWidth:1)
                for (index,ch) in characters.enumerated() {
                    let x=width/2-digitsWidth/2+CGFloat(index)*9
                    if let number=ch.wholeNumberValue { context.fill(MusicFont.path(UInt16(0xE880+number),in:CGRect(x:x,y:y-5,width:8,height:10)),with:.color(color)) }
                    else { for dy in [-2.0,2.0] { context.fill(Path(ellipseIn:CGRect(x:x+3,y:y+dy,width:1.5,height:1.5)),with:.color(color)) } }
                }
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
