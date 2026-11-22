import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MetronomeModel
    var tunerSettings = false
    @Binding var rememberLastSetup: Bool
    @AppStorage("tuner.reference") private var reference = 440
    @AppStorage("tuner.written") private var written = true
    @AppStorage("tuner.response") private var response = TunerResponse.balanced
    @AppStorage("tuner.confirmation") private var confirmation = true
    #if DEBUG
    @AppStorage(ControlSkin.preference) private var previewSkin = ControlSkin.sculpted
    #endif
    @Environment(\.dismiss) private var dismiss
    @State private var panel: InstrumentPanelKind?
    @State private var panelSession = UUID()
    private func present(_ kind: InstrumentPanelKind) { panelSession = UUID(); panel = kind }
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
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
                ScrollView {
                    VStack(spacing: 28) {
                        if tunerSettings {
                            tunerControls
                        } else {
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
                                SectionLabel(text: "METRONOME", p: p)
                                Button { present(.pedal) } label: {
                                    HStack(spacing: 10) {
                                        SettingsIllustration(kind: .pedal).frame(width: 42, height: 34)
                                        Text("Pedal setup").font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption)
                                    }.padding(.horizontal, 14).frame(height: 50)
                                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("settings-pedal")
                                Button { present(.countIn) } label: {
                                    HStack {
                                        Text("Count-in").technical(11, spacing: 1)
                                        Spacer()
                                        Text(model.rhythm.countIn == 0 ? L10n.text("Off") : L10n.bars(model.rhythm.countIn))
                                        Image(systemName: "chevron.right").font(.caption)
                                    }.padding(.horizontal, 14).frame(height: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("settings-count-in")
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
                            }
                        }
                        VStack(spacing: 16) {
                            SectionLabel(text: "02 GENERAL", p: p)
                            rememberSetupControl
                            ViewThatFits(in: .horizontal) {
                                HStack {
                                    Text("Keep screen awake").technical(11, spacing: 1)
                                    Spacer(minLength: 0)
                                    liveScreenKeys
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Keep screen awake").technical(11, spacing: 1)
                                    liveScreenKeys.frame(maxWidth: .infinity, alignment: .trailing)
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
                        #if DEBUG
                        HStack {
                            Text("Button finish").technical(11, spacing: 1)
                            Spacer()
                            ForEach([ControlSkin.sculpted, .flat], id: \.self) { skin in
                                Button { previewSkin = skin } label: {
                                    Text(L10n.text(skin == .sculpted ? "Raised" : "Flat finish")).frame(minWidth: 60, minHeight: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: previewSkin == skin))
                                    .accessibilityIdentifier("skin-" + skin.rawValue)
                                    .accessibilityAddTraits(previewSkin == skin ? .isSelected : [])
                            }
                        }
                        #endif
                    }.padding(.horizontal, 26).padding(.bottom, 24)
                }.scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("settings-scroll")
            if !tunerSettings {
                SettingsPlaybackBar(model: model, p: p).padding(.horizontal, 26).padding(.bottom, 12)
            }
        }.frame(maxWidth: 460).frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain).accessibilityHidden(panel != nil).allowsHitTesting(panel == nil)
            .foregroundStyle(p.ink).background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light)
            .overlay { if let panel { InstrumentPanel(model: model, kind: panel) { self.panel = nil }.id(panelSession) } }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onDisappear { model.endSoundPreview() }
            .onChange(of: model.error) { _, value in if value != nil { present(.audio) } }
    }
    private var rememberSetupControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $rememberLastSetup) {
                Text(L10n.text("Remember last setup")).font(InstrumentType.value(16))
            }
            .tint(Color(hex: 0x55764D))
            .accessibilityIdentifier("remember-last-setup")
            Text(L10n.text("Restores your last mode, tuner instrument, and each instrument’s tuning."))
                .font(.footnote)
                .foregroundStyle(p.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tunerControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "TUNER", p: p)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tunerText("Reference pitch")).font(InstrumentType.value(16))
                    Text("A4 · \(reference) Hz").monospacedDigit()
                        .accessibilityIdentifier("settings-tuner-reference")
                }
                Spacer()
                ForEach([-1, 1], id: \.self) { step in
                    Button { reference += step } label: {
                        Text(step < 0 ? "−" : "+").frame(width: 44, height: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p))
                        .disabled(!(400...480).contains(reference + step))
                        .accessibilityLabel(L10n.text(step < 0 ? "Decrease reference pitch" : "Increase reference pitch"))
                        .accessibilityIdentifier(step < 0 ? "tuner-reference-down" : "tuner-reference-up")
                }
            }
            Text(tunerText("Tuning response")).font(InstrumentType.value(16))
            tunerSelector(TunerResponse.allCases, selected: response, title: { tunerText($0.title) },
                          id: { "tuner-response-" + $0.rawValue }) { response = $0 }
            VStack(alignment: .leading, spacing: 8) {
                Text(tunerText("Note names for transposing instruments"))
                    .font(InstrumentType.value(16))
                    .accessibilityAddTraits(.isHeader)
                Text(tunerText("For B♭ clarinet, alto sax, piccolo and similar instruments. "
                    + "Written pitch is the note on your score. Concert pitch is what you hear. "
                    + "Choose which one appears in large type."))
                    .font(.footnote)
                    .foregroundStyle(p.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tuner-pitch-explanation")
                tunerSelector([false, true], selected: written,
                              title: { tunerText($0 ? "Written first" : "Concert first") },
                              id: { $0 ? "tuner-pitch-written" : "tuner-pitch-concert" }) { written = $0 }
            }
            Toggle(tunerText("In-tune feedback"), isOn: $confirmation)
                .tint(Color(hex: 0x55764D))
                .accessibilityIdentifier("tuner-confirmation")
        }
    }

    private func tunerSelector<Option: Hashable>(_ values: [Option], selected: Option,
                                                 title: @escaping (Option) -> String, id: @escaping (Option) -> String,
                                                 choose: @escaping (Option) -> Void) -> some View {
        HStack(spacing: 2) {
            ForEach(values, id: \.self) { value in
                Button { choose(value) } label: {
                    Text(title(value)).font(InstrumentType.value(14)).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: selected == value))
                .accessibilityIdentifier(id(value))
                .accessibilityAddTraits(selected == value ? .isSelected : [])
            }
        }.padding(2).insetPanel(p, radius: 10)
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
