import SwiftUI

struct TempoKeypad: View {
    let title: String
    let p: InstrumentPalette
    let feedback: () -> Void
    let apply: (Int) -> Void
    @State private var digits: String
    @State private var replaceDigits = true

    init(initial: Int, title: String, p: InstrumentPalette, feedback: @escaping () -> Void, apply: @escaping (Int) -> Void) {
        _digits = State(initialValue: String(initial))
        self.title = title
        self.p = p
        self.feedback = feedback
        self.apply = apply
    }
    private var validNumber: Bool { Int(digits).map { TempoScale.range.contains($0) } ?? false }
    var body: some View {
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
            PanelCommitButton(title: title, enabled: validNumber, p: p) {
                guard let value = Int(digits), validNumber else { return }
                apply(value)
            }
        }
    }
    private func typeDigit(_ key: String) {
        feedback()
        if key == "CLR" { digits = ""; replaceDigits = false; return }
        if key == "⌫" { if !digits.isEmpty { digits.removeLast() }; replaceDigits = false; return }
        if replaceDigits { digits = key; replaceDigits = false }
        else if digits.count < 3 { digits = digits == "0" ? key : digits + key }
    }
}

struct PanelCommitButton: View {
    let title: String
    let enabled: Bool
    let p: InstrumentPalette
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(L10n.text(title)).technical(12, spacing: 2); Spacer(); Image(systemName: "arrow.right").font(.system(size: 17, weight: .light)) }
                .padding(.horizontal, 19).frame(height: 52).frame(maxWidth: .infinity)
        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true, radius: 10)).disabled(!enabled).opacity(enabled ? 1 : 0.45)
            .accessibilityIdentifier("panelApply")
    }
}
