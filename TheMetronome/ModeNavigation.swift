import SwiftUI

enum InstrumentMode: String, CaseIterable, Identifiable {
    case metronome, practice, live
    var id: String { rawValue }
    var title: String { L10n.text(self == .metronome ? "Metronome" : self == .practice ? "Practice" : "Live") }
}

/// Vector silhouettes share the same optical box in every mode.
struct ModeIllustration: View {
    let mode: InstrumentMode
    var ink: Color = Color(hex: 0x282B25)
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            func line(_ points: [CGPoint], width: CGFloat, color: Color) {
                var path = Path(); path.addLines(points)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            switch mode {
            case .metronome:
                var shell = Path()
                shell.addLines([CGPoint(x: 18,y: 88), CGPoint(x: 39,y: 12), CGPoint(x: 59,y: 12), CGPoint(x: 80,y: 88)])
                shell.closeSubpath()
                context.fill(shell, with: .color(ink))
                var cutout = Path()
                cutout.addLines([CGPoint(x: 27,y: 71), CGPoint(x: 43,y: 18), CGPoint(x: 55,y: 18), CGPoint(x: 71,y: 71)])
                cutout.closeSubpath()
                context.blendMode = .destinationOut
                context.fill(cutout, with: .color(.black))
                context.blendMode = .normal
                line([CGPoint(x:49,y:22),CGPoint(x:49,y:67)],width:2.3,color:ink)
                line([CGPoint(x:49,y:67),CGPoint(x:66,y:27)],width:3.2,color:ink)
                context.fill(Path(CGRect(x:55,y:41,width:8,height:9)),with:.color(ink))
                line([CGPoint(x:27,y:86),CGPoint(x:25,y:91)],width:6,color:ink)
                line([CGPoint(x:71,y:86),CGPoint(x:73,y:91)],width:6,color:ink)
            case .practice:
                for inset in [CGFloat(12), CGFloat(25)] {
                    context.stroke(Path(ellipseIn: CGRect(x:inset,y:inset,width:100-2*inset,height:100-2*inset)),with:.color(ink),lineWidth:1.8)
                }
                for (x,y,r) in [(50.0,12.0,5.5),(85.7,63.0,5.5),(20.9,74.4,5.5),(50.0,50.0,6.5)] {
                    context.fill(Path(ellipseIn:CGRect(x:x-r,y:y-r,width:r*2,height:r*2)),with:.color(ink))
                }
            case .live:
                var paper = Path()
                paper.move(to:CGPoint(x:23,y:10)); paper.addLine(to:CGPoint(x:76,y:10))
                paper.addQuadCurve(to:CGPoint(x:81,y:16),control:CGPoint(x:82,y:10))
                paper.addLine(to:CGPoint(x:78,y:74)); paper.addLine(to:CGPoint(x:62,y:90))
                paper.addLine(to:CGPoint(x:19,y:90)); paper.addQuadCurve(to:CGPoint(x:16,y:85),control:CGPoint(x:15,y:90))
                paper.addLine(to:CGPoint(x:19,y:16)); paper.addQuadCurve(to:CGPoint(x:23,y:10),control:CGPoint(x:19,y:10))
                context.fill(paper,with:.linearGradient(Gradient(colors:[Color(hex:0xEDE4D1),Color(hex:0xC8B89B)]),startPoint:CGPoint(x:20,y:10),endPoint:CGPoint(x:80,y:90)))
                context.stroke(paper,with:.color(Color(hex:0x9D8E74).opacity(0.4)),lineWidth:0.7)
                for y in [CGFloat(31),CGFloat(49),CGFloat(67)] {
                    line([CGPoint(x:30,y:y+2),CGPoint(x:64,y:y-4)],width:3.6,color:Color(hex:0x393B30))
                    line([CGPoint(x:27,y:y+4),CGPoint(x:68,y:y-2)],width:1.2,color:Color(hex:0x393B30))
                }
                var fold = Path(); fold.move(to:CGPoint(x:62,y:87)); fold.addQuadCurve(to:CGPoint(x:66,y:75),control:CGPoint(x:62,y:74)); fold.addLine(to:CGPoint(x:76,y:74))
                context.stroke(fold,with:.color(Color(hex:0x48493D)),style:StrokeStyle(lineWidth:2,lineCap:.round))
            }
        }.accessibilityHidden(true)
    }
}

struct ModeTriggerLabel: View {
    let mode: InstrumentMode
    let expanded: Bool
    var body: some View {
        HStack(spacing: 5) {
            Text(mode.title.uppercased()).technical(11, spacing: 4.3).lineLimit(1)
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 8, weight: .medium)).opacity(0.65)
        }.frame(minWidth: 88, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }
}

