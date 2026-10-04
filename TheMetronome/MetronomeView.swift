import SwiftUI

@main
struct TheMetronomeApp: App {
    @StateObject private var model = MetronomeModel()
    var body: some Scene { WindowGroup { MetronomeView(model: model).preferredColorScheme(model.dark ? .dark : .light) } }
}

struct MetronomeView: View {
    @ObservedObject var model: MetronomeModel
    @State private var settings = false
    @State private var panel: InstrumentPanelKind?
    @State private var panelSession = UUID()
    private func present(_ kind: InstrumentPanelKind) { panelSession = UUID(); panel = kind }
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 414, geometry.size.height / 774)
            instrumentFace
                .frame(width: 414, height: 774)
                .scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }.accessibilityHidden(panel != nil).background { InstrumentBody(p: p).ignoresSafeArea() }
            .fullScreenCover(isPresented: $settings) { SettingsView(model: model) }
            .overlay {
                if let panel { InstrumentPanel(model: model, kind: panel) { self.panel = nil }.id(panelSession) }
            }
            .onChange(of: model.error) { _, value in if value != nil && !settings { present(.audio) } }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--settings") { settings = true }
                if let route = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--panel=") }), let kind = InstrumentPanelKind(rawValue: String(route.dropFirst(8))) { present(kind) }
                #endif
            }
    }
    private var instrumentFace: some View {
        ZStack(alignment: .topLeading) {
            Text("THE METRONOME").technical(11, spacing: 4.3)
                .frame(width: 300, alignment: .leading).position(x: 177, y: 15)
            Button { settings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 23)).frame(width: 40, height: 38)
            }.position(x: 374, y: 15).accessibilityLabel("Settings").accessibilityIdentifier("settings")

            Button { present(.tempo) } label: {
                HStack(alignment: .center, spacing: 28) {
                    Text(String(model.bpm))
                        .font(InstrumentType.display(112))
                        .tracking(0).minimumScaleFactor(0.70).lineLimit(1)
                        .frame(width: 150, alignment: .center)
                        .shadow(color: p.dark ? .clear : .white.opacity(0.35), radius: 0, y: 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(model.rhythm.beatUnit) BPM").technical(14, spacing: 2)
                        Text("\(model.rhythm.beats)/\(model.rhythm.denominator)  \(model.marking)").technical(12, spacing: 1).lineLimit(1).minimumScaleFactor(0.65)
                        if model.event?.countIn == true || model.event?.silent == true {
                            Text(model.event?.countIn == true ? "COUNT IN" : "SILENT BAR").technical(8, spacing: 1).foregroundStyle(InstrumentPalette.orange)
                        }
                    }.padding(.top, 39)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 35).frame(width: 365, height: 144).insetPanel(p)
            }.buttonStyle(.plain).position(x: 207, y: 114)
                .accessibilityLabel("Tempo, \(model.bpm) BPM. Tap to enter a value").accessibilityIdentifier("tempoDisplay")

            SectionLabel(text: "01  PULSE", p: p).frame(width: 360).position(x: 207, y: 206)
            beatKeys.frame(width: 360, height: 86).position(x: 207, y: 269)

            HStack { Text("02  TEMPO").technical(9, spacing: 2); Spacer(); Rectangle().fill(p.edge.opacity(0.65)).frame(width: 98, height: 0.5) }.frame(width: 360).position(x: 207, y: 345)
            TempoDial(model: model, p: p).frame(width: 204, height: 204).position(x: 206, y: 436)
            Button { model.setBPM(model.bpm - 1) } label: {
                Text("−").font(.system(size: 30, weight: .regular, design: .monospaced)).frame(width: 60, height: 57)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 11)).position(x: 57, y: 447).accessibilityLabel("Decrease tempo").accessibilityIdentifier("decrease")
            Button { model.setBPM(model.bpm + 1) } label: {
                Text("+").font(.system(size: 30, weight: .regular, design: .monospaced)).frame(width: 60, height: 57)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 11)).position(x: 357, y: 447).accessibilityLabel("Increase tempo").accessibilityIdentifier("increase")

            Button { present(.meter) } label: { selector("METER", value: "\(model.rhythm.beats)/\(model.rhythm.denominator)") }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 9)).frame(width: 170, height: 61).position(x: 112, y: 576)
                .accessibilityLabel("Time signature")
            Button { present(.division) } label: { selector("DIVISION", value: "") }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 9)).frame(width: 167, height: 61).position(x: 304, y: 576)
                .accessibilityLabel("Subdivision")

            Button { model.toggle(); model.tickFeedback() } label: {
                TransportGlyph(playing: model.playing).frame(width: 223, height: 100)
            }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true, radius: 13)).position(x: 138.5, y: 677)
                .accessibilityLabel(model.playing ? "Stop metronome" : "Start metronome").accessibilityIdentifier("transport")
            Button { model.tap() } label: {
                VStack(spacing: 19) {
                    LED(on: true, color: InstrumentPalette.amber, size: 13)
                    Text("TAP").technical(16, spacing: 1)
                }.frame(width: 121, height: 100)
            }.buttonStyle(HardwareButtonStyle(p: InstrumentPalette(dark: false), radius: 13)).position(x: 327.5, y: 677)
                .accessibilityLabel("Tap tempo").accessibilityIdentifier("tap")
            Button { present(.presets) } label: {
                Text("PRESET 01 / \(model.presetName)").technical(9, spacing: 1.6).lineLimit(1).frame(width: 360, height: 28)
            }.buttonStyle(.plain).position(x: 207, y: 753).accessibilityLabel("Saved presets").accessibilityIdentifier("presets")
        }.foregroundStyle(p.ink)
    }
    func selector(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).technical(9, spacing: 1.4)
            HStack {
                Spacer()
                if title == "DIVISION" {
                    RhythmGlyph(count: model.rhythm.subdivision, compound: model.rhythm.usesCompoundPulse).fill(p.ink).frame(width: 42, height: 26)
                } else { Text(value).font(InstrumentType.value(24)) }
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .medium))
            }.frame(height: 28)
        }.padding(.horizontal, 14).frame(maxWidth: .infinity).frame(height: 61)
    }
    private var beatKeys: some View {
        let count = model.rhythm.pulseCount
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: count <= 6 ? count : (count + 1) / 2), spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                let active = model.playing && model.event?.beat == index
                let accent = model.rhythm.displayedAccent(index)
                let strength = model.rhythm.beatStrength(index)
                Button { model.cycleAccent(index) } label: {
                    Text(accent == 0 ? "–" : String(index + 1))
                        .font(.system(size: count > 6 ? 20 : 26, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .frame(height: count > 6 ? 39 : 86, alignment: .center)
                        .overlay(alignment: .topLeading) {
                            if active {
                                LED(on: true, color: InstrumentPalette.amber, size: count > 6 ? 7 : 13)
                                    .padding(count > 6 ? 10 : 14)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if strength != 0 {
                                Capsule().fill(p.ink.opacity(strength == 2 ? 0.85 : strength == 4 ? 0.65 : 0.40))
                                    .frame(width: strength == 2 ? 18 : strength == 4 ? 11 : 5, height: 2)
                                    .padding(.bottom, count > 6 ? 4 : 12)
                            }
                        }
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 12))
                    .accessibilityLabel("Beat \(index + 1), \(strength == 0 ? "muted" : strength == 2 ? "strong" : strength == 4 ? "secondary" : strength == 5 ? "even" : "weak")").accessibilityIdentifier("beat-\(index + 1)").accessibilityHint("Tap to change accent")
            }
        }
    }
}
