import SwiftUI

enum InstrumentPanelKind: String, Identifiable {
    case tempo, meter, division, countIn, every, increment, practice, start, end, presets, audio, sounds, pedal, setlists, ramp, gap, polyrhythm, songLibrary
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tempo: return L10n.text("SET TEMPO")
        case .meter: return L10n.text("METER")
        case .division: return L10n.text("DIVISION")
        case .countIn: return L10n.text("COUNT IN")
        case .every: return L10n.text("RAMP INTERVAL")
        case .increment: return L10n.text("TEMPO STEP")
        case .practice: return L10n.text("Practice")
        case .ramp: return L10n.text("Tempo ramp")
        case .gap: return L10n.text("Silent bars")
        case .polyrhythm: return L10n.text("Polyrhythm")
        case .start: return L10n.text("START TEMPO")
        case .end: return L10n.text("END TEMPO")
        case .setlists: return L10n.text("Setlists")
        case .songLibrary: return L10n.text("Song library")
        case .presets: return L10n.text("PRESETS")
        case .audio: return L10n.text("AUDIO OUTPUT")
        case .sounds: return L10n.text("SOUND LIBRARY")
        case .pedal: return L10n.text("Pedal setup")
        }
    }
    var height: CGFloat {
        switch self {
        case .tempo, .start, .end: return 620
        case .meter: return 740
        case .division, .ramp, .gap, .polyrhythm: return 740
        case .practice: return 570
        case .setlists, .songLibrary: return 740
        case .presets: return 560
        case .audio: return 300
        case .sounds: return 740
        case .pedal: return 650
        default: return 300
        }
    }
}

