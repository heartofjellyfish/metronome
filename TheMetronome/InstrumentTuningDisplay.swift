import SwiftUI

struct InstrumentTuningDisplay<Targets: View>: View {
    let profile: TunerProfile
    let p: InstrumentPalette
    let note: Int?
    let reading: TunerReading?
    let status: String
    let notation: TunerPitchNotation
    let strings: [Int]
    let drawing: TunerStringDrawing
    let targetHeight: CGFloat
    let showsYangqin: Bool
    let stringName: String?
    let select: (Int) -> Void
    let openOptions: () -> Void
    @ViewBuilder let targets: () -> Targets

    private var artworkScale: CGFloat {
        switch profile.instrumentName {
        case "Accordion", "Organ", "Steel pan", "Handpan", "Kalimba", "Voice": return 0.90
        default: return 1
        }
    }

    var body: some View {
        let height = 330 - targetHeight
        let scale = artworkScale
        let zither = TunerZither.forInstrument(profile.instrumentName, stringCount: strings.count)
        let showsSitar = profile.instrumentName == "Sitar" && (18...20).contains(strings.count)
        let diagram: (any TunerWireDiagram)? = if let zither {
            zither
        } else if showsYangqin {
            TunerYangqin()
        } else if showsSitar {
            TunerSitar(stringCount: strings.count, horizontal: true)
        } else {
            nil
        }
        let singleRowZither = zither == .guqin
        let bounds = CGRect(x: 180 - 168 * scale, y: 310 + height * (1 - scale) / 2 + (singleRowZither ? 5 : 0),
                            width: 336 * scale, height: height * scale)
        InstrumentNeedleFace(p: p, note: note, reading: reading, status: status,
                             prefersFlats: strings.isEmpty,
                             notation: notation, showsPitchCheck: strings.isEmpty && !showsYangqin,
                             stringName: stringName) {
            if let diagram {
                wireDrawing(diagram, in: bounds)
            } else if let artwork = TunerVectorArtwork.load(profile.tuningArtworkName) {
                let frame = artwork.fitted(in: bounds)
                Button(action: openOptions) {
                    Canvas { context, size in
                        let local = CGRect(origin: .zero, size: size)
                        artwork.draw(in: context, frame: artwork.fitted(in: local), ink: drawing.outline)
                    }
                    .frame(width: max(44, frame.width), height: frame.height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
                .position(x: frame.midX, y: frame.midY)
            }
            if targetHeight > 0 {
                targets()
                    .frame(width: 340)
                    .position(x: 180, y: 637 - targetHeight / 2 - (singleRowZither ? 46 : 0))
            }
        }
    }

    private func wireDrawing(_ diagram: any TunerWireDiagram, in bounds: CGRect) -> some View {
        let frame = diagram.frame(in: bounds)
        return Canvas { context, _ in
            diagram.draw(in: context, frame: frame, surface: p.tunerDrawingSurface, drawing: drawing)
        }
        .frame(width: 360, height: 637)
        .contentShape(Path(frame))
        .onTapGesture(coordinateSpace: .local) { point in
            if let index = diagram.string(at: point, in: frame) { select(index) }
        }
        .accessibilityHidden(true)
        .position(x: 180, y: 318.5)
    }
}
