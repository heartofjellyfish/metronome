import SwiftUI

struct PedalSettingsView: View {
    @ObservedObject var model: MetronomeModel
    @ObservedObject var pedal: PedalControl
    let p: InstrumentPalette
    let close: () -> Void
    @State private var bindingTab = false
    @State private var midiPicker = false
    @State private var preparation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            HStack(spacing: 0) {
                tab("Connect pedal", selected: !bindingTab, id: "pedal-tab-connect") { pedal.cancelLearning(); bindingTab = false }
                tab("Assign controls", selected: bindingTab, id: "pedal-tab-bind") { bindingTab = true }
            }.padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 20)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if bindingTab {
                            bindingList.id("bindings")
                            Text(hint).font(.subheadline).foregroundStyle(p.muted)
                                .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44, alignment: .top)
                                .accessibilityIdentifier("pedal-hint")
                            if !pedal.inputAvailable {
                                Button { bindingTab = false } label: {
                                    Text("Connect pedal").font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16).frame(height: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p, radius: 10))
                                    .accessibilityIdentifier("pedal-connect-from-bindings")
                            }
                            Divider().overlay(p.edge.opacity(0.2))
                            HStack {
                                Text("Before performing").font(.body.weight(.medium))
                                Spacer()
                                Button {
                                    pedal.cancelLearning()
                                    preparation.toggle()
                                    if !preparation { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo("bindings", anchor: .top) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(preparation ? "Collapse" : "Expand")
                                        Image(systemName: preparation ? "chevron.up" : "chevron.down").font(.caption)
                                    }.font(.subheadline).padding(.horizontal, 12).frame(minHeight: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p, radius: 12)).accessibilityIdentifier("pedal-preparation")
                            }
                            if preparation { preparationNotes }
                        } else { connection }
                        if let problem = pedal.problem { Text(problem).font(.subheadline).foregroundStyle(InstrumentPalette.orange) }
                    }.padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 32)
                        .frame(maxWidth: 520).frame(maxWidth: .infinity)
                }.scrollBounceBehavior(.basedOnSize)
            }
        }.foregroundStyle(p.ink).background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light).accessibilityAddTraits(.isModal)
            .onAppear { pedal.setupVisible = true; bindingTab = !pedal.bindings.isEmpty }
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
    private func tab(_ title: LocalizedStringKey, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(spacing: 5) {
                    Text(title).font(.body.weight(selected ? .semibold : .regular)).foregroundStyle(selected ? p.ink : p.muted)
                }.frame(minHeight: 32)
                Rectangle().fill(selected ? InstrumentPalette.amber : .clear).frame(height: 2)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var connection: some View {
        VStack(spacing: 32) {
            PedalIllustration(p: p).frame(width: 110, height: 150).padding(.top, 25).padding(.bottom, 12).accessibilityHidden(true)
            Text("Turn on iPhone Bluetooth and put your pedal in pairing mode.")
                .font(.body.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
            Button { pedal.problem = nil; model.preparePedalInput(); pedal.enableMIDI(); midiPicker = true } label: {
                Text("Connect Bluetooth pedal").font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 58)
            }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true, radius: 14)).accessibilityIdentifier("pedal-midi")
            Text("After pairing, press your pedal once, then open Assign controls.").font(.subheadline).foregroundStyle(p.muted).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var bindingList: some View {
        VStack(spacing: 20) {
            ForEach(groups.indices, id: \.self) { index in
                VStack(spacing: 12) { ForEach(groups[index]) { bindingRow($0) } }
            }
        }
    }
    private func bindingRow(_ action: PedalAction) -> some View {
        HStack(spacing: 16) {
            Text(action.title).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            bindingButton(action)
        }.padding(.trailing, 12)
    }
    private func bindingButton(_ action: PedalAction) -> some View {
        let listening = pedal.learning == action
        let binding = pedal.bindings[action]
        let caption = listening ? L10n.text("Learning") : (binding?.displayLabel ?? L10n.text("Learn"))
        return Button {
            guard pedal.inputAvailable else { return }
            if listening { pedal.cancelLearning() } else { model.beginPedalLearning(action) }
        } label: {
            HStack(spacing: 8) {
                BindingLamp(listening: listening, assigned: binding != nil && pedal.inputAvailable, reduceMotion: reduceMotion)
                Text(caption).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 10).padding(.vertical, 12)
                .frame(width: min(keyWidth, 180)).frame(minHeight: 48)
        }.buttonStyle(PedalKeyStyle(p: p, held: listening))
            .disabled(!pedal.inputAvailable)
            .opacity(pedal.inputAvailable ? 1 : 0.45)
            .accessibilityIdentifier("pedal-\(action.rawValue)")
            .accessibilityLabel(action.title).accessibilityValue(caption)
            .accessibilityHint(listening ? L10n.text("Cancel") : L10n.text("Tap the key name to reassign."))
            .contextMenu {
                if binding != nil { Button("Remove assignment", role: .destructive) { pedal.clear(action) } }
            }
    }
    private var hint: String {
        if !pedal.inputAvailable { return L10n.text("Connect your pedal, then press it once.") }
        if let action = pedal.learning { return L10n.format("Press your pedal now to assign %@. Tap again to cancel.", action.title) }
        return L10n.text(pedal.bindings.isEmpty ? "Tap Learn, then press the pedal key you want to use." : "Assigned. Tap the key name to reassign.")
    }
    private var preparationNotes: some View {
        VStack(alignment: .leading, spacing: 24) {
            note("Avoid call interruptions", "When you do not need calls: turn on Airplane Mode, turn off Wi-Fi, and keep Bluetooth on. Disable alarms and timers during your performance. Restore your settings afterward.")
            note("Resume on the same beat timeline", "Audio may pause. When iOS allows automatic recovery, playback follows the original beat timeline instead of restarting from beat one.")
            note("Try a press before going on stage", "Check that your pedal starts and stops playback.")
            if pedal.bindings.values.contains(where: { $0.kind == .keyboard }) {
                Text("Keyboard pedals work while this app is on screen. For lock-screen control, use a media or MIDI mode.").font(.subheadline).foregroundStyle(p.muted)
            }
        }.padding(.bottom, 12).accessibilityIdentifier("pedal-preparation-notes")
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
