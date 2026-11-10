import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MetronomeModel
    @Environment(\.dismiss) private var dismiss
    @State private var panel: InstrumentPanelKind?
    @State private var panelSession = UUID()
    private func present(_ kind: InstrumentPanelKind) { panelSession = UUID(); panel = kind }
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    @State private var preparation = false
    private var shelf: [InstrumentSound] {
        let current = InstrumentSound(rawValue: model.rhythm.sound) ?? .naturalHiHat
        return Array(([current] + InstrumentSound.recommended.filter { $0 != current }).prefix(3))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETTINGS").technical(22, spacing: 4).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                Button { model.endSoundPreview(); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 22, weight: .light)).frame(width: 44, height: 44)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                    .accessibilityLabel("Close settings").accessibilityIdentifier("close-settings")
            }.padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 20)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 15) {
                            HStack(spacing: 12) {
                                SectionLabel(text: "01 SOUND", p: p)
                                Button { present(.sounds) } label: {
                                    HStack(spacing: 8) {
                                        Text("All sounds").font(.system(size: 13, weight: .medium))
                                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                    }.padding(.horizontal, 13).frame(minHeight: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p, radius: 8))
                                    .accessibilityLabel(L10n.text("All sounds")).accessibilityIdentifier("all-sounds")
                                    .accessibilityValue(InstrumentSound(rawValue: model.rhythm.sound)?.title ?? "HI-HAT")
                            }
                            SoundCardRow(selectedSound: model.rhythm.sound, selectSound: model.selectSound, sounds: shelf, namespace: "recommended", p: p)
                            SoundDynamicsControl(model: model)
                        }
                        VStack(spacing: 16) {
                            SectionLabel(text: "02 PRACTICE", p: p)
                            HStack(spacing: 14) {
                                navigationKey("PRACTICE", icon: .practice, route: .practice)
                                navigationKey("PRESETS", icon: .presets, route: .presets)
                            }
                        }
                        VStack(spacing: 14) {
                            SectionLabel(text: "03 LIVE MODE", p: p)
                            HStack(spacing: 14) {
                                liveKey("Setlists", icon: .setlists, route: .setlists)
                                liveKey("Song library", icon: .songLibrary, route: .songLibrary)
                                liveKey("Pedal", icon: .pedal, route: .pedal)
                            }
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) {
                                    Text("Keep screen awake").font(.system(size: 14))
                                    Spacer(minLength: 0)
                                    liveScreenKeys
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Keep screen awake").font(.system(size: 14))
                                    liveScreenKeys.frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            Button {
                                preparation.toggle()
                                if !preparation { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("live-section", anchor: .center) } }
                            } label: {
                                HStack {
                                    Text("Before performing").font(.system(size: 14))
                                    Spacer()
                                    Image(systemName: preparation ? "chevron.up" : "chevron.down").font(.system(size: 11))
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("settings-preparation")
                                .accessibilityValue(L10n.text(preparation ? "Collapse" : "Expand"))
                            if preparation { PerformancePreparation(p: p) }
                        }.id("live-section")
                        VStack(spacing: 16) {
                            SectionLabel(text: "04 GENERAL", p: p)
                            HStack {
                                Text("Playback sound").technical(11, spacing: 1)
                                Spacer()
                                HStack(spacing: 8) {
                                    ForEach([false, true], id: \.self) { on in
                                        Button { model.soundEnabled = on } label: { Text(L10n.text(on ? "ON" : "OFF")).frame(width: 60, height: 44) }
                                            .buttonStyle(HardwareButtonStyle(p: p, charcoal: model.soundEnabled == on))
                                            .accessibilityIdentifier(on ? "general-sound-on" : "general-sound-off")
                                            .accessibilityAddTraits(model.soundEnabled == on ? .isSelected : [])
                                    }
                                }
                            }
                            HStack {
                                Text("TOUCH FEEDBACK").technical(11, spacing: 1)
                                Spacer()
                                HStack(spacing: 8) {
                                    ForEach([false, true], id: \.self) { on in
                                        Button { model.haptics = on } label: { Text(L10n.text(on ? "ON" : "OFF")).frame(width: 60, height: 44) }
                                            .buttonStyle(HardwareButtonStyle(p: p, charcoal: model.haptics == on))
                                            .accessibilityIdentifier(on ? "general-haptics-on" : "general-haptics-off")
                                    }
                                }
                            }
                        }
                        HStack(spacing: 14) {
                            Text("SKIN").technical(11, spacing: 1.3)
                            Spacer(minLength: 0)
                            skinKeys.frame(maxWidth: 260).frame(height: 46)
                        }
                    }.padding(.horizontal, 26).padding(.bottom, 24)
                }.scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("settings-scroll")
            }
            SettingsPlaybackBar(model: model, p: p).padding(.horizontal, 26).padding(.bottom, 12)
        }.frame(maxWidth: 460).frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain).accessibilityHidden(panel != nil).allowsHitTesting(panel == nil)
            .foregroundStyle(p.ink).background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light)
            .overlay { if let panel { InstrumentPanel(model: model, kind: panel) { self.panel = nil }.id(panelSession) } }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onDisappear { model.endSoundPreview() }
            .onChange(of: model.error) { _, value in if value != nil { present(.audio) } }
    }
    private var liveScreenKeys: some View {
        HStack(spacing: 8) {
            ForEach([false, true], id: \.self) { on in
                Button { model.keepLiveScreenAwake = on } label: {
                    Text(L10n.text(on ? "ON" : "OFF")).frame(width: 60, height: 44)
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: model.keepLiveScreenAwake == on))
                    .accessibilityLabel(Text(on ? "Keep screen awake" : "Allow automatic screen lock"))
                    .accessibilityIdentifier(on ? "live-screen-on" : "live-screen-off")
                    .accessibilityAddTraits(model.keepLiveScreenAwake == on ? .isSelected : [])
            }
        }
    }

    private func liveKey(_ title: String, icon: SettingsIllustration.Kind, route: InstrumentPanelKind) -> some View {
        Button { model.endSoundPreview(); present(route) } label: {
            VStack(spacing: 5) {
                SettingsIllustration(kind: icon).frame(width: 55, height: 44)
                Text(L10n.text(title)).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.center).frame(height: 30)
            }.padding(.vertical, 10).frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("settings-\(route.rawValue)")
    }
    private func navigationKey(_ title: String, icon: SettingsIllustration.Kind, route: InstrumentPanelKind) -> some View {
        Button { model.endSoundPreview(); present(route) } label: {
            HStack(spacing: 7) {
                SettingsIllustration(kind: icon).frame(width: 44, height: 44)
                Text(L10n.text(title)).technical(12, spacing: 0.4)
                    .lineLimit(1).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }.padding(.horizontal, 10).frame(maxWidth: .infinity).frame(minHeight: 66)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10))
            .accessibilityLabel(L10n.text(title == "PRESETS" ? "Saved presets" : title == "PRACTICE" ? "Practice settings" : title))
            .accessibilityIdentifier(route == .practice ? "practice" : "settings-\(route.rawValue)")
    }
    private var skinKeys: some View {
        HStack(spacing: 9) {
            ForEach(0..<2) { index in
                let selected = model.dark == (index == 1)
                Button { model.dark = index == 1; model.tickFeedback() } label: {
                    HStack(spacing: 10) {
                        LED(on: selected, color: InstrumentPalette.amber, size: 7)
                        Text(L10n.text(index == 0 ? "LIGHT" : "DARK")).technical(12, spacing: 0.8).lineLimit(1).minimumScaleFactor(0.75)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(HardwareButtonStyle(p: InstrumentPalette(dark: false), charcoal: index == 1, radius: 9))
                .accessibilityLabel(L10n.text(index == 0 ? "LIGHT" : "DARK")).accessibilityIdentifier(index == 0 ? "theme-light" : "theme-dark")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
    func menuField(_ title: String, value: String, route: InstrumentPanelKind, fontSize: CGFloat = 21) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(title)).technical(10, spacing: 1.3).fixedSize()
            Button { present(route) } label: {
                HStack { Spacer(minLength: 0); Text(value).font(InstrumentType.value(fontSize)).lineLimit(1).minimumScaleFactor(0.7); Spacer(minLength: 0); Image(systemName: "chevron.down").font(.system(size: 10)) }
                    .padding(.horizontal, 12).frame(height: 46).frame(maxWidth: .infinity)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityIdentifier("settings-\(route.rawValue)").accessibilityLabel(title == "METER" ? L10n.text("Time signature") : title == "DIVISION" ? L10n.text("Subdivision") : "\(L10n.text(title)), \(value)")
        }.frame(maxWidth: .infinity)
    }
}

/// One transport controls the same clock throughout setup, playback and comparison.
struct SettingsPlaybackBar: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    var identifier = "settings-transport"
    var body: some View {
        VStack(spacing: 12) {
            Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5)
            HStack(spacing: 18) {
                Text("\(model.event?.bpm ?? model.bpm) BPM").font(.system(size: 16, weight: .medium).monospacedDigit()).frame(minWidth: 85, alignment: .leading)
                Button { model.endSoundPreview(); model.toggle() } label: {
                    TransportGlyph(playing: model.transportActive).frame(maxWidth: .infinity).frame(height: 48)
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                    .disabled(model.interrupted && !model.transportActive)
                    .accessibilityLabel(model.transportLabel)
                    .accessibilityIdentifier(identifier)
            }
        }
    }
}