/// All secondary surfaces use this same instrument chassis; no system menus or alerts.
struct InstrumentPanel: View {
    @ObservedObject var model: MetronomeModel
    let close: () -> Void
    let initialSetlistID: UUID?
    @State private var kind: InstrumentPanelKind
    @State private var digits: String
    @State private var replaceDigits = true
    @State private var selected: Int
    @State private var denominator: Int
    @State private var compoundPulse: Bool
    @State private var grouping: [Int]
    @State private var customMeter = false
    @State private var polyrhythmSoundLane: Int?
    @State private var divisionEditing = false
    @State private var returnRoutes: [InstrumentPanelKind] = []
    private var returnsToPractice: Bool { !returnRoutes.isEmpty }
    @State private var panelContentHeight: CGFloat = 0
    @State private var presetName = ""
    @State private var deleting: UUID?
    @State private var addingPreset: SavedPreset?
    @State private var presetNotice: String?
    @FocusState private var naming: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    init(model: MetronomeModel, kind: InstrumentPanelKind, initialSetlistID: UUID? = nil, close: @escaping () -> Void) {
        self.model = model; self.close = close; self.initialSetlistID = initialSetlistID
        _kind = State(initialValue: kind)
        _digits = State(initialValue: String(kind == .start ? model.rhythm.start : kind == .end ? model.rhythm.end : model.bpm))
        _denominator = State(initialValue: model.rhythm.denominator)
        _compoundPulse = State(initialValue: model.rhythm.isCompound ? model.rhythm.usesCompoundPulse : true)
        _grouping = State(initialValue: model.rhythm.effectiveGrouping)
        let value: Int
        switch kind {
        case .meter: value = model.rhythm.beats
        case .division: value = model.rhythm.subdivision
        case .countIn: value = model.rhythm.countIn
        case .every: value = model.rhythm.every
        case .increment: value = model.rhythm.increment
        default: value = 0
        }
        _selected = State(initialValue: value)
    }
    @ViewBuilder var body: some View {
        if kind == .pedal {
            PedalSettingsView(model: model, pedal: model.pedal, p: p, close: close)
        } else {
            if kind == .setlists || kind == .songLibrary { SetlistPanel(model: model, p: p, initialSetlistID: initialSetlistID, startInSongLibrary: kind == .songLibrary, close: close) }
            else { standardPanel }
        }
    }
    private var standardPanel: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(model.dark ? 0.55 : 0.30).ignoresSafeArea().onTapGesture { dismiss() }
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(divisionEditing ? L10n.text("Customize rhythm") : polyrhythmSoundLane == nil ? kind.title : L10n.text(polyrhythmSoundLane == 0 ? "First instrument" : "Second instrument")).font(.system(size: 22, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 5)
                        Button { dismiss() } label: {
                            Image(systemName: (returnsToPractice || polyrhythmSoundLane != nil || divisionEditing) ? "chevron.left" : "xmark").font(.system(size: 18, weight: .light)).frame(width: 43, height: 43)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel((returnsToPractice || polyrhythmSoundLane != nil || divisionEditing) ? L10n.text(divisionEditing ? "Back to subdivisions" : polyrhythmSoundLane != nil ? "Back to polyrhythm" : "Back to practice") : L10n.format("Close %@", kind.title.lowercased())).accessibilityIdentifier("close-panel")
                    }.padding(23)
                    Rectangle().fill(p.edge.opacity(0.45)).frame(height: 0.5).padding(.horizontal, 23)
                    ScrollViewReader { proxy in
                        ScrollView {
                            content.padding(23).id("panel-top")
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelContentHeight = $0 }
                        }.scrollBounceBehavior(.basedOnSize).id("\(kind.rawValue)-\(polyrhythmSoundLane ?? -1)")
                            .onChange(of: divisionEditing) { _, _ in proxy.scrollTo("panel-top", anchor: .top) }
                    }
                    if hasTransport {
                        SettingsPlaybackBar(model: model, p: p, identifier: [.ramp, .gap, .polyrhythm, .practice].contains(kind) ? "practice-transport" : "settings-transport")
                            .padding(.horizontal, 23).padding(.bottom, 18)
                    }
                }
                .frame(maxWidth: 460)
                .frame(height: min(kind == .meter && !customMeter ? (model.rhythm.isCompound ? 540 : 445) : compactPanelHeight, geometry.size.height - 12))
                .background { InstrumentBody(p: p) }
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 23).stroke(p.light, lineWidth: 0.8))
                .shadow(color: .black.opacity(0.25), radius: 22, x: 0, y: -4)
                .padding(.horizontal, 10).padding(.bottom, 7)
                .accessibilityAddTraits(.isModal)
            }.foregroundStyle(p.ink)
        }.transition(.identity)
            .preferredColorScheme(model.dark ? .dark : .light)
    }
    private var hasTransport: Bool { [.division, .meter, .practice, .ramp, .gap, .polyrhythm, .sounds, .presets, .countIn, .every, .increment].contains(kind) }
    private var compactPanelHeight: CGFloat {
        guard [.presets, .practice, .ramp, .gap].contains(kind), panelContentHeight > 0 else { return kind.height }
        return min(kind.height, max(300, panelContentHeight + (hasTransport ? 184 : 104)))
    }
    @ViewBuilder private var content: some View {
        switch kind {
        case .tempo, .start, .end: numberPad
        case .meter: meterPicker
        case .division: DivisionPanel(rhythm: $model.rhythm, editing: $divisionEditing, playing: model.playing, p: p, stopPreview: model.endSoundPreview)
        case .countIn, .every, .increment: quantityPicker
        case .practice: practicePanel
        case .ramp: rampPanel
        case .gap: gapPanel
        case .polyrhythm: PolyrhythmPanel(model: model, p: p, soundLane: $polyrhythmSoundLane)
        case .setlists, .songLibrary: SetlistPanel(model: model, p: p, initialSetlistID: initialSetlistID, startInSongLibrary: kind == .songLibrary, close: dismiss)
        case .presets: presetPanel
        case .sounds: SoundLibraryView(model: model)
        case .pedal: PedalSettingsView(model: model, pedal: model.pedal, p: p, close: close)
        case .audio:
            VStack(alignment: .leading, spacing: 25) {
                Text(model.error ?? L10n.text("Audio output changed.")).font(.system(size: 15)).lineSpacing(5)
                commitButton("OK") { model.error = nil; dismiss() }
            }
        }
    }
    private var validNumber: Bool { Int(digits).map { TempoScale.range.contains($0) } ?? false }
    private var numberPad: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(digits.isEmpty ? "—" : digits).font(InstrumentType.display(76)).lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(replaceDigits ? InstrumentPalette.orange : p.ink)
                    .accessibilityLabel(L10n.format("Entered tempo, %@", digits.isEmpty ? L10n.text("empty") : digits))
                Spacer(); Text("BPM").technical(12, spacing: 3).foregroundStyle(p.muted)
            }.padding(.horizontal, 22).frame(height: 100).insetPanel(p, radius: 14)
            HStack {
                Text("20 — 300 BPM").technical(9, spacing: 1.5)
                Spacer()
                Text(L10n.text(validNumber ? (replaceDigits ? "TYPE TO REPLACE" : "READY") : "ENTER 20–300")).technical(9, spacing: 1).foregroundStyle(validNumber ? p.muted : InstrumentPalette.orange)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 11) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "⌫"], id: \.self) { key in
                    Button { typeDigit(key) } label: {
                        Group {
                            if key == "⌫" { Image(systemName: "delete.left").font(.system(size: 22, weight: .light)) }
                            else if key == "CLR" { Text(L10n.text(key)).technical(11, spacing: 1) }
                            else { Text(key).font(InstrumentType.value(29)) }
                        }.frame(maxWidth: .infinity).frame(height: 54)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                        .accessibilityLabel(L10n.text(key == "⌫" ? "Delete digit" : key == "CLR" ? "Clear tempo" : key))
                        .accessibilityIdentifier("key-\(key)")
                }
            }
            commitButton(kind == .tempo ? "SET TEMPO" : "SET VALUE", enabled: validNumber) {
                guard let value = Int(digits), validNumber else { return }
                if kind == .tempo { model.setBPM(value); dismiss() }
                else { if kind == .start { model.rhythm.start = value } else { model.rhythm.end = value }; dismiss() }
            }
        }
    }
    private func typeDigit(_ key: String) {
        model.tickFeedback()
        if key == "CLR" { digits = ""; replaceDigits = false; return }
        if key == "⌫" { if !digits.isEmpty { digits.removeLast() }; replaceDigits = false; return }
        if replaceDigits { digits = key; replaceDigits = false }
        else if digits.count < 3 { digits = digits == "0" ? key : digits + key }
    }
    private var meterPicker: some View {
        VStack(alignment: .leading, spacing: 22) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 11) {
                ForEach([2, 3, 4, 6, 9, 12], id: \.self) { beats in
                    let unit = beats < 6 ? 4 : 8
                    choice("\(beats)/\(unit)", selected: selected == beats && denominator == unit, height: 67) {
                        selected = beats; denominator = unit; compoundPulse = true
                        applyMeter(); finishLiveSelection()
                    }.accessibilityIdentifier("meter-\(beats)-\(unit)")
                }
            }
            if [4, 8, 16].contains(denominator) && [6, 9, 12].contains(selected) {
                HStack(spacing: 10) {
                    choice("BIG BEATS", selected: compoundPulse, height: 44) { compoundPulse = true; applyMeter(); finishLiveSelection() }
                    choice("NOTE UNITS", selected: !compoundPulse, height: 44) { compoundPulse = false; applyMeter(); finishLiveSelection() }
                }
                Text(L10n.format("%d big beats or %d note units per bar.", selected / 3, selected))
                    .font(.system(size: 12)).foregroundStyle(p.muted)
            }
            Button { customMeter.toggle(); model.tickFeedback() } label: {
                HStack {
                    Text("MORE METERS").technical(10, spacing: 1.4)
                    Spacer()
                    Text("\(selected)/\(denominator)").font(InstrumentType.value(16))
                    Image(systemName: customMeter ? "chevron.up" : "chevron.down").font(.system(size: 10))
                }.padding(.horizontal, 15).frame(height: 48)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("More meters")
            if customMeter {
                SectionLabel(text: "BEATS", p: p)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4), spacing: 9) {
                    ForEach(1...12, id: \.self) { value in
                        choice(String(value), selected: selected == value, height: 48) { selected = value; applyMeter() }
                    }
                }
                SectionLabel(text: "NOTE VALUE", p: p)
                HStack(spacing: 10) {
                    ForEach([2, 4, 8, 16], id: \.self) { unit in
                        Button { denominator = unit; applyMeter(); model.tickFeedback() } label: {
                            HStack(spacing: 5) {
                                if denominator == unit { LED(on: true, size: 5) }
                                RhythmGlyph(count: 1, noteValue: unit).fill(p.ink).frame(width: 24, height: 24)
                                Text("/\(unit)").font(InstrumentType.value(19))
                            }.frame(maxWidth: .infinity).frame(height: 51)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                            .accessibilityLabel(L10n.format("Note value /%d", unit))
                            .accessibilityAddTraits(denominator == unit ? .isSelected : [])
                    }
                }
                if !Rhythm.groupingOptions(selected).isEmpty {
                    SectionLabel(text: "GROUPING", p: p)
                    HStack(spacing: 9) {
                        ForEach(Rhythm.groupingOptions(selected), id: \.self) { option in
                            choice(option.map(String.init).joined(separator: "+"), selected: option == model.rhythm.effectiveGrouping, height: 44) { grouping = option; applyMeter() }
                        }
                    }
                }
            }
        }
    }
    private func applyMeter() {
        var rhythm = model.rhythm
        rhythm.setMeter(beats: selected, denominator: denominator, compound: compoundPulse, grouping: grouping)
        model.rhythm = rhythm
    }
    private var quantities: [Int] {
        kind == .countIn ? [0, 1, 2] : kind == .every ? [1, 2, 4, 8, 16, 32] : [1, 2, 3, 5, 10, 20]
    }
    private var quantityPicker: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text(L10n.text(kind == .countIn ? "A MOMENT TO GET READY." : kind == .every ? "CHANGE TEMPO AFTER THIS MANY BARS." : "BPM ADDED OR REMOVED AT EACH STEP."))
                .technical(9, spacing: 1).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(quantities, id: \.self) { value in
                    choice(kind == .countIn && value == 0 ? "OFF" : String(value), selected: selected == value, height: 63) {
                        switch kind {
                        case .countIn: model.rhythm.countIn = value
                        case .every: model.rhythm.every = value
                        case .increment: model.rhythm.increment = value
                        default: break
                        }
                        dismiss()
                    }
                }
            }
        }
    }
    private var practicePanel: some View {
        VStack(spacing: 16) {
            practiceRoute("Tempo ramp", detail: "\(model.rhythm.start) → \(model.rhythm.end) BPM", route: .ramp, enabled: model.rhythm.ramp)
            practiceRoute("Silent bars", detail: L10n.format("%d sound bars · %d silent bars", model.rhythm.audibleBars, model.rhythm.silentBars), route: .gap, enabled: model.rhythm.gap)
            practiceRoute("Polyrhythm", detail: "\(model.rhythm.polyrhythmPrimary ?? 3) : \(model.rhythm.crossRhythm ?? 2)", route: .polyrhythm, enabled: model.rhythm.crossCount > 0)
            HStack {
                Text("COUNT IN").font(.subheadline)
                Spacer()
                Button { selected = model.rhythm.countIn; navigate(.countIn) } label: {
                    HStack { Text(model.rhythm.countIn == 0 ? L10n.text("OFF") : L10n.bars(model.rhythm.countIn)); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("practice-countIn")
            }.padding(.top, 5)
        }
    }
    private func practiceRoute(_ title: String, detail: String, route: InstrumentPanelKind, enabled: Bool) -> some View {
        Button { navigate(route) } label: {
            HStack(spacing: 15) {
                LED(on: enabled, color: InstrumentPalette.amber, size: 8)
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text(title)).font(.system(size: 17, weight: .medium))
                    Text(detail).font(.system(size: 13)).foregroundStyle(p.muted)
                }
                Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 72)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 12)).accessibilityIdentifier("practice-\(route.rawValue)")
    }
    private var rampPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            switchRow("RAMP", value: $model.rhythm.ramp)
            HStack(spacing: 13) {
                numberWell("START", value: model.rhythm.start) { openNumber(.start, value: model.rhythm.start) }
                Image(systemName: "arrow.right").font(.system(size: 13))
                numberWell("END", value: model.rhythm.end) { openNumber(.end, value: model.rhythm.end) }
            }
            HStack(spacing: 13) {
                practiceChoice("EVERY", value: L10n.bars(model.rhythm.every), route: .every, selection: model.rhythm.every)
                practiceChoice("STEP", value: "\(model.rhythm.increment) BPM", route: .increment, selection: model.rhythm.increment)
            }
            Text("Moves toward the end tempo, then holds. Press stop and play to restart the ramp.").font(.system(size: 13)).foregroundStyle(p.muted)
        }
    }
    private var gapPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            switchRow("SOUND / SILENCE", value: $model.rhythm.gap)
            HStack(spacing: 14) {
                stepper("SOUND BARS", value: $model.rhythm.audibleBars, range: 1...16)
                stepper("SILENT BARS", value: $model.rhythm.silentBars, range: 1...16)
            }
            HStack(spacing: 6) {
                ForEach(0..<min(16, model.rhythm.audibleBars + model.rhythm.silentBars), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4).fill(i < model.rhythm.audibleBars ? p.ink : p.muted.opacity(0.2)).frame(height: 35)
                }
            }.padding(20).insetPanel(p, radius: 12)
            Text("The click takes a break. You keep playing.").font(.system(size: 14)).foregroundStyle(p.muted)
        }
    }
    private func navigate(_ route: InstrumentPanelKind) { returnRoutes.append(kind); kind = route }
    private var presetPanel: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(spacing: 11) {
                TextField("NAME THIS RHYTHM", text: $presetName).accessibilityIdentifier("preset-name")
                    .font(.system(size: 12, design: .monospaced)).textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled().focused($naming).submitLabel(.done)
                    .onSubmit { savePreset() }.padding(15).insetPanel(p, radius: 9)
                Button { savePreset() } label: { Image(systemName: "plus").font(.system(size: 22, weight: .light)).frame(width: 47, height: 47) }
                    .buttonStyle(HardwareButtonStyle(p: p)).disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    .accessibilityLabel("Save current rhythm").accessibilityIdentifier("save-preset")
            }
            if model.presets.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "square.stack").font(.system(size: 28, weight: .ultraLight))
                    Text("KEEP A GOOD RHYTHM.").technical(11, spacing: 1.5)
                    Text("Tempo, accents and practice settings — ready next time.").font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(p.muted)
                }.padding(24).frame(maxWidth: .infinity).insetPanel(p, radius: 12)
            }
            if let presetNotice { Text(presetNotice).font(.subheadline).foregroundStyle(p.muted) }
            if let source = addingPreset {
                VStack(spacing: 12) {
                    HStack { Text("Add to setlist").font(.headline); Spacer(); Button("Cancel") { addingPreset = nil } }
                    if model.setlists.isEmpty { Text("Create a setlist first.").font(.subheadline).foregroundStyle(p.muted) }
                    ForEach(model.setlists) { list in
                        Button { model.importPreset(source, into: list.id); addingPreset = nil; presetNotice = L10n.text(source.rhythm.hasPracticeEffects ? "Song added. Practice effects stay in the preset." : "Added to setlist.") } label: {
                            HStack { Text(list.name); Spacer(); Image(systemName: "plus") }.padding(14).frame(minHeight: 44)
                        }.buttonStyle(HardwareButtonStyle(p: p))
                    }
                }.padding(15).insetPanel(p, radius: 12)
            }
            ForEach(model.presets) { preset in
                VStack(spacing: 11) {
                    HStack(spacing: 12) {
                        Button { model.load(preset); finishLiveSelection() } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(preset.name).font(.system(size: 15, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                    Text(preset.rhythm.savedSummary).font(.system(size: 12)).foregroundStyle(p.muted).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(preset.rhythm.savedTempo).font(InstrumentType.value(preset.rhythm.ramp ? 23 : 30)).fixedSize()
                                    Text("BPM").technical(9, spacing: 1)
                                }
                            }.padding(15).frame(maxWidth: .infinity, minHeight: 76)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("load-preset-\(preset.name)")
                            .accessibilityAddTraits(model.isCurrentPreset(preset) ? .isSelected : [])
                            .overlay(alignment: .topLeading) {
                                if model.isCurrentPreset(preset) { LED(on: true, size: 5).offset(x: 6, y: 6).allowsHitTesting(false) }
                            }
                        Menu {
                            Button("Add to setlist") { addingPreset = preset; presetNotice = nil }
                            Button("DELETE", role: .destructive) { deleting = preset.id }
                        } label: { Image(systemName: "ellipsis").frame(width: 40, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel(L10n.format("Options for %@", preset.name))
                    }
                    if deleting == preset.id {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DELETE THIS PRESET?").technical(10, spacing: 1)
                            HStack(spacing: 10) {
                                choice("KEEP", selected: false, height: 43) { deleting = nil }
                                choice("DELETE", selected: false, height: 43) { model.presets.removeAll { $0.id == preset.id }; deleting = nil }
                            }
                        }.padding(14).insetPanel(p, radius: 10)
                    }
                }
            }
        }
    }
    private func savePreset() {
        guard !presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.addPreset(presetName); presetName = ""; naming = false
    }
    private func openNumber(_ target: InstrumentPanelKind, value: Int) { digits = String(value); replaceDigits = true; navigate(target) }
    private func practiceChoice(_ title: String, value: String, route: InstrumentPanelKind, selection: Int) -> some View {
        Button { selected = selection; navigate(route) } label: {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text(title)).technical(9, spacing: 1)
                    Text(L10n.text(value)).font(InstrumentType.value(19)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10))
            }.padding(14).frame(maxWidth: .infinity)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("\(L10n.text(title)), \(L10n.text(value))").accessibilityIdentifier("practice-\(route.rawValue)")
    }
    // Live comparison keeps context; a stopped one-off choice returns to the instrument.
    private func finishLiveSelection() { if !model.playing { dismiss() } }
    private func dismiss() { model.endSoundPreview(); if divisionEditing { divisionEditing = false; return }; if polyrhythmSoundLane != nil { polyrhythmSoundLane = nil; return }; if let previous = returnRoutes.popLast() { kind = previous; return }; naming = false; if kind == .audio { model.error = nil }; close() }
    private func commitButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(L10n.text(title)).technical(12, spacing: 2); Spacer(); Image(systemName: "arrow.right").font(.system(size: 17, weight: .light)) }
                .padding(.horizontal, 19).frame(height: 52).frame(maxWidth: .infinity)
        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true, radius: 10)).disabled(!enabled).opacity(enabled ? 1 : 0.45)
            .accessibilityIdentifier("panelApply")
    }
    private func choice(_ label: String, selected: Bool, height: CGFloat = 51, action: @escaping () -> Void) -> some View {
        Button { action(); model.tickFeedback() } label: {
            HStack(spacing: 7) {
                if selected { LED(on: true, size: 6) }
                Text(L10n.text(label)).font(InstrumentType.value(label.count > 4 ? 16 : 23)).lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity).frame(height: height)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func switchRow(_ label: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(L10n.text(label)).technical(10, spacing: 1)
            Spacer(minLength: 10)
            HStack(spacing: 6) {
                choice("OFF", selected: !value.wrappedValue, height: 43) { value.wrappedValue = false }.accessibilityIdentifier("\(label)-off")
                choice("ON", selected: value.wrappedValue, height: 43) { value.wrappedValue = true }.accessibilityIdentifier("\(label)-on")
            }.frame(width: 150)
        }
    }
    private func numberWell(_ label: String, value: Int, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.text(label)).technical(9, spacing: 2)
            Button(action: action) { Text(String(value)).font(InstrumentType.value(34)).frame(maxWidth: .infinity).frame(height: 67).insetPanel(p, radius: 11) }.buttonStyle(.plain)
                .accessibilityLabel("\(L10n.text(label)), \(value) BPM")
        }
    }
    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.text(label)).technical(8, spacing: 1)
            HStack(spacing: 5) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1); model.tickFeedback() } label: { Text("−").font(.system(size: 20)).frame(width: 38, height: 43) }.buttonStyle(HardwareButtonStyle(p: p, radius: 7)).accessibilityLabel(L10n.format("Decrease %@", L10n.text(label)))
                Text(String(value.wrappedValue)).font(InstrumentType.value(24)).frame(maxWidth: .infinity)
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1); model.tickFeedback() } label: { Text("+").font(.system(size: 20)).frame(width: 38, height: 43) }.buttonStyle(HardwareButtonStyle(p: p, radius: 7)).accessibilityLabel(L10n.format("Increase %@", L10n.text(label)))
            }
        }.frame(maxWidth: .infinity)
    }
}

