import SwiftUI

enum InstrumentMode: String, CaseIterable, Identifiable {
    case metronome, practice, live
    var id: String { rawValue }
    var title: String { L10n.text(self == .metronome ? "Metronome" : self == .practice ? "Practice" : "Live") }
}

/// Approved miniature instrument artwork, shared by the chooser and mode surfaces.
struct ModeIllustration: View {
    let mode: InstrumentMode
    private var asset: String {
        switch mode {
        case .metronome: "ModeMetronome"
        case .practice: "ModePractice"
        case .live: "ModeLive"
        }
    }
    var body: some View {
        Image(asset).resizable().scaledToFit().accessibilityHidden(true)
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

struct ModeChooser: View {
    let current: InstrumentMode
    let p: InstrumentPalette
    var embedded = false
    let select: (InstrumentMode) -> Void
    @ViewBuilder var body: some View {
        if embedded {
            VStack(spacing: 6) {
                Text(L10n.text("Choose mode")).font(.system(size: 12, weight: .medium)).foregroundStyle(p.muted)
                choices
            }.padding(12).frame(width: 365, height: 144).insetPanel(p)
        } else {
            choices.padding(3).insetPanel(p, radius: 8).padding(9)
                .frame(width: 300).foregroundStyle(p.ink)
                .background {
                    ModeMenuShell(tabWidth: current == .metronome ? 180 : current == .practice ? 150 : 110)
                        .fill(LinearGradient(colors: [p.top, p.body], startPoint: .top, endPoint: .bottom))
                        .overlay(ModeMenuShell(tabWidth: current == .metronome ? 180 : current == .practice ? 150 : 110).stroke(p.light, lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.23), radius: 4, y: 2)
                }
        }
    }
    private var choices: some View {
            HStack(spacing: 0) {
                ForEach(InstrumentMode.allCases) { mode in
                    Button { select(mode) } label: {
                        VStack(spacing: 2) {
                            ModeIllustration(mode: mode).frame(height: 52)
                            Text(mode.title).font(.system(size: 13, weight: .medium))
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }.frame(maxWidth: .infinity).frame(height: 84)
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
                                    Rectangle().fill(p.edge.opacity(0.45)).frame(width: 0.5, height: 54)
                                }
                            }
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("mode-\(mode.rawValue)")
                        .accessibilityAddTraits(current == mode ? .isSelected : [])
                }
            }
    }
}

/// One continuous housing joins the text trigger to its selector tray.
private struct ModeMenuShell: Shape {
    let tabWidth: CGFloat
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 12))
        path.addLine(to: CGPoint(x: 0, y: -25))
        path.addQuadCurve(to: CGPoint(x: 10, y: -35), control: CGPoint(x: 0, y: -35))
        path.addLine(to: CGPoint(x: tabWidth - 10, y: -35))
        path.addQuadCurve(to: CGPoint(x: tabWidth, y: -25), control: CGPoint(x: tabWidth, y: -35))
        path.addLine(to: CGPoint(x: tabWidth, y: -10))
        path.addQuadCurve(to: CGPoint(x: tabWidth + 10, y: 0), control: CGPoint(x: tabWidth, y: 0))
        path.addLine(to: CGPoint(x: r.maxX - 12, y: 0))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: 12), control: CGPoint(x: r.maxX, y: 0))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 12))
        path.addQuadCurve(to: CGPoint(x: r.maxX - 12, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: 12, y: r.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: r.maxY - 12), control: CGPoint(x: 0, y: r.maxY))
        path.closeSubpath()
        return path
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
