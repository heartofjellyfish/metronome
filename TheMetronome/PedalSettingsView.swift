import Combine
import SwiftUI

struct PedalSettingsView: View {
    @ObservedObject var model: MetronomeModel
    @ObservedObject var pedal: PedalControl
    let p: InstrumentPalette
    let close: () -> Void
    @State private var midiPicker = false
    private enum Detail { case profiles, connection }
    @State private var detail: Detail?
    @State private var profileName = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var keyWidth: CGFloat = 138
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button { pedal.cancelLearning(); close() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 19, weight: .medium)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Done").accessibilityIdentifier("close-panel")
                Text("Pedal setup").font(.system(size: 25, weight: .semibold))
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    inputStatus
                    bindingGroup("Playback", actions: [.toggle])
                    bindingGroup("Songs", actions: [.previous, .next])
                    bindingGroup("Tempo", actions: [.tap, .slower, .faster])
                    if let conflict = pedal.conflict {
                        VStack(spacing: 14) {
                            Text(L10n.format("This key is assigned to %@. Move it?", conflict.title)).font(.subheadline)
                            HStack(spacing: 12) {
                                Button { pedal.resolveConflict(replace: false) } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p))
                                Button { pedal.resolveConflict(replace: true) } label: { Text("Move").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                            }
                        }.padding(16).insetPanel(p, radius: 12)
                    }
                    VStack(spacing: 0) {
                        Divider()
                        disclosure("Pedal profiles", .profiles, id: "pedal-profiles",
                                   value: pedal.profiles.count > 1 ? pedal.profileName : nil)
                        if detail == .profiles { profilePicker }
                        if pedal.inputAvailable {
                            Divider()
                            disclosure("Connection help", .connection, id: "pedal-help")
                            if detail == .connection { connectionHelp }
                        }
                    }
                    if let problem = pedal.problem { Text(problem).font(.subheadline).foregroundStyle(InstrumentPalette.orange) }
                }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 24)
                    .frame(maxWidth: 520).frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize)
             .scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(p.ink).background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light).accessibilityAddTraits(.isModal)
            .onAppear { pedal.setupVisible = true; model.preparePedalInput(); pedal.enableMIDI() }
            .onDisappear { pedal.setupVisible = false; pedal.cancelLearning() }
            .sheet(isPresented: $midiPicker) {
                NavigationStack {
                    BluetoothMIDIPicker()
                        .navigationTitle(Text("Connect MIDI pedal"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { midiPicker = false } } }
                }
            }
    }
    @ViewBuilder private var inputStatus: some View {
        if !pedal.inputAvailable && pedal.learning == nil {
            VStack(alignment: .leading, spacing: 6) {
                statusLine(L10n.text("No input detected"), icon: "cable.connector")
                Text("Turn on your pedal, then select it in Settings → Bluetooth.")
                    .font(.subheadline).foregroundStyle(p.muted)
                disclosure("Not listed in Bluetooth?", .connection, id: "pedal-help")
                if detail == .connection { midiHelp }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).insetPanel(p, radius: 12)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if !pedal.midiInputNames.isEmpty && (pedal.isMIDIProfile || (!pedal.keyboardDetected && pedal.lastDirectInput == nil)) {
                    ForEach(Array(pedal.midiInputNames.enumerated()), id: \.offset) { _, name in
                        let text = name == "MIDI" ? L10n.text("MIDI input detected") : L10n.format("MIDI connected · %@", name)
                        statusLine(text, icon: "pianokeys")
                    }
                } else if pedal.lastDirectInput == .media {
                    statusLine(L10n.text("Media button received"), icon: "playpause")
                } else if pedal.inputAvailable {
                    statusLine(L10n.text("Input device detected"), icon: "switch.2")
                }
                Text(hint).font(.subheadline).foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 38, alignment: .topLeading)
                    .accessibilityIdentifier("pedal-hint")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusLine(_ title: String, icon: String) -> some View {
        Label { Text(verbatim: title) } icon: { Image(systemName: icon) }
            .font(.subheadline.weight(.semibold))
    }

    private func bindingGroup(_ title: LocalizedStringKey, actions: [PedalAction]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(p.muted)
                    .layoutPriority(1)
                    .accessibilityAddTraits(.isHeader)
                Rectangle().fill(p.edge.opacity(0.55)).frame(height: 1)
            }
            ForEach(actions) { bindingRow($0) }
        }
    }

    private func disclosure(_ title: LocalizedStringKey, _ section: Detail, id: String, value: String? = nil) -> some View {
        Button {
            pedal.cancelLearning()
            dismissTextInput()
            detail = detail == section ? nil : section
        } label: {
            HStack(spacing: 10) {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                if let value { Text(verbatim: value).font(.subheadline).foregroundStyle(p.muted).lineLimit(1) }
                Image(systemName: detail == section ? "chevron.up" : "chevron.down").font(.caption)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private var profilePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("iOS does not identify page-turning pedals. Choose saved controls when switching pedals.")
                .font(.subheadline).foregroundStyle(p.muted)
            ForEach(pedal.profiles) { profile in
                Button {
                    pedal.selectProfile(profile.id)
                    dismissTextInput()
                    detail = nil
                } label: {
                    HStack {
                        Text(verbatim: profile.displayName)
                        Spacer()
                        if pedal.profileID == profile.id { Image(systemName: "checkmark") }
                    }.padding(.horizontal, 12).frame(minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p))
                    .accessibilityAddTraits(pedal.profileID == profile.id ? .isSelected : [])
                    .accessibilityIdentifier("pedal-profile-" + profile.id)
            }
            HStack {
                TextField("Name a new pedal", text: $profileName).padding(12).insetPanel(p, radius: 8)
                    .accessibilityIdentifier("pedal-profile-name").submitLabel(.done)
                    .onSubmit { addProfile() }
                Button(action: addProfile) { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Add profile")
                    .accessibilityIdentifier("pedal-add-profile")
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(.bottom, 14)
    }

    private func addProfile() {
        guard !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pedal.addProfile(profileName)
        dismissTextInput()
        profileName = ""
        detail = nil
    }

    private var connectionHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turn on your pedal, then select it in Settings → Bluetooth.")
            Divider()
            midiHelp
            if pedal.bindings.values.contains(where: { $0.kind == .keyboard }) {
                Text("Keyboard pedals work while this app is on screen. For lock-screen control, use a media or MIDI mode.")
            }
        }.font(.subheadline).foregroundStyle(p.muted)
    }

    private var midiHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Some pedals connect inside the app. Search below, then select your pedal by name.")
                .font(.subheadline).foregroundStyle(p.muted)
            midiButton
        }
    }

    private var midiButton: some View {
        Button {
            pedal.cancelLearning()
            pedal.problem = nil
            model.preparePedalInput()
            pedal.enableMIDI()
            midiPicker = true
        } label: {
            Label("Find a MIDI pedal", systemImage: "magnifyingglass").font(.subheadline)
                .padding(.horizontal, 12).frame(minHeight: 44)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).foregroundStyle(p.ink)
            .accessibilityIdentifier("pedal-midi")
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
            }
        }
    }
    private func bindingButton(_ action: PedalAction) -> some View {
        let listening = pedal.learning == action
        let binding = pedal.bindings[action]
        let caption = listening ? L10n.text("Learning") : (binding?.displayLabel ?? L10n.text("Learn"))
        return Button {
            if listening { pedal.cancelLearning() } else { dismissTextInput(); detail = nil; model.beginPedalLearning(action) }
        } label: {
            HStack(spacing: 8) {
                BindingLamp(listening: listening, assigned: binding != nil, reduceMotion: reduceMotion,
                            action: action, presses: pedal.actionPresses)
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
        if pedal.unassignedPress { return L10n.text("This switch is unassigned. Tap Learn beside an action, then press it again.") }
        return L10n.text(pedal.hasBindingForDetectedInput ? "Bindings saved. Press your pedal to try them." : "Tap Learn beside an action, then press the pedal switch you want to use.")
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

struct BindingLamp: View {
    let listening: Bool
    let assigned: Bool
    let reduceMotion: Bool
    let action: PedalAction
    let presses: PassthroughSubject<PedalAction, Never>
    @State private var lastPress: ContinuousClock.Instant?

    var body: some View {
        lamp
            .onReceive(presses) { if $0 == action { lastPress = .now } }
            .task(id: lastPress) {
                guard lastPress != nil else { return }
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                lastPress = nil
            }
    }

    @ViewBuilder private var lamp: some View {
        if listening && !reduceMotion {
            TimelineView(.periodic(from: .now, by: 0.65)) { time in
                LED(on: Int(time.date.timeIntervalSinceReferenceDate / 0.65).isMultiple(of: 2), color: .red, size: 7)
            }.accessibilityHidden(true)
        } else if listening {
            LED(on: true, color: .red, size: 7)
        } else if assigned {
            let lit = lastPress != nil
            LED(on: true, color: lit ? Color(hex: 0x7EE991) : Color(hex: 0x38A850),
                size: 7, intensity: lit ? 1 : 0.35)
                .overlay { if lit { Circle().stroke(Color(hex: 0x54BA68), lineWidth: 1).frame(width: 11, height: 11) } }
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
