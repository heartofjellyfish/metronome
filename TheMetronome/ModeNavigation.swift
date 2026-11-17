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

/// Full-screen chooser. Opening and dismissing are navigation only: audio keeps running.
struct ModeChooser: View {
    let current: InstrumentMode
    let p: InstrumentPalette
    let close: () -> Void
    let select: (InstrumentMode) -> Void
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650
            let margin: CGFloat = geometry.size.width < 360 ? 16 : 24
            VStack(spacing: compact ? 22 : 32) {
                HStack {
                    Text(L10n.text("Modes")).font(.system(size: compact ? 32 : 40, weight: .bold)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 23, weight: .regular)).frame(width: 48, height: 48)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 11))
                        .accessibilityLabel(L10n.text("Close")).accessibilityIdentifier("mode-menu-close")
                }.padding(.horizontal, 8)
                VStack(spacing: 0) {
                    ForEach(InstrumentMode.allCases) { mode in
                        row(mode, compact: compact)
                        if mode != .live {
                            Rectangle().fill(p.light).frame(height: 1)
                        }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 23))
                    .insetPanel(p, radius: 23)

            }
            .padding(.horizontal, margin)
            .padding(.top, compact ? 20 : 52)
            .padding(.bottom, compact ? 28 : 60)
            .frame(maxWidth: 620).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.foregroundStyle(p.ink)
            .background { InstrumentBody(p: p).ignoresSafeArea() }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, close)
    }
    private func row(_ mode: InstrumentMode, compact: Bool) -> some View {
        let selected = mode == current
        let foreground = selected ? Color(hex: 0xF2EDDF) : p.ink
        return Button { select(mode) } label: {
            HStack(spacing: compact ? 16 : 22) {
                ModeIllustration(mode: mode, ink: foreground)
                    .frame(width: compact ? 68 : 80, height: compact ? 82 : 100)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(mode.title).font(.system(size: compact ? 23 : 27, weight: .bold))
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if selected {
                            Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold))
                        }
                    }
                    Text(L10n.text(mode.summary)).font(.system(size: compact ? 14 : 16))
                        .foregroundStyle(foreground.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(.horizontal, compact ? 18 : 24)
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

private struct ModeRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay(Color.black.opacity(configuration.isPressed ? 0.07 : 0)).animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private extension InstrumentMode {
    var summary: String {
        switch self {
        case .metronome: "Set a tempo. Start playing."
        case .practice: "Build speed. Train your timing."
        case .live: "Your songs. Your setlists."
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
