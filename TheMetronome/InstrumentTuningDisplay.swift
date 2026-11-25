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
    let select: (Int, TunerReferenceAction) -> Void
    let auditionNote: ((Int, TunerReferenceAction) -> Void)?
    let previewingNote: Bool
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
        let zither = TunerZither.forInstrument(profile.instrumentName, strings: strings)
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
        let isKoto = zither?.isKoto == true
        let diagramWidth: CGFloat = isKoto ? 348 : 336
        let verticalOffset: CGFloat = isKoto ? 38 : singleRowZither ? 5 : 0
        let targetLift: CGFloat = isKoto ? 12 : singleRowZither ? 46 : 0
        let bounds = CGRect(x: 180 - diagramWidth * scale / 2,
                            y: 310 + height * (1 - scale) / 2 + verticalOffset,
                            width: diagramWidth * scale, height: height * scale)
        InstrumentNeedleFace(p: p, note: note, reading: reading, status: status,
                             prefersFlats: strings.isEmpty || profile.prefersFlatStringNotes,
                             notation: notation, showsPitchCheck: strings.isEmpty && !showsYangqin,
                             stringName: stringName, showsStringStatus: drawing.active != nil,
                             auditionNote: auditionNote, previewingNote: previewingNote) {
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
                    .position(x: 180, y: 637 - targetHeight / 2 - targetLift)
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
        .modifier(TunerReferenceGesture { action, point in
            if let index = diagram.string(at: point, in: frame) { select(index, action) }
        })
        .accessibilityHidden(true)
        .position(x: 180, y: 318.5)
    }
}
