import SwiftUI

struct PedalSettingsView: View {
    @ObservedObject var model: MetronomeModel
    @ObservedObject var pedal: PedalControl
    let p: InstrumentPalette
    @State private var midiPicker = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap an action. Press your pedal.").font(.system(size: 20, weight: .medium))
            Text("Songs follow your saved preset order.").font(.system(size: 14)).foregroundStyle(p.muted)
            ForEach(PedalAction.allCases) { action in
                VStack(alignment: .leading, spacing: 8) {
                    Button { pedal.learning == action ? pedal.cancelLearning() : model.beginPedalLearning(action) } label: {
                        HStack(spacing: 12) {
                            Text(action.title).font(.system(size: 17, weight: .medium))
                            Spacer(minLength: 4)
                            Text(pedal.learning == action ? L10n.text("Press now…") : pedal.bindings[action]?.label ?? "—")
                                .font(.system(size: 13, design: .monospaced)).foregroundStyle(pedal.learning == action ? InstrumentPalette.orange : p.muted)
                                .multilineTextAlignment(.trailing)
                        }.padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 48)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityIdentifier("pedal-\(action.rawValue)")
                    if pedal.learning == action {
                        HStack {
                            Button("Cancel") { pedal.cancelLearning() }
                            Spacer()
                            if pedal.bindings[action] != nil { Button("Remove assignment") { pedal.clear(action) } }
                        }.font(.system(size: 14)).padding(.horizontal, 4)
                    }
                }
            }
            Text(model.presetCaption).font(.system(size: 13, weight: .medium)).accessibilityIdentifier("live-song")
            if pedal.bindings.values.contains(where: { $0.kind == .keyboard }) {
                Text("Keyboard pedals work while this app is on screen. For lock-screen control, use a media or MIDI mode.")
                    .font(.system(size: 14)).foregroundStyle(p.ink)
            }
            Button { pedal.enableMIDI(); midiPicker = true } label: {
                HStack { Text("Connect Bluetooth MIDI"); Spacer(); Image(systemName: "chevron.right") }
                    .font(.system(size: 15)).padding(14)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityIdentifier("pedal-midi")
            Text("Test your pedal with the screen locked before a performance. Calls and alarms can interrupt audio.")
                .font(.system(size: 14)).foregroundStyle(p.muted)
            if !pedal.bindings.isEmpty {
                Button("Remove all assignments") { pedal.clearAll() }.font(.system(size: 14)).foregroundStyle(p.muted).accessibilityIdentifier("pedal-clear")
            }
            if let problem = pedal.problem { Text(problem).foregroundStyle(InstrumentPalette.orange) }
        }.fixedSize(horizontal: false, vertical: true)
            .onDisappear { pedal.cancelLearning() }
            .sheet(isPresented: $midiPicker) {
                NavigationStack {
                    BluetoothMIDIPicker().navigationTitle(Text("Bluetooth MIDI"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { midiPicker = false } } }
                }
            }
    }
}
