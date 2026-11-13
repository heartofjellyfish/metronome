import SwiftUI

/// Shared by the Practice mode and its existing settings entry.
struct PracticeControls: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(spacing: 16) {
            practiceRoute("Tempo ramp", detail: "\(model.rhythm.start) → \(model.rhythm.end) BPM", route: .ramp, enabled: model.rhythm.ramp)
            practiceRoute("Silent bars", detail: L10n.format("%d sound bars · %d silent bars", model.rhythm.audibleBars, model.rhythm.silentBars), route: .gap, enabled: model.rhythm.gap)
            practiceRoute("Polyrhythm", detail: "\(model.rhythm.polyrhythmPrimary ?? 3) : \(model.rhythm.crossRhythm ?? 2)", route: .polyrhythm, enabled: model.rhythm.crossCount > 0)
            HStack {
                Text("COUNT IN").font(.subheadline)
                Spacer()
                Button { open(.countIn) } label: {
                    HStack { Text(model.rhythm.countIn == 0 ? L10n.text("OFF") : L10n.bars(model.rhythm.countIn)); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("practice-countIn")
            }.padding(.top, 5)
        }
    }
    private func practiceRoute(_ title: String, detail: String, route: InstrumentPanelKind, enabled: Bool) -> some View {
        Button { open(route) } label: {
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
}