/// Compact modal; the underlying instrument remains visible and keeps playing.
struct ModeChooser: View {
    let current: InstrumentMode
    let p: InstrumentPalette
    let close: () -> Void
    let select: (InstrumentMode) -> Void
    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 390
            let rowHeight = min(CGFloat(148), max(120, (geo.size.height - 138) / 3))
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.38).ignoresSafeArea().onTapGesture(perform: close).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: close) {
                        HStack(spacing: 12) {
                            Text(L10n.text("Modes")).technical(13, spacing: 2)
                            Image(systemName: "chevron.up").font(.system(size: 11, weight: .medium))
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).frame(width: 150, height: 52)
                    }.buttonStyle(.plain).accessibilityIdentifier("mode-menu-close").accessibilityLabel(L10n.text("Close"))
                    VStack(spacing: 0) {
                        ForEach(InstrumentMode.allCases) { mode in
                            row(mode, compact: compact).frame(height: rowHeight)
                            if mode != .live { Rectangle().fill(p.light).frame(height: 1) }
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 18)).insetPanel(p, radius: 18)
                        .padding(18).padding(.top, 4)
                }.frame(maxWidth: 450)
                    .background { InstrumentBody(p: p).clipShape(ModeMenuShape()) }
                    .overlay { ModeMenuShape().stroke(p.light.opacity(0.65), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
            }
        }.foregroundStyle(p.ink)
            .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, close)
    }
    private func row(_ mode: InstrumentMode, compact: Bool) -> some View {
        let selected = mode == current
        let foreground = selected ? Color(hex: 0xF2EDDF) : p.ink
        return Button { select(mode) } label: {
            HStack(alignment: .center, spacing: compact ? 13 : 14) {
                ModeIllustration(mode: mode, ink: foreground)
                    .frame(width: compact ? 44 : 52, height: compact ? 66 : 76)
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title).font(.system(size: compact ? 20 : 22, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(L10n.text(mode.summary)).font(.system(size: compact ? 13 : 14))
                        .foregroundStyle(foreground.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 5) {
                    Image(systemName: "checkmark").font(.system(size: 22, weight: .semibold))
                    Text(L10n.text("CURRENT")).technical(8, spacing: 1.2)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }.frame(width: 40).opacity(selected ? 1 : 0).accessibilityHidden(true)
            }.padding(.horizontal, compact ? 14 : 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(foreground)
                .background {
                    if selected {
                        LinearGradient(colors: [Color(hex: 0x343731), Color(hex: 0x262923)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .overlay(MaterialGrain().opacity(0.045).blendMode(.overlay))
                    }
                }
                .contentShape(Rectangle())
        }.buttonStyle(ModeRowStyle())
            .accessibilityIdentifier("mode-\(mode.rawValue)")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ModeMenuShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 0))
        p.addLine(to: CGPoint(x: 138, y: 0))
        p.addQuadCurve(to: CGPoint(x: 158, y: 20), control: CGPoint(x: 158, y: 0))
        p.addLine(to: CGPoint(x: 158, y: 34))
        p.addQuadCurve(to: CGPoint(x: 174, y: 50), control: CGPoint(x: 158, y: 50))
        p.addLine(to: CGPoint(x: r.width - 22, y: 50))
        p.addQuadCurve(to: CGPoint(x: r.width, y: 72), control: CGPoint(x: r.width, y: 50))
        p.addLine(to: CGPoint(x: r.width, y: r.height - 22))
        p.addQuadCurve(to: CGPoint(x: r.width - 22, y: r.height), control: CGPoint(x: r.width, y: r.height))
        p.addLine(to: CGPoint(x: 22, y: r.height))
        p.addQuadCurve(to: CGPoint(x: 0, y: r.height - 22), control: CGPoint(x: 0, y: r.height))
        p.addLine(to: CGPoint(x: 0, y: 20))
        p.addQuadCurve(to: CGPoint(x: 20, y: 0), control: .zero)
        p.closeSubpath()
        return p
    }
}

private struct ModeRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay(Color.black.opacity(configuration.isPressed ? 0.07 : 0)).animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private extension InstrumentMode {
    var summary: String {
        switch self {
        case .metronome: "For a quick start. A classic metronome."
        case .practice: "For focused practice. Tempo ramps, silent bars & polyrhythms."
        case .live: "For rehearsals and shows. Setlists, songs, notes & visual beats."
        }
    }
}

struct ModeLanding: View {
    @ObservedObject var model: MetronomeModel
    let mode: InstrumentMode
    let open: (InstrumentPanelKind) -> Void
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PracticeControls(model: model, open: open)
                }.padding(.top, 22).padding(.bottom, 12)
            }
            if model.playing { SettingsPlaybackBar(model: model, p: p) }
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
    }
}
