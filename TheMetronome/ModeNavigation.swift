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
    let select: (InstrumentMode) -> Void
    var body: some View {
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
            }.padding(3).insetPanel(p, radius: 8).padding(9)
            .frame(width: 300)
            .foregroundStyle(p.ink)
            .background {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [p.top, p.body], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.light, lineWidth: 0.8))
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
