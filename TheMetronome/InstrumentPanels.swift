import SwiftUI

enum InstrumentPanelKind: String, Identifiable {
    case tempo, meter, division, countIn, every, increment, practice, start, end, presets, audio, sounds, pedal, setlists
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tempo: return L10n.text("SET TEMPO")
        case .meter: return L10n.text("METER")
        case .division: return L10n.text("DIVISION")
        case .countIn: return L10n.text("COUNT IN")
        case .every: return L10n.text("RAMP INTERVAL")
        case .increment: return L10n.text("TEMPO STEP")
        case .practice: return L10n.text("PRACTICE")
        case .start: return L10n.text("START TEMPO")
        case .end: return L10n.text("END TEMPO")
        case .setlists: return L10n.text("Setlists")
        case .presets: return L10n.text("PRESETS")
        case .audio: return L10n.text("AUDIO OUTPUT")
        case .sounds: return L10n.text("SOUND LIBRARY")
        case .pedal: return L10n.text("LIVE MODE")
        }
    }
    var height: CGFloat {
        switch self {
        case .tempo, .start, .end: return 620
        case .meter: return 740
        case .division: return 520
        case .practice: return 740
        case .setlists: return 740
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
    @State private var kind: InstrumentPanelKind
    @State private var digits: String
    @State private var replaceDigits = true
    @State private var selected: Int
    @State private var denominator: Int
    @State private var compoundPulse: Bool
    @State private var grouping: [Int]
    @State private var advancedDivision = false
    @State private var customMeter = false
    @State private var returnsToPractice = false
    @State private var presetName = ""
    @State private var deleting: UUID?
    @FocusState private var naming: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    init(model: MetronomeModel, kind: InstrumentPanelKind, close: @escaping () -> Void) {
        self.model = model; self.close = close
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
        _advancedDivision = State(initialValue: model.rhythm.divisionMask != nil || model.rhythm.crossCount > 0 || ![1,2,3,model.rhythm.usesCompoundPulse ? 6 : 4].contains(value))
    }
    @ViewBuilder var body: some View {
        if kind == .pedal {
            PedalSettingsView(model: model, pedal: model.pedal, p: p, close: close)
        } else {
            standardPanel
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
                            Text(kind.title).technical(19, spacing: 3).lineLimit(2).minimumScaleFactor(0.8)
                            Text("THE METRONOME / SETUP").technical(8, spacing: 1.8).foregroundStyle(p.muted)
                        }
                        Spacer(minLength: 5)
                        Button { dismiss() } label: {
                            Image(systemName: returnsToPractice ? "chevron.left" : "xmark").font(.system(size: 18, weight: .light)).frame(width: 43, height: 43)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel(returnsToPractice ? L10n.text("Back to practice") : L10n.format("Close %@", kind.title.lowercased())).accessibilityIdentifier("close-panel")
                    }.padding(23)
                    Rectangle().fill(p.edge.opacity(0.45)).frame(height: 0.5).padding(.horizontal, 23)
                    ScrollView {
                        content.padding(23)
                    }.scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: 460)
                .frame(height: min(kind == .meter && !customMeter ? (model.rhythm.isCompound ? 460 : 365) : kind == .division && advancedDivision ? 740 : kind.height, geometry.size.height - 12))
                .background { InstrumentBody(p: p) }
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 23).stroke(p.light, lineWidth: 0.8))
                .shadow(color: .black.opacity(0.25), radius: 22, x: 0, y: -4)
                .padding(.horizontal, 10).padding(.bottom, 7)
                .accessibilityAddTraits(.isModal)
            }.foregroundStyle(p.ink)
        }.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            .preferredColorScheme(model.dark ? .dark : .light)
    }
    @ViewBuilder private var content: some View {
        switch kind {
        case .tempo, .start, .end: numberPad
        case .meter: meterPicker
        case .division: divisionPicker
        case .countIn, .every, .increment: quantityPicker
        case .practice: practicePanel
        case .setlists: SetlistPanel(model: model, p: p, close: dismiss, presets: { kind = .presets })
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
    private var divisionPicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CLICKS WITHIN EACH BEAT").technical(9, spacing: 1.5).foregroundStyle(p.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(model.rhythm.usesCompoundPulse ? [1, 2, 3, 6] : [1, 2, 3, 4], id: \.self) { value in
                    Button { model.rhythm.setDivision(value); model.tickFeedback(); finishLiveSelection() } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { LED(on: model.rhythm.subdivision == value && model.rhythm.divisionMask == nil && model.rhythm.crossCount == 0, size: 7); Spacer() }
                            RhythmNotation(count: value, compound: model.rhythm.usesCompoundPulse, noteValue: model.rhythm.divisionNoteValue(value), color: p.ink).frame(height: 40).padding(.horizontal, 16)
                            Text(model.rhythm.divisionTitle(value)).technical(11, spacing: 1.3).frame(maxWidth: .infinity)
                        }.padding(13).frame(maxWidth: .infinity)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 11))
                        .accessibilityLabel(L10n.format("%d clicks per beat", value)).accessibilityAddTraits(model.rhythm.subdivision == value && model.rhythm.divisionMask == nil && model.rhythm.crossCount == 0 ? .isSelected : [])
                }
            }
            Button { advancedDivision.toggle() } label: {
                HStack { Text("More rhythms"); Spacer(); Image(systemName: advancedDivision ? "chevron.up" : "chevron.down") }
                    .font(.subheadline).padding(12)
            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("more-divisions")
            if advancedDivision {
                Text("Rests & swing").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    patternKey("Offbeat", count: 2, mask: 2)
                    patternKey("Swing", count: 6, mask: 17)
                    patternKey("Triplet · rest first", count: 3, mask: 6)
                    patternKey("Triplet · rest middle", count: 3, mask: 5)
                    patternKey("Triplet · rest last", count: 3, mask: 3)
                    patternKey("Sixteenths · offbeats", count: 4, mask: 10)
                    patternKey("Short · short · long", count: 4, mask: 7)
                    patternKey("Long · short · short", count: 4, mask: 13)
                    patternKey("Short · long · short", count: 4, mask: 11)
                    patternKey("Dotted", count: 4, mask: 9)
                }
                Text("Build a rhythm").font(.headline)
                Text("Choose divisions, then tap pulses to add rests.").font(.subheadline).foregroundStyle(p.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 9) {
                    ForEach(1...8, id: \.self) { n in
                        choice("\(n)", selected: model.rhythm.subdivision == n) { model.rhythm.setDivision(n) }
                            .accessibilityIdentifier("division-count-\(n)")
                    }
                }
                HStack(spacing: 6) {
                    ForEach(0..<model.rhythm.subdivision, id: \.self) { i in
                        let enabled = model.rhythm.enabledMask & (1 << i) != 0
                        Button {
                            let mask = model.rhythm.enabledMask ^ (1 << i)
                            if mask != 0 { model.rhythm.divisionMask = mask == (1 << model.rhythm.subdivision) - 1 ? nil : mask }
                        } label: {
                            DivisionPulseGlyph(sounding: enabled, noteValue: model.rhythm.subdivision > 3 ? 16 : 8, color: p.ink)
                                .frame(width: 18, height: 27).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(HardwareButtonStyle(p: p, radius: 8))
                        .accessibilityLabel(L10n.format("Pulse %d", i + 1)).accessibilityValue(enabled ? L10n.text("Sound") : L10n.text("Rest"))
                        .accessibilityIdentifier("division-pulse-\(i)")
                    }
                }
                Text("Polyrhythm").font(.headline)
                Text("A second pulse across the same beat.").font(.subheadline).foregroundStyle(p.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 9) {
                    choice("OFF", selected: model.rhythm.crossCount == 0) { model.rhythm.crossRhythm = nil }
                    ForEach(2...9, id: \.self) { n in
                        choice("\(model.rhythm.subdivision):\(n)", selected: model.rhythm.crossCount == n) { model.rhythm.crossRhythm = n }
                            .accessibilityIdentifier("cross-rhythm-\(n)")
                    }
                }
                commitButton("DONE") { dismiss() }
            }
        }
    }
    private func patternKey(_ title: String, count: Int, mask: Int) -> some View {
        Button { model.rhythm.setDivision(count, mask: mask); model.tickFeedback(); finishLiveSelection() } label: {
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    ForEach(0..<count, id: \.self) { i in
                        DivisionPulseGlyph(sounding: mask & (1 << i) != 0, noteValue: count > 3 ? 16 : 8, color: p.ink)
                            .frame(width: 14, height: 25)
                    }
                }.accessibilityHidden(true)
                Text(L10n.text(title)).font(.caption).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 75).padding(5)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10))
            .overlay(alignment: .topLeading) {
                if model.rhythm.subdivision == count && model.rhythm.enabledMask == mask && model.rhythm.crossCount == 0 {
                    LED(on: true, size: 5).padding(5).allowsHitTesting(false)
                }
            }
            .accessibilityLabel(L10n.text(title)).accessibilityIdentifier("pattern-\(count)-\(mask)")
            .accessibilityAddTraits(model.rhythm.subdivision == count && model.rhythm.enabledMask == mask && model.rhythm.crossCount == 0 ? .isSelected : [])
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
        VStack(alignment: .leading, spacing: 23) {
            practiceChoice("COUNT IN", value: model.rhythm.countIn == 0 ? "OFF" : L10n.bars(model.rhythm.countIn), route: .countIn, selection: model.rhythm.countIn)
            SectionLabel(text: "TEMPO RAMP", p: p)
            switchRow("RAMP", value: $model.rhythm.ramp)
            if model.rhythm.ramp {
            HStack(spacing: 13) {
                numberWell("START", value: model.rhythm.start) { openNumber(.start, value: model.rhythm.start) }
                Image(systemName: "arrow.right").font(.system(size: 13))
                numberWell("END", value: model.rhythm.end) { openNumber(.end, value: model.rhythm.end) }
            }
            HStack(spacing: 13) {
                practiceChoice("EVERY", value: L10n.bars(model.rhythm.every), route: .every, selection: model.rhythm.every)
                practiceChoice("STEP", value: "\(model.rhythm.increment) BPM", route: .increment, selection: model.rhythm.increment)
            }
            Text("Moves toward the end tempo, then holds. Press stop and play to restart the ramp.").font(.system(size: 12)).foregroundStyle(p.muted)
            }
            SectionLabel(text: "GAP TRAINING", p: p)
            switchRow("SOUND / SILENCE", value: $model.rhythm.gap)
            if model.rhythm.gap {
            HStack(spacing: 14) {
                stepper("SOUND BARS", value: $model.rhythm.audibleBars, range: 1...16)
                stepper("SILENT BARS", value: $model.rhythm.silentBars, range: 1...16)
            }
            }
            SectionLabel(text: "FEEL", p: p)
            switchRow("TOUCH FEEDBACK", value: $model.haptics)
        }
    }
    private var presetPanel: some View {
        VStack(alignment: .leading, spacing: 21) {
            choice("Setlists", selected: false) { kind = .setlists }
            HStack(spacing: 11) {
                TextField("NAME THIS RHYTHM", text: $presetName)
                    .font(.system(size: 12, design: .monospaced)).textInputAutocapitalization(.characters)
                    .autocorrectionDisabled().focused($naming).submitLabel(.done)
                    .onSubmit { savePreset() }.padding(15).insetPanel(p, radius: 9)
                Button { savePreset() } label: { Image(systemName: "plus").font(.system(size: 22, weight: .light)).frame(width: 47, height: 47) }
                    .buttonStyle(HardwareButtonStyle(p: p)).disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save current rhythm")
            }
            if model.presets.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "square.stack").font(.system(size: 28, weight: .ultraLight))
                    Text("KEEP A GOOD RHYTHM.").technical(11, spacing: 1.5)
                    Text("Tempo, accents and practice settings — ready next time.").font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(p.muted)
                }.padding(24).frame(maxWidth: .infinity).insetPanel(p, radius: 12)
            }
            ForEach(model.presets) { preset in
                VStack(spacing: 11) {
                    HStack(spacing: 12) {
                        Button { model.load(preset); finishLiveSelection() } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(preset.name).technical(11, spacing: 1).lineLimit(2)
                                    Text("\(preset.rhythm.beats)/\(preset.rhythm.denominator) · \(L10n.format("%d / BEAT", preset.rhythm.subdivision))").technical(8, spacing: 1).foregroundStyle(p.muted)
                                }
                                Spacer(); Text(String(preset.rhythm.bpm)).font(InstrumentType.value(30))
                            }.padding(15).frame(maxWidth: .infinity, minHeight: 76)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("load-preset-\(preset.name)")
                            .accessibilityAddTraits(model.isCurrentPreset(preset) ? .isSelected : [])
                            .overlay(alignment: .topLeading) {
                                if model.isCurrentPreset(preset) { LED(on: true, size: 5).offset(x: 6, y: 6).allowsHitTesting(false) }
                            }
                        Button { deleting = preset.id } label: { Image(systemName: "trash").font(.system(size: 15, weight: .light)).frame(width: 40, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel(L10n.format("Delete %@", preset.name))
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
    private func openNumber(_ target: InstrumentPanelKind, value: Int) { digits = String(value); replaceDigits = true; returnsToPractice = true; kind = target }
    private func practiceChoice(_ title: String, value: String, route: InstrumentPanelKind, selection: Int) -> some View {
        Button { selected = selection; returnsToPractice = true; kind = route } label: {
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
    private func dismiss() { if returnsToPractice { returnsToPractice = false; kind = .practice; return }; if kind == .sounds { model.endSoundPreview() }; naming = false; if kind == .audio { model.error = nil }; close() }
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

struct SetlistPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    let close: () -> Void
    let presets: () -> Void
    @State private var choosing = false
    @State private var editing = false
    @State private var listName = ""
    @State private var songName = ""
    @State private var tempo = "96"
    @State private var songForm = false
    @State private var editingSong: UUID?
    @State private var deletingList = false
    @State private var deletingSong: UUID?
    private var validSong: Bool { !songName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (20...300).contains(Int(tempo) ?? 0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button { choosing.toggle(); listName = ""; editing = false; deletingList = false; songForm = false; editingSong = nil } label: {
                    HStack { Text(model.activeSetlist?.name ?? L10n.text("Choose a setlist")).lineLimit(2); Image(systemName: "chevron.down") }.frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("choose-setlist")
                Button { editing.toggle(); choosing = false; listName = model.activeSetlist?.name ?? ""; songForm = false; deletingSong = nil } label: { Text(editing ? "DONE" : "Edit").padding(12) }
                    .buttonStyle(HardwareButtonStyle(p: p)).disabled(model.activeSetlist == nil).accessibilityIdentifier("edit-setlist")
            }
            if choosing || model.activeSetlist == nil {
                ForEach(model.setlists) { list in
                    Button { model.activeSetlistID = list.id; choosing = false; songForm = false } label: {
                        HStack { Text(list.name); Spacer(); Text("\(list.songs.count)") }.padding(12)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("setlist-\(list.name)")
                }
                HStack {
                    TextField("Setlist name", text: $listName).accessibilityIdentifier("setlist-name").textFieldStyle(.plain).padding(12).insetPanel(p, radius: 8)
                    Button { model.addSetlist(listName); listName = ""; choosing = false } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Create setlist")
                }
            }
            if let list = model.activeSetlist {
                if editing {
                    HStack {
                        TextField("Setlist name", text: $listName).accessibilityIdentifier("setlist-name").padding(12).insetPanel(p, radius: 8)
                        Button("Rename") { model.renameSetlist(listName); listName = "" }.disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Button("Delete setlist") { deletingList = true }.foregroundStyle(p.muted)
                    if deletingList {
                        Text("Delete this setlist and its songs?").font(.subheadline)
                        HStack {
                            Button("Cancel") { deletingList = false }
                            Spacer()
                            Button("DELETE") { model.deleteActiveSetlist(); deletingList = false; editing = false; songForm = false; editingSong = nil }
                        }
                    }
                }
                if list.songs.isEmpty { Text("Your next show, song by song.").font(.subheadline).foregroundStyle(p.muted).padding(.vertical, 12) }
                ForEach(Array(list.songs.enumerated()), id: \.element.id) { index, song in
                    VStack(spacing: 8) {
                        Button { model.loadSong(song); if !model.playing { close() } } label: {
                            HStack(spacing: 12) {
                                LED(on: model.selectedSongID == song.id, size: 7)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(song.name).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                                    Text("\(song.rhythm.beats)/\(song.rhythm.denominator)").font(.caption).foregroundStyle(p.muted)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(song.rhythm.bpm)").font(InstrumentType.value(30))
                                    Text("BPM").technical(8, spacing: 1)
                                }
                            }.padding(14).frame(maxWidth: .infinity)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("song-\(song.name)")
                            .accessibilityAddTraits(model.selectedSongID == song.id ? .isSelected : [])
                        if songForm && editingSong == song.id { songEditor }
                        if editing {
                            HStack(spacing: 18) {
                                Button { model.moveSong(song.id, by: -1) } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityLabel("Move up").accessibilityIdentifier("move-up-\(song.name)")
                                Button { model.moveSong(song.id, by: 1) } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }.disabled(index == list.songs.count - 1).accessibilityLabel("Move down").accessibilityIdentifier("move-down-\(song.name)")
                                Button("Edit") { editingSong = song.id; songName = song.name; tempo = String(song.rhythm.bpm); songForm = true }
                                    .accessibilityIdentifier("edit-song-\(song.name)")
                                Spacer()
                                Button { deletingSong = song.id } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Delete song").accessibilityIdentifier("delete-song-\(song.name)")
                            }.foregroundStyle(p.muted)
                            if deletingSong == song.id {
                                HStack {
                                    Button("Cancel") { deletingSong = nil }; Spacer()
                                    Button("DELETE") {
                                        model.deleteSong(song.id); deletingSong = nil
                                        if editingSong == song.id { songForm = false; editingSong = nil }
                                    }
                                }
                            }
                        }
                    }
                }
                if !songForm {
                    Button { editingSong = nil; songName = ""; tempo = String(model.bpm); songForm = true } label: {
                        Label("Add song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-song")
                } else {
                    if editingSong == nil { songEditor }
                }
            }
            Divider()
            Button(action: presets) { Text("Saved presets").font(.subheadline).frame(minHeight: 44) }
        }.foregroundStyle(p.ink)
    }
    private var songEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
                    TextField("Song name", text: $songName).accessibilityIdentifier("song-name").padding(12).insetPanel(p, radius: 8)
                    HStack {
                        Text("BPM")
                        TextField("BPM", text: $tempo).accessibilityIdentifier("song-bpm").keyboardType(.numberPad).padding(12).insetPanel(p, radius: 8)
                        Text("20–300").font(.caption).foregroundStyle(p.muted)
                    }
                    if editingSong == nil { Text("Uses the current meter, sound and rhythm.").font(.caption).foregroundStyle(p.muted) }
                    HStack {
                        Button("Cancel") { songForm = false }
                        Spacer()
                        Button("Save song") {
                            if let id = editingSong { model.editSong(id, name: songName, bpm: Int(tempo)!) }
                            else { model.addSong(songName, bpm: Int(tempo)!) }
                            songForm = false
                        }.disabled(!validSong).accessibilityIdentifier("save-song")
                    }.frame(minHeight: 44)
        }
    }
}
