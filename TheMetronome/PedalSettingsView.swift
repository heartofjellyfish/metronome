import SwiftUI

struct PedalSettingsView: View {
    @ObservedObject var model: MetronomeModel
    @ObservedObject var pedal: PedalControl
    let p: InstrumentPalette
    let close: () -> Void
    @State private var midiPicker = false
    @State private var help = false
    @State private var choosingProfile = false
    @State private var profileName = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var keyWidth: CGFloat = 138
    private let groups: [[PedalAction]] = [[.toggle, .tap], [.previous, .next], [.slower, .faster]]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button { pedal.cancelLearning(); close() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 19, weight: .medium)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Done").accessibilityIdentifier("close-panel")
                Text("Pedal setup").font(.system(size: 25, weight: .semibold))
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(pedal.connectedName ?? pedal.profileName).font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Button { choosingProfile.toggle(); pedal.cancelLearning() } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Saved controls")
                            }
                            Text(pedal.connectedName != nil ? L10n.text("Connected") : pedal.isMIDIProfile ? L10n.text("Not connected. Assignments saved.") : L10n.text("Assignments saved on this iPhone."))
                                .font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        if choosingProfile {
                            VStack(spacing: 12) {
                                ForEach(pedal.profiles) { profile in
                                    Button { pedal.selectProfile(profile.id); choosingProfile = false } label: {
                                        HStack { Text(profile.name); Spacer(); if pedal.profileID == profile.id { Image(systemName: "checkmark") } }.padding(12).frame(minHeight: 44)
                                    }.buttonStyle(HardwareButtonStyle(p: p))
                                }
                                HStack {
                                    TextField("Name a new pedal", text: $profileName).padding(12).insetPanel(p, radius: 8)
                                    Button { pedal.addProfile(profileName); profileName = ""; choosingProfile = false } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.buttonStyle(HardwareButtonStyle(p: p)).disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                                Text("iOS does not identify page-turning pedals. Choose saved controls when switching pedals.").font(.subheadline).foregroundStyle(p.muted)
                            }
                        }
                        bindingList.id("bindings")
                        if let conflict = pedal.conflict {
                            VStack(spacing: 14) {
                                Text(L10n.format("This key is assigned to %@. Move it?", conflict.title)).font(.subheadline)
                                HStack(spacing: 12) {
                                    Button { pedal.resolveConflict(replace: false) } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p))
                                    Button { pedal.resolveConflict(replace: true) } label: { Text("Move").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                                }
                            }.padding(16).insetPanel(p, radius: 12)
                        }
                        Text(hint).font(.subheadline).foregroundStyle(p.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44, alignment: .top)
                            .accessibilityIdentifier("pedal-hint")
                        Button { help.toggle() } label: {
                            HStack { Text("Connection help"); Spacer(); Image(systemName: help ? "chevron.up" : "chevron.down") }.font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("pedal-help")
                        if help {
                        Text("Page-turning pedals: pair in iPhone Settings > Bluetooth, then return here.").font(.subheadline).foregroundStyle(p.muted)
                        Button {
                            pedal.cancelLearning()
                            pedal.problem = nil
                            model.preparePedalInput()
                            pedal.enableMIDI()
                            midiPicker = true
                        } label: {
                            Text("Connect MIDI pedal").font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16).frame(height: 44)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10))
                            .accessibilityIdentifier("pedal-midi")
                        if pedal.bindings.values.contains(where: { $0.kind == .keyboard }) {
                            Text("Keyboard pedals work while this app is on screen. For lock-screen control, use a media or MIDI mode.")
                                .font(.subheadline).foregroundStyle(p.muted)
                        }
                        }
                        if let problem = pedal.problem { Text(problem).font(.subheadline).foregroundStyle(InstrumentPalette.orange) }
                    }.padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 32)
                        .frame(maxWidth: 520).frame(maxWidth: .infinity)
                }.scrollBounceBehavior(.basedOnSize)
            }
        }.foregroundStyle(p.ink).background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light).accessibilityAddTraits(.isModal)
            .onAppear { pedal.setupVisible = true; model.preparePedalInput(); pedal.enableMIDI() }
            .onDisappear { pedal.setupVisible = false; pedal.cancelLearning() }
            .sheet(isPresented: $midiPicker) {
                NavigationStack {
                    VStack(spacing: 0) {
                        BluetoothMIDIPicker()
                        Text("Page-turning pedals: pair in iPhone Settings > Bluetooth, then return here.")
                            .font(.subheadline).padding()
                    }.navigationTitle(Text("Connect Bluetooth pedal"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { midiPicker = false } } }
                }
            }
    }
    private var bindingList: some View {
        VStack(spacing: 20) {
            ForEach(groups.indices, id: \.self) { index in
                VStack(spacing: 12) { ForEach(groups[index]) { bindingRow($0) } }
            }
        }
    }
    @ViewBuilder private func bindingRow(_ action: PedalAction) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                Text(action.title).font(.body.weight(.medium))
                bindingButton(action).frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(spacing: 16) {
                Text(action.title).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                bindingButton(action)
            }.padding(.trailing, 12)
        }
    }
    private func bindingButton(_ action: PedalAction) -> some View {
        let listening = pedal.learning == action
        let binding = pedal.bindings[action]
        let caption = listening ? L10n.text("Learning") : (binding?.displayLabel ?? L10n.text("Learn"))
        return Button {
            if listening { pedal.cancelLearning() } else { model.beginPedalLearning(action) }
        } label: {
            HStack(spacing: 8) {
                BindingLamp(listening: listening, assigned: binding != nil, reduceMotion: reduceMotion)
                Text(caption).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 10).padding(.vertical, 12)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : min(keyWidth, 180))
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil).frame(minHeight: 48)
        }.buttonStyle(PedalKeyStyle(p: p, held: listening))
            .accessibilityIdentifier("pedal-\(action.rawValue)")
            .accessibilityLabel(action.title).accessibilityValue(caption)
            .accessibilityHint(listening ? L10n.text("Cancel") : L10n.text("Tap the key name to reassign."))
            .contextMenu {
                if binding != nil { Button("Remove assignment", role: .destructive) { pedal.clear(action) } }
            }
    }
    private var hint: String {
        if let action = pedal.learning { return L10n.format("Press your pedal now to assign %@. Tap again to cancel.", action.title) }
        return L10n.text(pedal.bindings.isEmpty ? "Tap Learn, then press your pedal." : "Assigned. Tap the key name to reassign.")
    }
}

