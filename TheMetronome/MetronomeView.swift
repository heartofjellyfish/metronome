import SwiftUI

@main
struct TheMetronomeApp: App {
    @StateObject private var model = MetronomeModel()
    var body: some Scene { WindowGroup { MetronomeView(model: model).background(KeyboardGestures()).preferredColorScheme(model.dark ? .dark : .light) } }
}

struct MetronomeView: View {
    @ObservedObject var model: MetronomeModel
    @State private var settings = false
    @State private var mode: InstrumentMode = .metronome
    @State private var modesOpen = false
    @State private var panel: InstrumentPanelKind?
    @State private var liveListRoute: LiveListRoute?
    private struct LiveListRoute: Identifiable { let id = UUID(); var setlistID: UUID?; var action: LiveSetlistAction }
    @State private var panelSession = UUID()
    private func present(_ kind: InstrumentPanelKind) { modesOpen = false; panelSession = UUID(); panel = kind }
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 414, geometry.size.height / 774)
            Group {
                if mode == .metronome { instrumentFace }
                else {
                    VStack(spacing: 0) {
                        modeHeader.frame(height: 38)
                        if mode == .live {
                            LiveModeHome(model: model, open: present) { id, action in
                                modesOpen = false
                                liveListRoute = LiveListRoute(setlistID: id, action: action)
                            }
                        } else {
                            ModeLanding(model: model, mode: mode, open: present)
                        }
                    }
                }
            }
                .accessibilityElement(children: .contain)
                .accessibilityHidden(settings || panel != nil || liveListRoute != nil)
                .frame(width: 414, height: 774, alignment: .top)
                .overlay(alignment: .topLeading) {
                    if modesOpen {
                        ZStack(alignment: .topLeading) {
                            Color.black.opacity(0.001).padding(.top, 38)
                                .onTapGesture { modesOpen = false }
                            modeMenu.padding(.top, 40).padding(.leading, 24)
                        }
                    }
                }
                .scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }.accessibilityHidden(settings || panel != nil || liveListRoute != nil).background { InstrumentBody(p: p).ignoresSafeArea() }
            .fullScreenCover(isPresented: $settings) { SettingsView(model: model) }
            .overlay {
                if let panel { InstrumentPanel(model: model, kind: panel, initialSetlistID: panel == .setlists ? model.activeSetlistID : nil) { self.panel = nil }.id(panelSession) }
            }
            .overlay {
                if let route = liveListRoute {
                    SetlistPanel(model: model, p: p, initialSetlistID: route.setlistID, startCreating: route.action == .create, initialAction: route.action) { liveListRoute = nil }.id(route.id)
                }
            }
            .onChange(of: model.error) { _, value in if value != nil && !settings { present(.audio) } }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--modes") { modesOpen = true }
                if ProcessInfo.processInfo.arguments.contains("--mode-practice") { mode = .practice }
                if ProcessInfo.processInfo.arguments.contains("--mode-live") { mode = .live }
                if ProcessInfo.processInfo.arguments.contains("--settings") { settings = true }
                if let route = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--panel=") }), let kind = InstrumentPanelKind(rawValue: String(route.dropFirst(8))) { present(kind) }
                #endif
            }
    }
    private var modeHeader: some View {
        HStack(spacing: 12) {
            Button { modesOpen.toggle() } label: {
                ModeTriggerLabel(mode: mode, expanded: modesOpen)
            }.buttonStyle(.plain).accessibilityIdentifier("mode-menu")
                .accessibilityLabel(mode.title)
                .accessibilityValue(L10n.text(modesOpen ? "Collapse" : "Expand"))
            Spacer(minLength: 8)
            Button { modesOpen = false; settings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 23)).frame(width: 40, height: 38)
            }.accessibilityLabel("Settings").accessibilityIdentifier("settings")
        }.padding(.horizontal, 24).foregroundStyle(p.ink)
    }
    private var modeMenu: some View {
        ModeChooser(current: mode, p: p) { choice in
            model.endSoundPreview()
            mode = choice
            modesOpen = false
        }.frame(width: 300)
    }
    private var instrumentFace: some View {
        ZStack(alignment: .topLeading) {
            modeHeader.frame(width: 414, height: 38).position(x: 207, y: 15)

            Button { present(.tempo) } label: {
                HStack(alignment: .center, spacing: 28) {
                    Text(String(model.bpm))
                        .font(InstrumentType.display(112))
                        .tracking(0).minimumScaleFactor(0.70).lineLimit(1)
                        .frame(width: 150, alignment: .center)
                        .shadow(color: p.dark ? .clear : .white.opacity(0.35), radius: 0, y: 1)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            RhythmGlyph(count: 1, compound: model.rhythm.usesCompoundPulse, noteValue: model.rhythm.divisionNoteValue(1)).fill(p.ink).frame(width: 20, height: 23)
                            Text("BPM").technical(14, spacing: 2)
                        }
                        Text("\(model.rhythm.beats)/\(model.rhythm.denominator)  \(model.marking)").technical(12, spacing: 1).lineLimit(1).minimumScaleFactor(0.65)
                        if model.interrupted {
                            Text("AUDIO INTERRUPTED").technical(8, spacing: 1).foregroundStyle(InstrumentPalette.orange)
                        } else if model.needsManualResume {
                            Text("Ready to resume").font(.caption)
                        } else if model.event?.countIn == true || model.event?.silent == true {
                            Text(L10n.text(model.event?.countIn == true ? "COUNT IN" : "SILENT BAR")).technical(8, spacing: 1).foregroundStyle(InstrumentPalette.orange)
                        }
                    }.padding(.top, 39)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 35).frame(width: 365, height: 144).insetPanel(p)
            }.buttonStyle(.plain).position(x: 207, y: 114)
                .accessibilityLabel(L10n.format("Tempo, %d BPM. Tap to enter a value", model.bpm)).accessibilityIdentifier("tempoDisplay")

            if !model.soundEnabled {
                Button { model.soundEnabled = true } label: {
                    Image(systemName: "speaker.slash").font(.system(size: 17)).frame(width: 44, height: 44)
                }.position(x: 310, y: 65).accessibilityLabel("Turn sound on").accessibilityIdentifier("home-muted")
            }

            PedalDisplayStatus(pedal: model.pedal, p: p) { present(.pedal) }
                .frame(width: 44, height: 44).position(x: 365, y: 65)

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
                .accessibilityLabel("Time signature").accessibilityIdentifier("home-meter").accessibilityValue("\(model.rhythm.beats)/\(model.rhythm.denominator)")
            Button { present(.division) } label: { selector("DIVISION", value: "") }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 9)).frame(width: 167, height: 61).position(x: 304, y: 576)
                .accessibilityLabel("Subdivision").accessibilityIdentifier("home-division")

            Button { model.toggle(); model.tickFeedback() } label: {
                Group {
                    if model.needsManualResume && !model.interrupted { Label("Resume", systemImage: "play.fill") }
                    else { TransportGlyph(playing: model.transportActive) }
                }.frame(width: 223, height: 100)
            }.buttonStyle(HardwareButtonStyle(p: InstrumentPalette(dark: false), charcoal: !model.dark, radius: 13)).position(x: 138.5, y: 677)
                .disabled(model.interrupted && !model.transportActive)
                .accessibilityLabel(model.transportLabel).accessibilityIdentifier("transport")
            Button { model.tap() } label: {
                VStack(spacing: 19) {
                    LED(on: true, color: InstrumentPalette.amber, size: 13)
                    Text("TAP").technical(16, spacing: 1)
                }.frame(width: 121, height: 100)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 13)).position(x: 327.5, y: 677)
                .accessibilityLabel("Tap tempo").accessibilityIdentifier("tap")
            Button { present(model.activeSetlist != nil ? .setlists : (model.currentSong != nil ? .songLibrary : .presets)) } label: {
                Text(model.presetCaption).technical(9, spacing: 1.6).lineLimit(1).frame(width: 360, height: 28)
            }.buttonStyle(.plain).position(x: 207, y: 753).accessibilityLabel(L10n.text(model.activeSetlist != nil ? "Setlists" : model.currentSong != nil ? "Song library" : "Saved presets")).accessibilityValue(model.presetCaption).accessibilityIdentifier("presets")
        }.foregroundStyle(p.ink)
    }
    func selector(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.text(title)).technical(9, spacing: 1.4)
            HStack {
                Spacer()
                if title == "DIVISION" {
                    RhythmScore(rhythm: model.rhythm, color: p.ink).frame(width: 92, height: 32)
                } else { Text(value).font(InstrumentType.value(24)) }
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .medium))
            }.frame(height: 32)
        }.padding(.horizontal, 14).frame(maxWidth: .infinity).frame(height: 61)
    }
    private var beatKeys: some View {
        let count = model.rhythm.pulseCount
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: count <= 6 ? count : (count + 1) / 2), spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                let active = model.playing && model.event?.beat == index
                let accent = model.rhythm.displayedAccent(index)
                let strength = model.rhythm.displayStrength(index)
                Button { model.cycleAccent(index) } label: {
                    Text(accent == 0 ? "–" : String(index + 1))
                        .font(.system(size: count > 6 ? 20 : 26, weight: strength == 2 ? .bold : strength == 4 ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(strength == 2 ? p.ink : strength == 4 ? p.pulseSecondary : p.pulseWeak)
                        .frame(maxWidth: .infinity)
                        .frame(height: count > 6 ? 39 : 86, alignment: .center)
                        .overlay(alignment: .topLeading) {
                            LED(on: active, color: InstrumentPalette.amber, size: count > 6 ? 7 : 11,
                                intensity: strength == 2 ? 1 : strength == 4 ? 0.80 : strength == 3 ? 0.44 : 0.56)
                                .padding(count > 6 ? 5 : 12)
                        }
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 12))
                    .accessibilityLabel(L10n.format("Beat %d, %@", index + 1, L10n.text(strength == 2 ? "strong" : strength == 4 ? "secondary" : "weak"))).accessibilityValue(L10n.text(accent == 0 ? "Muted" : !model.rhythm.followsMeter ? "Even sound" : accent == 2 ? "Accented sound" : "Meter sound")).accessibilityIdentifier("beat-\(index + 1)").accessibilityHint("Tap to change accent")
            }
        }
    }
}
