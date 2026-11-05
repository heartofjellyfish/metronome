import SwiftUI

struct PolyrhythmPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    @State private var advanced = false
    @State private var audition = false
    @State private var rememberedLower = 2
    private var upper: Int { model.rhythm.polyrhythmPrimary ?? 3 }
    private var lower: Int { model.rhythm.crossRhythm ?? rememberedLower }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                ForEach([false, true], id: \.self) { on in
                    Button {
                        model.endSoundPreview()
                        rememberedLower = lower
                        model.rhythm.polyrhythmPrimary = upper
                        model.rhythm.crossRhythm = on ? lower : nil
                    } label: { Text(L10n.text(on ? "ON" : "OFF")).frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p, charcoal: (model.rhythm.crossCount > 0) == on))
                        .accessibilityIdentifier(on ? "polyrhythm-on" : "polyrhythm-off")
                        .accessibilityAddTraits((model.rhythm.crossCount > 0) == on ? .isSelected : [])
                }
            }
            HStack(spacing: 10) {
                ratio(3, 2); ratio(4, 3); ratio(5, 4)
            }
            VStack(spacing: 24) {
                lane(upper, title: "WOOD")
                lane(lower, title: "BELL")
            }.padding(22).insetPanel(p, radius: 14)
            HStack {
                Text("Both rows start and finish together.").font(.system(size: 14)).foregroundStyle(p.muted)
                Spacer()
                Button {
                    if audition { model.endSoundPreview(); audition = false }
                    else {
                        var value = model.rhythm; value.polyrhythmPrimary = upper; value.crossRhythm = lower
                        model.previewRhythm(value); audition = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(value.pulseCount)*60/Double(value.bpm)+0.9) { audition = false }
                    }
                } label: { Image(systemName: audition ? "stop.fill" : "speaker.wave.2").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p, charcoal: audition)).accessibilityLabel("Preview rhythm")
            }
            Button { advanced.toggle() } label: {
                HStack { Text("Other ratios"); Spacer(); Image(systemName: advanced ? "chevron.up" : "chevron.down") }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if advanced {
                countRow("WOOD", value: upper, range: 2...8) { model.rhythm.polyrhythmPrimary = $0; model.rhythm.crossRhythm = lower }
                countRow("BELL", value: lower, range: 2...9) { model.rhythm.polyrhythmPrimary = upper; model.rhythm.crossRhythm = $0 }
            }
        }.onDisappear { model.endSoundPreview() }
    }
    private func ratio(_ a: Int, _ b: Int) -> some View {
        Button {
            model.endSoundPreview(); model.rhythm.polyrhythmPrimary = a; model.rhythm.crossRhythm = b
        } label: { Text(L10n.format("%d over %d", a, b)).font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity, minHeight: 48) }
            .buttonStyle(HardwareButtonStyle(p: p, charcoal: model.rhythm.crossCount > 0 && upper == a && lower == b))
            .accessibilityIdentifier("polyrhythm-\(a)-\(b)")
            .accessibilityAddTraits(model.rhythm.crossCount > 0 && upper == a && lower == b ? .isSelected : [])
    }
    private func lane(_ count: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(L10n.text(title)).technical(11, spacing: 1); Spacer(); Text("\(count)").font(InstrumentType.value(24)) }
            HStack(spacing: 6) { ForEach(0..<count, id: \.self) { _ in Capsule().fill(title == "WOOD" ? p.ink : InstrumentPalette.amber).frame(maxWidth: .infinity).frame(height: 8) } }
        }
    }
    private func countRow(_ title: String, value: Int, range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(L10n.text(title)).technical(11, spacing: 1); Spacer()
            Button { set(value-1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }.disabled(value == range.lowerBound)
            Text("\(value)").font(InstrumentType.value(25)).frame(width: 32)
            Button { set(value+1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.disabled(value == range.upperBound)
        }.buttonStyle(HardwareButtonStyle(p: p))
    }
}
