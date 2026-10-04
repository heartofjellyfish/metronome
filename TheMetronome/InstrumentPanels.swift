import SwiftUI

enum InstrumentPanelKind: String, Identifiable {
    case tempo, meter, division, countIn, every, increment, practice, start, end, presets, audio, sounds
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tempo: return "SET TEMPO"
        case .meter: return "METER"
        case .division: return "DIVISION"
        case .countIn: return "COUNT IN"
        case .every: return "RAMP INTERVAL"
        case .increment: return "TEMPO STEP"
        case .practice: return "PRACTICE"
        case .start: return "START TEMPO"
        case .end: return "END TEMPO"
        case .presets: return "PRESETS"
        case .audio: return "AUDIO OUTPUT"
        case .sounds: return "SOUND LIBRARY"
        }
    }
    var height: CGFloat {
        switch self {
        case .tempo, .start, .end: return 620
        case .meter: return 660
        case .division: return 510
        case .practice: return 740
        case .presets: return 560
        case .audio: return 300
        case .sounds: return 740
        default: return 370
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
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(model.dark ? 0.55 : 0.30).ignoresSafeArea().onTapGesture { dismiss() }
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(kind.title).technical(19, spacing: 3)
                            Text("THE METRONOME / SETUP").technical(8, spacing: 1.8).foregroundStyle(p.muted)
                        }
                        Spacer(minLength: 5)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 18, weight: .light)).frame(width: 43, height: 43)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("Close \(kind.title.lowercased())")
                    }.padding(23)
                    Rectangle().fill(p.edge.opacity(0.45)).frame(height: 0.5).padding(.horizontal, 23)
                    ScrollView {
                        content.padding(23)
                    }.scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: 460)
                .frame(height: min(kind.height, geometry.size.height - 12))
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
        case .presets: presetPanel
        case .sounds: SoundLibraryView(model: model)
        case .audio:
            VStack(alignment: .leading, spacing: 25) {
                Text(model.error ?? "Audio output changed.").font(.system(size: 15)).lineSpacing(5)
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
                    .accessibilityLabel("Entered tempo, \(digits.isEmpty ? "empty" : digits)")
                Spacer(); Text("BPM").technical(12, spacing: 3).foregroundStyle(p.muted)
            }.padding(.horizontal, 22).frame(height: 100).insetPanel(p, radius: 14)
            HStack {
                Text("20 — 300 BPM").technical(9, spacing: 1.5)
                Spacer()
                Text(validNumber ? (replaceDigits ? "TYPE TO REPLACE" : "READY") : "ENTER 20–300").technical(9, spacing: 1).foregroundStyle(validNumber ? p.muted : InstrumentPalette.orange)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 11) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "⌫"], id: \.self) { key in
                    Button { typeDigit(key) } label: {
                        Group {
                            if key == "⌫" { Image(systemName: "delete.left").font(.system(size: 22, weight: .light)) }
                            else if key == "CLR" { Text(key).technical(11, spacing: 1) }
                            else { Text(key).font(InstrumentType.value(29)) }
                        }.frame(maxWidth: .infinity).frame(height: 54)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                        .accessibilityLabel(key == "⌫" ? "Delete digit" : key == "CLR" ? "Clear tempo" : key)
                        .accessibilityIdentifier("key-\(key)")
                }
            }
            commitButton(kind == .tempo ? "SET TEMPO" : "SET VALUE", enabled: validNumber) {
                guard let value = Int(digits), validNumber else { return }
                if kind == .tempo { model.setBPM(value); dismiss() }
                else { if kind == .start { model.rhythm.start = value } else { model.rhythm.end = value }; kind = .practice }
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(selected)/\(denominator)").font(InstrumentType.display(58))
                Spacer()
                Text("TIME SIGNATURE").technical(9, spacing: 1.2).foregroundStyle(p.muted)
            }.padding(.horizontal, 20).frame(height: 82).insetPanel(p, radius: 13)
            SectionLabel(text: "01  BEATS PER BAR", p: p)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4), spacing: 9) {
                ForEach(1...12, id: \.self) { value in
                    choice(String(value), selected: selected == value, height: 48) { selected = value }
                }
            }
            SectionLabel(text: "02  BEAT UNIT", p: p)
            HStack(spacing: 10) {
                choice("♩  /4", selected: denominator == 4) { denominator = 4 }
                choice("♪  /8", selected: denominator == 8) { denominator = 8 }
            }
            Text("BPM counts each \(denominator == 4 ? "quarter" : "eighth") note. Accents shape the grouping.")
                .font(.system(size: 12)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            commitButton("SET METER") { model.rhythm.beats = selected; model.rhythm.denominator = denominator; dismiss() }
        }
    }
    private var divisionPicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CLICKS WITHIN EACH BEAT").technical(9, spacing: 1.5).foregroundStyle(p.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(1...4, id: \.self) { value in
                    Button { selected = value; model.tickFeedback() } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { LED(on: selected == value, size: 7); Spacer(); Text(String(format: "%02d", value)).technical(9, spacing: 1).foregroundStyle(p.muted) }
                            RhythmGlyph(count: value).fill(p.ink).frame(height: 40).padding(.horizontal, 16)
                            Text(["ONE", "TWO", "TRIPLET", "FOUR"][value - 1]).technical(11, spacing: 1.3).frame(maxWidth: .infinity)
                            Text("\(value) / BEAT").technical(8, spacing: 1).foregroundStyle(p.muted).frame(maxWidth: .infinity)
                        }.padding(13).frame(maxWidth: .infinity)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 11))
                        .accessibilityLabel("\(value) clicks per beat").accessibilityAddTraits(selected == value ? .isSelected : [])
                }
            }
            commitButton("SET DIVISION") { model.rhythm.subdivision = selected; dismiss() }
        }
    }
    private var quantities: [Int] {
        kind == .countIn ? [0, 1, 2] : kind == .every ? [1, 2, 4, 8, 16, 32] : [1, 2, 3, 5, 10, 20]
    }
    private var quantityPicker: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text(kind == .countIn ? "A MOMENT TO GET READY." : kind == .every ? "CHANGE TEMPO AFTER THIS MANY BARS." : "BPM ADDED OR REMOVED AT EACH STEP.")
                .technical(9, spacing: 1).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(quantities, id: \.self) { value in
                    choice(kind == .countIn && value == 0 ? "OFF" : String(value), selected: selected == value, height: 63) { selected = value }
                }
            }
            commitButton("APPLY") {
                switch kind {
                case .countIn: model.rhythm.countIn = selected
                case .every: model.rhythm.every = selected
                case .increment: model.rhythm.increment = selected
                default: break
                }
                dismiss()
            }
        }
    }
    private var practicePanel: some View {
        VStack(alignment: .leading, spacing: 23) {
            SectionLabel(text: "01  TEMPO RAMP", p: p)
            switchRow("RAMP", value: $model.rhythm.ramp)
            HStack(spacing: 13) {
                numberWell("START", value: model.rhythm.start) { openNumber(.start, value: model.rhythm.start) }
                Image(systemName: "arrow.right").font(.system(size: 13))
                numberWell("END", value: model.rhythm.end) { openNumber(.end, value: model.rhythm.end) }
            }
            Text("Moves toward the end tempo, then holds. Press stop and play to restart the ramp.").font(.system(size: 12)).foregroundStyle(p.muted)
            SectionLabel(text: "02  GAP TRAINING", p: p)
            switchRow("SOUND / SILENCE", value: $model.rhythm.gap)
            HStack(spacing: 14) {
                stepper("SOUND BARS", value: $model.rhythm.audibleBars, range: 1...16)
                stepper("SILENT BARS", value: $model.rhythm.silentBars, range: 1...16)
            }
            SectionLabel(text: "03  FEEL", p: p)
            switchRow("TOUCH FEEDBACK", value: $model.haptics)
            commitButton("DONE") { dismiss() }
        }
    }
    private var presetPanel: some View {
        VStack(alignment: .leading, spacing: 21) {
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
                        Button { model.load(preset); dismiss() } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(preset.name).technical(11, spacing: 1).lineLimit(2)
                                    Text("\(preset.rhythm.beats)/\(preset.rhythm.denominator) · \(preset.rhythm.subdivision) / BEAT").technical(8, spacing: 1).foregroundStyle(p.muted)
                                }
                                Spacer(); Text(String(preset.rhythm.bpm)).font(InstrumentType.value(30))
                            }.padding(15).frame(maxWidth: .infinity, minHeight: 76)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 10))
                        Button { deleting = preset.id } label: { Image(systemName: "trash").font(.system(size: 15, weight: .light)).frame(width: 40, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Delete \(preset.name)")
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
    private func openNumber(_ target: InstrumentPanelKind, value: Int) { digits = String(value); replaceDigits = true; kind = target }
    private func dismiss() { if kind == .sounds { model.endSoundPreview() }; naming = false; if kind == .audio { model.error = nil }; close() }
    private func commitButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title).technical(12, spacing: 2); Spacer(); Image(systemName: "arrow.right").font(.system(size: 17, weight: .light)) }
                .padding(.horizontal, 19).frame(height: 52).frame(maxWidth: .infinity)
        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true, radius: 10)).disabled(!enabled).opacity(enabled ? 1 : 0.45)
            .accessibilityIdentifier("panelApply")
    }
    private func choice(_ label: String, selected: Bool, height: CGFloat = 51, action: @escaping () -> Void) -> some View {
        Button { action(); model.tickFeedback() } label: {
            HStack(spacing: 7) {
                if selected { LED(on: true, size: 6) }
                Text(label).font(InstrumentType.value(label.count > 4 ? 16 : 23)).lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity).frame(height: height)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func switchRow(_ label: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(label).technical(10, spacing: 1)
            Spacer(minLength: 10)
            HStack(spacing: 6) {
                choice("OFF", selected: !value.wrappedValue, height: 43) { value.wrappedValue = false }
                choice("ON", selected: value.wrappedValue, height: 43) { value.wrappedValue = true }
            }.frame(width: 150)
        }
    }
    private func numberWell(_ label: String, value: Int, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).technical(9, spacing: 2)
            Button(action: action) { Text(String(value)).font(InstrumentType.value(34)).frame(maxWidth: .infinity).frame(height: 67).insetPanel(p, radius: 11) }.buttonStyle(.plain)
                .accessibilityLabel("\(label), \(value) BPM")
        }
    }
    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).technical(8, spacing: 1)
            HStack(spacing: 5) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1); model.tickFeedback() } label: { Text("−").font(.system(size: 20)).frame(width: 38, height: 43) }.buttonStyle(HardwareButtonStyle(p: p, radius: 7)).accessibilityLabel("Decrease \(label)")
                Text(String(value.wrappedValue)).font(InstrumentType.value(24)).frame(maxWidth: .infinity)
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1); model.tickFeedback() } label: { Text("+").font(.system(size: 20)).frame(width: 38, height: 43) }.buttonStyle(HardwareButtonStyle(p: p, radius: 7)).accessibilityLabel("Increase \(label)")
            }
        }.frame(maxWidth: .infinity)
    }
}

struct RhythmGlyph: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let width = min(rect.width - 10, CGFloat(max(1, count - 1)) * 20)
        let left = (rect.width - width) / 2
        for i in 0..<count {
            let x = count == 1 ? rect.midX : left + CGFloat(i) * width / CGFloat(count - 1)
            p.addEllipse(in: CGRect(x: x - 7, y: rect.height - 12, width: 10, height: 6))
            p.addRect(CGRect(x: x + 1.5, y: 5, width: 1.8, height: rect.height - 14))
        }
        if count > 1 {
            p.addRect(CGRect(x: left + 1.5, y: 5, width: width + 1.8, height: 2.4))
            if count == 4 { p.addRect(CGRect(x: left + 1.5, y: 10, width: width + 1.8, height: 2.4)) }
        }
        return p
    }
}
