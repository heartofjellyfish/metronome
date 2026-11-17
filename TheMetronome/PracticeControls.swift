import SwiftUI

/// Parallel training entries share one size and one visual hierarchy.
struct PracticeControls: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(spacing: 14) {
            practiceRoute("Tempo ramp", route: .ramp)
            practiceRoute("Silent bars", route: .gap)
            practiceRoute("Polyrhythm", route: .polyrhythm)
        }
    }
    private func practiceRoute(_ title: String, route: InstrumentPanelKind) -> some View {
        Button { open(route) } label: {
            HStack(spacing: 22) {
                illustration(route).frame(width: 92, height: 64).accessibilityHidden(true)
                Rectangle().fill(p.edge.opacity(0.4)).frame(width: 0.5, height: 48)
                Text(L10n.text(title)).font(.system(size: 19, weight: .medium))
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 20).frame(height: 100).contentShape(Rectangle())
        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("practice-\(route.rawValue)")
    }
    @ViewBuilder private func illustration(_ route: InstrumentPanelKind) -> some View {
        switch route {
        case .ramp:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color(hex: 0x879894), Color(hex: 0x475A57)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.5), lineWidth: 0.6))
                        .frame(width: 12, height: CGFloat(16 + i * 9))
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 2)
                }
            }
        case .gap:
            HStack(spacing: 5) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == 2 ? p.body : p.ink.opacity(0.78))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(p.muted, style: StrokeStyle(lineWidth: 1, dash: i == 2 ? [3, 2] : [])))
                        .frame(width: 17, height: 28)
                        .shadow(color: .black.opacity(i == 2 ? 0 : 0.18), radius: 1, y: 2)
                }
            }
        default:
            ZStack {
                Circle().stroke(PolyrhythmRings.color(0), lineWidth: 3).frame(width: 60, height: 60)
                Circle().stroke(PolyrhythmRings.color(1), lineWidth: 3).frame(width: 37, height: 37)
                ForEach(0..<3) { index in
                    Circle().fill(PolyrhythmRings.color(0)).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(p.light, lineWidth: 1))
                        .offset(x: sin(Double(index) * .pi * 2 / 3) * 30, y: -cos(Double(index) * .pi * 2 / 3) * 30)
                }
                ForEach(0..<2) { index in
                    Circle().fill(PolyrhythmRings.color(1)).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(p.light, lineWidth: 1)).offset(y: index == 0 ? -18.5 : 18.5)
                }
            }.shadow(color: .black.opacity(0.18), radius: 1, y: 2)
        }
    }
}
