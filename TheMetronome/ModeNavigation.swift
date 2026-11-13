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

/// One continuous housing: the tab grows into a shared recessed three-way selector.
private struct ModeHousing: Shape {
    func path(in r: CGRect) -> Path {
        let left = r.width - 140.0, right = r.width - 52.0
        var p = Path()
        p.move(to: CGPoint(x: left + 9, y: 0))
        p.addLine(to: CGPoint(x: right - 9, y: 0))
        p.addQuadCurve(to: CGPoint(x: right, y: 9), control: CGPoint(x: right, y: 0))
        p.addLine(to: CGPoint(x: right, y: 29))
        p.addQuadCurve(to: CGPoint(x: right + 9, y: 38), control: CGPoint(x: right, y: 38))
        p.addLine(to: CGPoint(x: r.width - 12, y: 38))
        p.addQuadCurve(to: CGPoint(x: r.width, y: 50), control: CGPoint(x: r.width, y: 38))
        p.addLine(to: CGPoint(x: r.width, y: r.height - 12))
        p.addQuadCurve(to: CGPoint(x: r.width - 12, y: r.height), control: CGPoint(x: r.width, y: r.height))
        p.addLine(to: CGPoint(x: 12, y: r.height))
        p.addQuadCurve(to: CGPoint(x: 0, y: r.height - 12), control: CGPoint(x: 0, y: r.height))
        p.addLine(to: CGPoint(x: 0, y: 50))
        p.addQuadCurve(to: CGPoint(x: 12, y: 38), control: CGPoint(x: 0, y: 38))
        p.addLine(to: CGPoint(x: left - 9, y: 38))
        p.addQuadCurve(to: CGPoint(x: left, y: 29), control: CGPoint(x: left, y: 38))
        p.addLine(to: CGPoint(x: left, y: 9))
        p.addQuadCurve(to: CGPoint(x: left + 9, y: 0), control: CGPoint(x: left, y: 0))
        p.closeSubpath()
        return p
    }
}

struct ModeTriggerLabel: View {
    let expanded: Bool
    var body: some View {
        HStack(spacing: 5) {
            Text(L10n.text("Modes")).font(.system(size: 14, weight: .medium, design: .monospaced))
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 8, weight: .medium)).opacity(0.65)
        }.frame(width: 88, height: 38)
    }
}

struct ModeChooser: View {
    let current: InstrumentMode
    let p: InstrumentPalette
    let close: () -> Void
    let select: (InstrumentMode) -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Button(action: close) { ModeTriggerLabel(expanded: true) }
                    .buttonStyle(.plain).accessibilityIdentifier("mode-menu")
                    .accessibilityValue(L10n.text("Collapse"))
                Color.clear.frame(width: 52)
            }.frame(height: 38)
            HStack(spacing: 0) {
                ForEach(InstrumentMode.allCases) { mode in
                    Button { select(mode) } label: {
                        VStack(spacing: 8) {
                            ModeIllustration(mode: mode).brightness(current == mode ? 0.24 : 0).frame(height: 32)
                            Text(mode.title).font(.custom("HelveticaNeue-CondensedBold", size: 12))
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }.frame(maxWidth: .infinity).frame(height: 106)
                            .foregroundStyle(current == mode ? Color(hex: 0xF5F0E2) : p.ink)
                            .background {
                                if current == mode {
                                    RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [Color(hex: 0x45483F), Color(hex: 0x2F322D)], startPoint: .top, endPoint: .bottom))
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.25), lineWidth: 0.7))
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if current == mode { Image(systemName: "checkmark").font(.system(size: 9, weight: .medium)).foregroundStyle(Color(hex: 0xD0BE8D)).padding(6) }
                            }
                            .overlay(alignment: .trailing) {
                                if mode != .live && current != mode && InstrumentMode.allCases[InstrumentMode.allCases.firstIndex(of: mode)! + 1] != current {
                                    Rectangle().fill(p.edge.opacity(0.45)).frame(width: 0.5, height: 70)
                                }
                            }
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("mode-\(mode.rawValue)")
                        .accessibilityAddTraits(current == mode ? .isSelected : [])
                }
            }.padding(3).insetPanel(p, radius: 8).padding(9)
        }.frame(width: 206, height: 168)
            .foregroundStyle(p.ink)
            .background {
                ModeHousing().fill(LinearGradient(colors: [p.top, p.body], startPoint: .top, endPoint: .bottom))
                    .overlay(ModeHousing().stroke(p.light, lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.23), radius: 4, y: 2)
            }
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
