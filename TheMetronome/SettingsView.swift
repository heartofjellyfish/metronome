import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MetronomeModel
    var tunerSettings = false
    var chromaticTuner = false
    @Binding var rememberLastSetup: Bool
    @AppStorage("tuner.reference") private var reference = 440
    @AppStorage("tuner.written") private var written = true
    @AppStorage("tuner.response") private var response = TunerResponse.balanced
    @AppStorage(ChromaticTuningRange.preferenceKey) private var chromaticRange = ChromaticTuningRange.standard
    @AppStorage("tuner.confirmation") private var confirmation = true
    @AppStorage(ControlSkin.preference) private var design = ControlSkin.sculpted
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
                                    settingsHeading("SOUND")
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
                                settingSwitch("Playback sound", isOn: $model.soundEnabled, id: "general-sound")
                            }
                            VStack(spacing: 16) {
                                settingsHeading("Playback")
                                Button { present(.pedal) } label: {
                                    HStack(spacing: 10) {
                                        SettingsIllustration(kind: .pedal).frame(width: 42, height: 34)
                                        Text("Pedal setup").font(InstrumentType.value(16))
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption)
                                    }.padding(.horizontal, 14).frame(height: 50)
                                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("settings-pedal")
                                Button { present(.countIn) } label: {
                                    HStack {
                                        Text("Count-in").font(InstrumentType.value(16))
                                        Spacer()
                                        Text(model.rhythm.countIn == 0 ? L10n.text("Off") : L10n.bars(model.rhythm.countIn))
                                        Image(systemName: "chevron.right").font(.caption)
                                    }.padding(.horizontal, 14).frame(height: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("settings-count-in")
                            }
                        }
                        VStack(spacing: 16) {
                            settingsHeading("Appearance")
                            VStack(spacing: 12) {
                                HStack(spacing: 14) {
                                    Text("COLOR").font(InstrumentType.value(16))
                                    Spacer(minLength: 0)
                                    colorKeys.frame(maxWidth: 260).frame(height: 46)
                                }
                                HStack(spacing: 14) {
                                    Text("DESIGN").font(InstrumentType.value(16))
                                    Spacer(minLength: 0)
                                    designKeys.frame(maxWidth: 260).frame(height: 46)
                                }
                            }
                        }
                        VStack(spacing: 16) {
                            settingsHeading("General")
                            rememberSetupControl
                            settingSwitch("Keep screen awake", isOn: $model.keepLiveScreenAwake, id: "live-screen")
                            settingSwitch("TOUCH FEEDBACK", isOn: $model.haptics, id: "general-haptics")
                        }
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
    private func settingsHeading(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(tunerText(title)).font(.system(size: 17, weight: .semibold)).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Rectangle().fill(p.edge.opacity(0.40)).frame(maxWidth: .infinity).frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var rememberSetupControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            settingSwitch("Remember last setup", isOn: $rememberLastSetup, id: "remember-last-setup")
            Text(L10n.text("Restores your last mode, tuner instrument, and each instrument’s tuning."))
                .font(.footnote)
                .foregroundStyle(p.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var tunerControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeading(chromaticTuner ? "Chromatic" : "Tuner")
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
            if chromaticTuner {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tunerText("In-tune range")).font(InstrumentType.value(16))
                        .accessibilityAddTraits(.isHeader)
                    optionSelector(ChromaticTuningRange.allCases, selected: chromaticRange,
                                  title: { "\(tunerText($0.title)) ±\(Int($0.cents))¢" },
                                  id: { "tuner-chromatic-range-" + $0.rawValue }) { chromaticRange = $0 }
                    Text(tunerText("How close the pitch must be to turn green."))
                        .font(.footnote)
                        .foregroundStyle(p.ink.opacity(0.72))
                }
            } else {
                Text(tunerText("Tuning response")).font(InstrumentType.value(16))
                optionSelector(TunerResponse.allCases, selected: response, title: { tunerText($0.title) },
                              id: { "tuner-response-" + $0.rawValue }) { response = $0 }
            }
            settingSwitch("In-tune feedback", isOn: $confirmation, id: "tuner-confirmation")
        }
        if !chromaticTuner && TunerProfile.showsExtendedCatalog {
            VStack(alignment: .leading, spacing: 8) {
                settingsHeading("Note names for transposing instruments")
                Text(tunerText("For B♭ clarinet, alto sax, piccolo and similar instruments. "
                    + "Written pitch is the note on your score. Concert pitch is what you hear. "
                    + "Choose which one appears in large type."))
                    .font(.footnote)
                    .foregroundStyle(p.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tuner-pitch-explanation")
                optionSelector([false, true], selected: written,
                              title: { tunerText($0 ? "Written first" : "Concert first") },
                              id: { $0 ? "tuner-pitch-written" : "tuner-pitch-concert" }) { written = $0 }
            }
        }
    }

    private func optionSelector<Option: Hashable>(_ values: [Option], selected: Option,
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

    private func settingSwitch(_ title: String, isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            Text(tunerText(title)).font(InstrumentType.value(16))
        }
        .frame(minHeight: 44)
        .tint(Color(hex: 0x55764D))
        .accessibilityIdentifier(id)
    }

    private var designKeys: some View {
        optionSelector(ControlSkin.allCases, selected: design,
                       title: { L10n.text($0 == .sculpted ? "Relief" : "Flat") },
                       id: { "skin-" + $0.rawValue }) {
            design = $0
            model.tickFeedback()
        }
    }

    private var colorKeys: some View {
        optionSelector([false, true], selected: model.dark,
                       title: { L10n.text($0 ? "DARK" : "LIGHT") },
                       id: { $0 ? "theme-dark" : "theme-light" }) {
            model.dark = $0
            model.tickFeedback()
        }
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