struct PerformancePreparation: View {
    let p: InstrumentPalette
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            note("Avoid call interruptions", "When you do not need calls: turn on Airplane Mode, turn off Wi-Fi, and keep Bluetooth on. Disable alarms and timers during your performance. Restore your settings afterward.")
            note("Resume on the same beat timeline", "Audio may pause. When iOS allows automatic recovery, playback follows the original beat timeline instead of restarting from beat one.")
            note("Try a press before going on stage", "Check that your pedal starts and stops playback.")
        }.padding(.bottom, 12).accessibilityIdentifier("performance-preparation-notes")
    }
    private func note(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.body.weight(.semibold)); Text(detail).font(.subheadline).foregroundStyle(p.muted).lineSpacing(3) }
    }
}

private struct BindingLamp: View {
    let listening: Bool
    let assigned: Bool
    let reduceMotion: Bool
    var body: some View {
        if listening && !reduceMotion {
            TimelineView(.periodic(from: .now, by: 0.65)) { time in
                LED(on: Int(time.date.timeIntervalSinceReferenceDate / 0.65).isMultiple(of: 2), color: .red, size: 7)
            }.accessibilityHidden(true)
        } else if listening || assigned {
            LED(on: true, color: listening ? .red : Color(red: 0.22, green: 0.67, blue: 0.31), size: 7)
        } else {
            Circle().fill(Color.gray.gradient).frame(width: 7, height: 7).overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 0.5)).accessibilityHidden(true)
        }
    }
}
private struct PedalKeyStyle: ButtonStyle {
    let p: InstrumentPalette
    let held: Bool
    func makeBody(configuration: Configuration) -> some View {
        let pressed = held || configuration.isPressed
        configuration.label.foregroundStyle(p.ink)
            .background { HardwareKeySurface(p: p, radius: 12, pressed: pressed) }
            .offset(y: pressed ? 1.6 : 0)
            .animation(.easeOut(duration: 0.10), value: pressed)
    }
}
private struct PedalIllustration: View {
    let p: InstrumentPalette
    var body: some View {
        ZStack {
            HardwareKeySurface(p: p, charcoal: true, radius: 16)
            VStack(spacing: 20) {
                VStack(spacing: 7) { ForEach(0..<8) { _ in Capsule().fill(.black.opacity(0.4)).frame(height: 2) } }
                    .padding(12).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                LED(on: false, size: 7)
            }.padding(13)
        }
    }
}
