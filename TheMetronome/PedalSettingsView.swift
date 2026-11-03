import SwiftUI

/// A dedicated setup page. Binding changes stay inline, without nesting another panel.
struct PedalSettingsView: View {
    @ObservedObject var model: MetronomeModel
    @ObservedObject var pedal: PedalControl
    let p: InstrumentPalette
    let close: () -> Void
    @State private var midiPicker = false
    private let groups: [[PedalAction]] = [[.toggle, .tap], [.previous, .next], [.slower, .faster]]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Button { pedal.cancelLearning(); close() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 19, weight: .medium))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Done").accessibilityIdentifier("close-panel")
                Text("LIVE MODE").technical(20, spacing: 2)
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Tap an action. Press your pedal.")
                        .font(.system(size: 27, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                    VStack(spacing: 18) {
                        ForEach(groups.indices, id: \.self) { index in
                            VStack(spacing: 0) {
                                ForEach(groups[index]) { action in
                                    bindingRow(action)
                                    if action != groups[index].last {
                                        Rectangle().fill(p.edge.opacity(0.35)).frame(height: 0.5).padding(.horizontal, 16)
                                    }
                                }
                            }.background(p.light.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.edge.opacity(0.35), lineWidth: 0.7))
                        }
                    }
                    Text("Songs follow your saved preset order.").font(.system(size: 14)).foregroundStyle(p.muted)
                    Button { pedal.cancelLearning(); pedal.enableMIDI(); midiPicker = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Connect Bluetooth MIDI")
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.system(size: 12))
                        }.font(.system(size: 16, weight: .medium)).padding(16)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 12)).accessibilityIdentifier("pedal-midi")
                    if pedal.bindings.values.contains(where: { $0.kind == .keyboard }) {
                        Text("Keyboard pedals work while this app is on screen. For lock-screen control, use a media or MIDI mode.")
                            .font(.system(size: 14)).foregroundStyle(p.ink)
                    }
                    Text("Test your pedal with the screen locked before a performance. Calls and alarms can interrupt audio.")
                        .font(.system(size: 14)).foregroundStyle(p.muted).lineSpacing(3)
                    if let problem = pedal.problem { Text(problem).foregroundStyle(InstrumentPalette.orange) }
                }.padding(.horizontal, 26).padding(.bottom, 28).frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize)
        }.foregroundStyle(p.ink)
            .background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light)
            .accessibilityAddTraits(.isModal)
            .onDisappear { pedal.cancelLearning() }
            .sheet(isPresented: $midiPicker) {
                NavigationStack {
                    BluetoothMIDIPicker().navigationTitle(Text("Bluetooth MIDI"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { midiPicker = false } } }
                }
            }
    }
    private func bindingRow(_ action: PedalAction) -> some View {
        let listening = pedal.learning == action
        let binding = pedal.bindings[action]
        return HStack(spacing: 0) {
            Button { listening ? pedal.cancelLearning() : model.beginPedalLearning(action) } label: {
                HStack(spacing: 12) {
                    Text(action.title).font(.system(size: 17, weight: action == .toggle ? .semibold : .regular))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if listening {
                        Text("Press now…").font(.system(size: 14, weight: .medium)).foregroundStyle(InstrumentPalette.orange)
                    } else if let binding {
                        Text(binding.label).font(.system(size: 13, design: .monospaced)).foregroundStyle(p.muted)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Image(systemName: "plus").font(.system(size: 16, weight: .light)).foregroundStyle(p.muted)
                    }
                }.padding(.leading, 16).padding(.trailing, 12).frame(minHeight: 64).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("pedal-\(action.rawValue)")
                .accessibilityValue(listening ? L10n.text("Press now…") : binding?.label ?? "")
            if listening || binding != nil {
                Button { listening ? pedal.cancelLearning() : pedal.clear(action) } label: {
                    Image(systemName: listening ? "xmark" : "minus.circle")
                        .font(.system(size: 16)).foregroundStyle(p.muted).frame(width: 44, height: 64)
                }.buttonStyle(.plain).accessibilityLabel(listening ? L10n.text("Cancel") : L10n.text("Remove assignment"))
            }
        }.background(listening ? InstrumentPalette.orange.opacity(0.07) : Color.clear)
    }
}
