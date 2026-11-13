import SwiftUI

enum InstrumentMode: String, CaseIterable, Identifiable {
    case metronome, practice, live
    var id: String { rawValue }
    var title: String { L10n.text(self == .metronome ? "Metronome" : self == .practice ? "Practice" : "Live") }
}

/// Miniature physical objects, drawn at a shared size so every mode has equal visual weight.
struct ModeIllustration: View {
    let mode: InstrumentMode
    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 80, size.height / 64)
            context.translateBy(x: (size.width - 80*s)/2, y: (size.height - 64*s)/2)
            context.scaleBy(x: s, y: s)
            let ink = Color(hex: 0x41443E), brass = Color(hex: 0xAC9060)
            func line(_ points: [CGPoint], _ color: Color, _ width: CGFloat) {
                var path = Path(); path.addLines(points)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func rect(_ r: CGRect, _ color: Color, _ radius: CGFloat = 2) {
                context.fill(Path(roundedRect: r, cornerRadius: radius), with: .linearGradient(Gradient(colors: [color, color.opacity(0.85)]), startPoint: r.origin, endPoint: CGPoint(x: r.maxX, y: r.maxY)))
            }
            if mode == .practice {
                // P3: a score stand, equally relevant to strings, keys, winds and percussion.
                line([CGPoint(x:40,y:29),CGPoint(x:40,y:53)], ink, 3)
                line([CGPoint(x:22,y:60),CGPoint(x:40,y:51),CGPoint(x:58,y:60)], ink, 3)
                line([CGPoint(x:40,y:51),CGPoint(x:40,y:61)], brass, 3)
                rect(CGRect(x:13,y:3,width:54,height:32), ink, 3)
                rect(CGRect(x:17,y:6,width:46,height:25), Color(hex:0xE8DDC3))
                for y in [12,17,22,27] { line([CGPoint(x:21,y:y),CGPoint(x:59,y:y)], brass.opacity(0.5), 0.6) }
                for x in [28,45] {
                    context.fill(Path(ellipseIn:CGRect(x:x-4,y:21,width:7,height:4)),with:.color(ink))
                    line([CGPoint(x:x+2,y:23),CGPoint(x:x+2,y:10)],ink,1.5)
                }
                rect(CGRect(x:10,y:32,width:60,height:4), ink)
            } else if mode == .live {
                // L1: a small stage and paired lamps; light is contained, never a neon glow.
                context.fill(Path(ellipseIn:CGRect(x:10,y:48,width:60,height:12)),with:.color(ink))
                rect(CGRect(x:10,y:49,width:60,height:7),ink)
                context.fill(Path(ellipseIn:CGRect(x:10,y:44,width:60,height:12)),with:.color(brass))
                for side in [0,1] {
                    let x: CGFloat = side == 0 ? 24 : 56
                    var beam = Path(); beam.move(to:CGPoint(x:x,y:21)); beam.addLine(to:CGPoint(x:side == 0 ? 20 : 38,y:49)); beam.addLine(to:CGPoint(x:side == 0 ? 42 : 60,y:49)); beam.closeSubpath()
                    context.fill(beam,with:.linearGradient(Gradient(colors:[Color(hex:0xE7C580).opacity(0.55),.clear]),startPoint:CGPoint(x:x,y:21),endPoint:CGPoint(x:x,y:50)))
                    line([CGPoint(x:x,y:9),CGPoint(x:x,y:17)],brass,2)
                    rect(CGRect(x:x-7,y:15,width:14,height:13),ink,4)
                    context.fill(Path(ellipseIn:CGRect(x:x-5,y:23,width:10,height:5)),with:.color(Color(hex:0xE8C680)))
                }
                rect(CGRect(x:12,y:6,width:56,height:4),ink)
            } else {
                var outline = Path(); outline.move(to:CGPoint(x:29,y:6)); outline.addLine(to:CGPoint(x:51,y:6)); outline.addLine(to:CGPoint(x:63,y:58)); outline.addLine(to:CGPoint(x:17,y:58)); outline.closeSubpath()
                context.fill(outline,with:.color(ink))
                rect(CGRect(x:32,y:12,width:16,height:37),Color(hex:0xD8CDAF))
                line([CGPoint(x:40,y:48),CGPoint(x:52,y:17)],brass,2.5)
                rect(CGRect(x:46,y:21,width:9,height:6),brass,1)
            }
        }.accessibilityHidden(true)
    }
}

struct ModeChooser: View {
    let current: InstrumentMode
    let p: InstrumentPalette
    let select: (InstrumentMode) -> Void
    var body: some View {
        HStack(spacing: 5) {
            ForEach(InstrumentMode.allCases) { mode in
                Button { select(mode) } label: {
                    VStack(spacing: 5) {
                        ModeIllustration(mode: mode).brightness(current == mode ? 0.14 : 0).frame(height: 40)
                        Text(mode.title).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).opacity(current == mode ? 1 : 0)
                    }.frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: current == mode, radius: 9))
                    .accessibilityIdentifier("mode-\(mode.rawValue)")
                    .accessibilityAddTraits(current == mode ? .isSelected : [])
            }
        }.padding(8).background { RoundedRectangle(cornerRadius: 15).fill(p.body).shadow(color: .black.opacity(0.20), radius: 8, y: 5) }
    }
}

struct ModeLanding: View {
    @ObservedObject var model: MetronomeModel
    let mode: InstrumentMode
    let open: (InstrumentPanelKind) -> Void
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 18) {
                ModeIllustration(mode: mode).frame(width: 64, height: 56)
                Text(mode.title).font(.system(size: 28, weight: .semibold))
                Spacer()
            }.padding(.top, 25)
            ScrollView {
                VStack(spacing: 14) {
                    if mode == .practice {
                        PracticeControls(model: model, open: open)
                        route("PRESETS", icon: .presets, kind: .presets)
                    } else {
                        route("Setlists", icon: .setlists, kind: .setlists)
                        route("Song library", icon: .songLibrary, kind: .songLibrary)
                        route("Pedal", icon: .pedal, kind: .pedal)
                    }
                }.padding(.vertical, 8)
            }
            SettingsPlaybackBar(model: model, p: p)
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
    }
    private func route(_ title: String, icon: SettingsIllustration.Kind, kind: InstrumentPanelKind) -> some View {
        Button { open(kind) } label: {
            HStack(spacing: 16) {
                SettingsIllustration(kind: icon).frame(width: 52, height: 48)
                Text(L10n.text(title)).font(.system(size: 17, weight: .medium))
                Spacer(); Image(systemName: "chevron.right").font(.caption)
            }.padding(16)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 12))
    }
}
