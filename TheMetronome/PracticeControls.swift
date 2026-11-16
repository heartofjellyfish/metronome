import SwiftUI

/// Shared by the Practice mode and its existing settings entry.
struct PracticeControls: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
            practiceRoute("Tempo ramp", detail: "\(model.rhythm.start) → \(model.rhythm.end) BPM", route: .ramp, enabled: model.rhythm.ramp)
            practiceRoute("Silent bars", detail: L10n.format("%d sound bars · %d silent bars", model.rhythm.audibleBars, model.rhythm.silentBars), route: .gap, enabled: model.rhythm.gap)
            }
            practiceRoute("Polyrhythm", detail: "\(model.rhythm.polyrhythmPrimary ?? 3) : \(model.rhythm.crossRhythm ?? model.rhythm.polyrhythmStoredSecondary ?? 2)", route: .polyrhythm, enabled: model.rhythm.crossCount > 0)
        }
    }
    private func practiceRoute(_ title: String, detail: String, route: InstrumentPanelKind, enabled: Bool) -> some View {
        Button { open(route) } label: {
            VStack(alignment: .leading, spacing: 12) {
                LED(on: enabled, color: InstrumentPalette.amber, size: 8)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text(title)).font(.system(size: 17, weight: .medium))
                    Text(detail).font(.system(size: 12)).foregroundStyle(p.muted)
                }

            }.padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading).frame(height: 110, alignment: .topLeading).contentShape(Rectangle())
        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("practice-\(route.rawValue)")
    }
}