/// Tuplet numerals distinguish borrowed divisions from ordinary beamed notes.
struct RhythmNotation: View {
    let count: Int
    let compound: Bool
    let noteValue: Int
    let color: Color
    private var tuplet: Int? { compound ? (![1, 3, 6].contains(count) ? count : nil) : ([3, 5, 6, 7].contains(count) ? count : nil) }
    var body: some View {
        GeometryReader { geometry in
            let glyphHeight = min(26, max(0, geometry.size.height - (tuplet == nil ? 0 : 9)))
            VStack(spacing: 0) {
                if let tuplet {
                    HStack(spacing: 3) {
                        Rectangle().frame(height: 0.7)
                        Text(String(tuplet)).font(.system(size: 9, weight: .medium, design: .serif))
                        Rectangle().frame(height: 0.7)
                    }.frame(width: 24, height: 9)
                }
                RhythmGlyph(count: count, compound: compound, noteValue: noteValue).fill(color)
                    .frame(height: glyphHeight)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.foregroundStyle(color)
    }
}

struct RhythmGlyph: Shape {
    let count: Int
    var compound = false
    var noteValue = 4
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let width = min(rect.width - 10, CGFloat(max(1, count - 1)) * 20)
        let left = (rect.width - width) / 2
        for i in 0..<count {
            let x = count == 1 ? rect.midX : left + CGFloat(i) * width / CGFloat(count - 1)
            p.addEllipse(in: CGRect(x: x - 7, y: rect.height - 7, width: 10, height: 6))
            p.addRect(CGRect(x: x + 1.5, y: 1, width: 1.8, height: rect.height - 4.5))
        }
        if compound && count == 1 { p.addEllipse(in: CGRect(x: rect.midX + 7, y: rect.height - 5, width: 3, height: 3)) }
        let flags = noteValue >= 8 ? Int(log2(Double(noteValue))) - 2 : 0
        for flag in 0..<flags {
            let y = CGFloat(1 + flag * 5)
            if count > 1 { p.addRect(CGRect(x: left + 1.5, y: y, width: width + 1.8, height: 2.4)) }
            else {
                p.move(to: CGPoint(x: rect.midX + 3, y: y))
                p.addQuadCurve(to: CGPoint(x: rect.midX + 11, y: y + 12), control: CGPoint(x: rect.midX + 15, y: y + 3))
                p.addQuadCurve(to: CGPoint(x: rect.midX + 3, y: y + 4), control: CGPoint(x: rect.midX + 10, y: y + 7))
                p.closeSubpath()
            }
        }
        if noteValue == 2 {
            for i in 0..<count {
                let x = count == 1 ? rect.midX : left + CGFloat(i) * width / CGFloat(count - 1)
                p = p.subtracting(Path(ellipseIn: CGRect(x: x - 5, y: rect.height - 5.5, width: 6, height: 3)))
            }
        }
        return p
    }
}

/// Draw rests directly: the system text font does not contain musical-rest glyphs.
private struct DivisionPulseGlyph: View {
    let sounding: Bool
    let noteValue: Int
    let color: Color
    var body: some View {
        if sounding {
            RhythmGlyph(count: 1, noteValue: noteValue).fill(color)
        } else {
            DivisionRest(sixteenth: noteValue == 16).fill(color)
        }
    }
}

private struct DivisionRest: Shape {
    let sixteenth: Bool
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var stroke = Path()
        stroke.move(to: point(0.78, 0.13))
        stroke.addLine(to: point(0.39, 0.93))
        stroke.move(to: point(0.72, 0.25))
        stroke.addCurve(to: point(0.26, 0.24), control1: point(0.5, 0.42), control2: point(0.13, 0.4))
        if sixteenth {
            stroke.move(to: point(0.58, 0.54))
            stroke.addCurve(to: point(0.16, 0.52), control1: point(0.35, 0.71), control2: point(0.02, 0.67))
        }
        var result = stroke.strokedPath(StrokeStyle(lineWidth: rect.width * 0.12, lineCap: .round, lineJoin: .round))
        result.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.17, width: rect.width * 0.3, height: rect.height * 0.17))
        if sixteenth {
            result.addEllipse(in: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.45, width: rect.width * 0.3, height: rect.height * 0.17))
        }
        return result
    }
}

extension Rhythm {
    var savedTempo: String { ramp ? "\(start)–\(end)" : "\(bpm)" }
    var savedSummary: String {
        var parts = ["\(beats)/\(denominator)", divisionSummary]
        if gap { parts.append(L10n.format("%d silent bars", silentBars)) }
        return parts.joined(separator: " · ")
    }
}
