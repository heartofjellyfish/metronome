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
                menuField("DIVISION", value: "\(model.rhythm.subdivision) / BEAT", route: .division, fontSize: 17)
            }.frame(width: 359).position(x: 206.5, y: 154)

            HStack(spacing: 12) {
                SectionLabel(text: "02 SOUND", p: p)
                Button { present(.sounds) } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CURRENT").technical(6, spacing: 1).foregroundStyle(p.muted)
                            Text(InstrumentSound(rawValue: model.rhythm.sound)?.title ?? "HI-HAT")
                                .technical(10, spacing: 0.5).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
                    }.padding(.horizontal, 10).frame(width: 115, height: 32)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 7))
                    .accessibilityLabel("All sounds")
                    .accessibilityValue(InstrumentSound(rawValue: model.rhythm.sound)?.title ?? "HI-HAT")
            }.frame(width: 359).position(x: 206.5, y: 228)
            SoundCardRow(model: model, sounds: InstrumentSound.recommended, namespace: "recommended")
                .frame(width: 359).position(x: 206.5, y: 322)
            SoundDynamicsControl(model: model).frame(width: 359).position(x: 206.5, y: 418)

            SectionLabel(text: "03 MORE", p: p).frame(width: 359).position(x: 206.5, y: 487)
            HStack(spacing: 17) {
                navigationKey("PRACTICE", subtitle: "COUNT IN · RAMP · GAP", route: .practice)
                navigationKey("PRESETS", subtitle: "SAVE A RHYTHM", route: .presets)
            }.frame(width: 359).position(x: 206.5, y: 555)

            SectionLabel(text: "04 VIEW", p: p).frame(width: 359).position(x: 206.5, y: 668)
            HStack {
                Text("SKIN").technical(12, spacing: 1.7); Spacer()
                skinKeys.frame(width: 261, height: 46)
            }.frame(width: 359).position(x: 206.5, y: 714)
        }
    }
    private func navigationKey(_ title: String, subtitle: String, route: InstrumentPanelKind) -> some View {
        Button { model.endSoundPreview(); present(route) } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(title).technical(12, spacing: 1.2)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                }
                Text(subtitle).technical(7, spacing: 0.4).foregroundStyle(p.muted)
            }.padding(15).frame(maxWidth: .infinity).frame(height: 81)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10))
            .accessibilityLabel(title == "PRESETS" ? "Saved presets" : "Practice settings")
            .accessibilityIdentifier(route == .presets ? "settings-presets" : route.rawValue)
    }
    private var skinKeys: some View {
        HStack(spacing: 9) {
            ForEach(0..<2) { index in
                let selected = model.dark == (index == 1)
                Button { model.dark = index == 1; model.tickFeedback() } label: {
                    HStack(spacing: 10) {
                        LED(on: selected, color: InstrumentPalette.amber, size: 7)
                        Text(index == 0 ? "LIGHT" : "DARK").technical(12, spacing: 0.8)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(HardwareButtonStyle(p: InstrumentPalette(dark: false), charcoal: index == 1, radius: 9))
                .accessibilityLabel(index == 0 ? "LIGHT" : "DARK")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
    func menuField(_ title: String, value: String, route: InstrumentPanelKind, fontSize: CGFloat = 21) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).technical(10, spacing: 1.3).fixedSize()
            Button { present(route) } label: {
                HStack { Spacer(minLength: 0); Text(value).font(InstrumentType.value(fontSize)).lineLimit(1).minimumScaleFactor(0.7); Spacer(minLength: 0); Image(systemName: "chevron.down").font(.system(size: 10)) }
                    .padding(.horizontal, 12).frame(height: 46).frame(maxWidth: .infinity)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityIdentifier("settings-\(route.rawValue)").accessibilityLabel(title == "METER" ? "Time signature" : title == "DIVISION" ? "Subdivision" : "\(title), \(value)")
        }.frame(maxWidth: .infinity)
    }
}
