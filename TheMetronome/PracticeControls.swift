import SwiftUI

/// Shared by the Practice mode and its existing settings entry.
struct PracticeControls: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(spacing: 0) {
            practiceRoute("Tempo ramp", detail: "\(model.rhythm.start) → \(model.rhythm.end) BPM", route: .ramp, enabled: model.rhythm.ramp)
            Divider().padding(.horizontal, 16)
            practiceRoute("Silent bars", detail: L10n.format("%d sound bars · %d silent bars", model.rhythm.audibleBars, model.rhythm.silentBars), route: .gap, enabled: model.rhythm.gap)
            Divider().padding(.horizontal, 16)
            practiceRoute("Polyrhythm", detail: "\(model.rhythm.polyrhythmPrimary ?? 3) : \(model.rhythm.crossRhythm ?? model.rhythm.polyrhythmStoredSecondary ?? 2)", route: .polyrhythm, enabled: model.rhythm.crossCount > 0)
            Divider().padding(.horizontal, 16)
            practiceRoute("Count-in", detail: model.rhythm.countIn == 0 ? L10n.text("Off") : L10n.bars(model.rhythm.countIn), route: .countIn, enabled: model.rhythm.countIn > 0)
        }.insetPanel(p, radius: 16)
    }
    private func practiceRoute(_ title: String, detail: String, route: InstrumentPanelKind, enabled: Bool) -> some View {
        Button { open(route) } label: {
            HStack(spacing: 12) {
                LED(on: enabled, color: InstrumentPalette.amber, size: 8)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text(title)).font(.system(size: 17, weight: .medium))
                    Text(detail).font(.system(size: 12)).foregroundStyle(p.muted)
                }
                Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
            }.padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 68).contentShape(Rectangle())
        }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("practice-\(route.rawValue)")
    }
}
