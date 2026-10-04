import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MetronomeModel
    @Environment(\.dismiss) private var dismiss
    @State private var panel: InstrumentPanelKind?
    @State private var panelSession = UUID()
    private func present(_ kind: InstrumentPanelKind) { panelSession = UUID(); panel = kind }
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 414, geometry.size.height / 774)
            face.accessibilityElement(children: .contain).accessibilityHidden(panel != nil).allowsHitTesting(panel == nil).frame(width: 414, height: 774).scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }.foregroundStyle(p.ink).background { InstrumentBody(p: p).ignoresSafeArea() }
            .preferredColorScheme(model.dark ? .dark : .light)
            .overlay { if let panel { InstrumentPanel(model: model, kind: panel) { self.panel = nil }.id(panelSession) } }
            .onDisappear { model.endSoundPreview() }
            .onChange(of: model.error) { _, value in if value != nil { present(.audio) } }
    }
    private var face: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SETTINGS").technical(22, spacing: 5)
                Text("THE METRONOME / SETUP").technical(9, spacing: 2.5)
            }.frame(width: 280, alignment: .leading).position(x: 167, y: 30)
            Button { model.endSoundPreview(); dismiss() } label: { Image(systemName: "xmark").font(.system(size: 23, weight: .light)).frame(width: 43, height: 44) }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).position(x: 370, y: 28).accessibilityLabel("Close settings")
            SectionLabel(text: "01 RHYTHM", p: p).frame(width: 359).position(x: 206.5, y: 93)
            HStack(spacing: 17) {
                menuField("METER", value: "\(model.rhythm.beats)/\(model.rhythm.denominator)", route: .meter)
                menuField("COUNT IN", value: model.rhythm.countIn == 0 ? "OFF" : "\(model.rhythm.countIn) BAR", route: .countIn)
            }.frame(width: 359).position(x: 206.5, y: 154)

            HStack(spacing: 12) {
                SectionLabel(text: "02 SOUND", p: p)
                Button { present(.sounds) } label: {
                    HStack(spacing: 8) {
                        Text("ALL SOUNDS").technical(8, spacing: 0.8)
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
                    }.frame(width: 115, height: 32)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 7))
                    .accessibilityLabel("All sounds")
            }.frame(width: 359).position(x: 206.5, y: 228)
            SoundCardRow(model: model, sounds: InstrumentSound.recommended, namespace: "recommended")
                .frame(width: 359).position(x: 206.5, y: 322)
            SoundDynamicsControl(model: model).frame(width: 359).position(x: 206.5, y: 418)

            SectionLabel(text: "03 PRACTICE", p: p).frame(width: 359).position(x: 206.5, y: 466)
            HStack {
                Text("RAMP").technical(12, spacing: 1.7); Spacer()
                flatSegment($model.rhythm.ramp, labels: ["OFF", "ON"]).frame(width: 233, height: 46)
            }.frame(width: 359).position(x: 206.5, y: 512)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("START → END (BPM)").technical(10, spacing: 0.7).fixedSize()
                    Button { present(.practice) } label: {
                        Text("\(model.rhythm.start) → \(model.rhythm.end)").font(InstrumentType.value(21)).frame(width: 146, height: 46).insetPanel(p, radius: 9)
                    }.buttonStyle(.plain).accessibilityLabel("Edit ramp start and end")
                }
                menuField("EVERY", value: "\(model.rhythm.every) BARS", route: .every, fontSize: 13).frame(width: 100)
                menuField("INCREASE BY", value: "+\(model.rhythm.increment)", route: .increment, fontSize: 20).frame(width: 81)
            }.frame(width: 359).position(x: 206.5, y: 589)

            SectionLabel(text: "04 VIEW", p: p).frame(width: 359).position(x: 206.5, y: 668)
            HStack {
                Text("SKIN").technical(12, spacing: 1.7); Spacer()
                flatSegment($model.dark, labels: ["LIGHT", "DARK"]).frame(width: 261, height: 46)
            }.frame(width: 359).position(x: 206.5, y: 714)
        }
    }
    func flatSegment(_ value: Binding<Bool>, labels: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<2) { index in
                let selected = value.wrappedValue == (index == 1)
                Button { value.wrappedValue = index == 1; model.tickFeedback() } label: {
                    Text(labels[index]).technical(13, spacing: 0.5).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [p.top, p.bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.edge, lineWidth: 0.7))
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(p.light, lineWidth: 0.8).padding(1))
                                    .shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 2)
                            }
                        }
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }.insetPanel(p, radius: 9)
    }
    func menuField(_ title: String, value: String, route: InstrumentPanelKind, fontSize: CGFloat = 21) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).technical(10, spacing: 1.3).fixedSize()
            Button { present(route) } label: {
                HStack { Spacer(minLength: 0); Text(value).font(InstrumentType.value(fontSize)).lineLimit(1).minimumScaleFactor(0.7); Spacer(minLength: 0); Image(systemName: "chevron.down").font(.system(size: 10)) }
                    .padding(.horizontal, 12).frame(height: 46).frame(maxWidth: .infinity)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("\(title), \(value)")
        }.frame(maxWidth: .infinity)
    }
}
