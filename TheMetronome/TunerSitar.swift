import SwiftUI

struct TunerSitar: TunerWireDiagram {
    // The drawing follows Nodu Mullick's 1961 concert sitar (British Museum 2017,3039.1).
    // String routing and the editable Bilaval starting pitches follow Hackleman's peg chart.
    static let cSharp = [54, 49, 44, 37, 56, 61, 73, 61, 61, 60, 61, 63, 65, 66, 66, 68, 70, 72, 73, 75]
    static let baseCount = 7

    private static let size = CGSize(width: 120, height: 328)
    private static let playingBridge = CGRect(x: 46.6, y: 278, width: 26.8, height: 9.1)
    private static let sympatheticBridge = CGRect(x: 51, y: 265.2, width: 18, height: 6.2)
    private static let anchorY: CGFloat = 311.5
    private static let neckLeft: CGFloat = 47
    private static let neckRight: CGFloat = 74

    let stringCount: Int
    var horizontal = false

    private enum KeyType {
        case face, side, sympathetic

        var isSympathetic: Bool { self == .sympathetic }
        var span: CGFloat { self == .sympathetic ? 3.2 : 6.4 }
    }

    private struct Wire {
        let key: CGPoint
        let winding: CGPoint
        let guide: CGPoint
        let bridge: CGPoint
        let anchor: CGPoint
        let keyType: KeyType

        var string: Path {
            Path { path in
                path.move(to: winding)
                path.addLine(to: guide)
                path.addLine(to: bridge)
                path.addLine(to: anchor)
            }
        }

        var shaft: Path {
            Path { path in
                path.move(to: CGPoint(x: key.x + keyType.span, y: key.y))
                path.addLine(to: CGPoint(x: winding.x, y: key.y))
                path.addLine(to: winding)
            }
        }
    }

    private var wires: [Wire] {
        let keys = [
            CGPoint(x: 60.5, y: 47), CGPoint(x: 60.5, y: 17.5),
            CGPoint(x: 32, y: 22.4), CGPoint(x: 32, y: 43.1), CGPoint(x: 32, y: 64.3),
            CGPoint(x: 34.4, y: 94), CGPoint(x: 34.4, y: 115.2)
        ]
        let main = keys.enumerated().map { index, key in
            let lane = CGFloat(index)
            let x = 68 - lane * 2.7
            let winding = switch index {
            case 0, 1: CGPoint(x: key.x + 3.1, y: key.y + 2.8)
            default: CGPoint(x: 53.2 - lane * 0.28, y: key.y + 2)
            }
            return Wire(key: key, winding: winding,
                        guide: CGPoint(x: x, y: index < 5 ? 78.8 : key.y + 5.4),
                        bridge: CGPoint(x: 67.8 - lane * 2.55, y: Self.playingBridge.midY),
                        anchor: CGPoint(x: 64.6 - lane * 1.72, y: Self.anchorY),
                        keyType: index < 2 ? .face : .side)
        }

        let count = stringCount - Self.baseCount
        let sympathetic = (0..<count).map { index in
            let fraction = CGFloat(index) / CGFloat(max(1, count - 1))
            let y = 127 + 77 * fraction
            let x = 53.2 + 13.6 * fraction
            return Wire(key: CGPoint(x: 41, y: y),
                        winding: CGPoint(x: x - 1.15, y: y + 1.7),
                        guide: CGPoint(x: x, y: y + 7.3),
                        bridge: CGPoint(x: x, y: Self.sympatheticBridge.midY),
                        anchor: CGPoint(x: 54.7 + 10.1 * fraction, y: Self.anchorY - 1.6),
                        keyType: .sympathetic)
        }
        return main + sympathetic
    }

    func frame(in bounds: CGRect) -> CGRect {
        let size = horizontal ? CGSize(width: Self.size.height, height: Self.size.width) : Self.size
        let scale = min(bounds.height / size.height, bounds.width / size.width)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    private func transform(_ frame: CGRect) -> CGAffineTransform {
        if horizontal {
            return CGAffineTransform(a: 0, b: -frame.height / Self.size.width, c: frame.width / Self.size.height, d: 0,
                                     tx: frame.minX, ty: frame.maxY)
        }
        return CGAffineTransform(a: frame.width / Self.size.width, b: 0, c: 0, d: frame.height / Self.size.height,
                                 tx: frame.minX, ty: frame.minY)
    }

    func draw(in context: GraphicsContext, frame: CGRect, surface: Color, drawing: TunerStringDrawing) {
        let transform = transform(frame)
        let ink = drawing.outline
        drawStructure(in: context, transform: transform, ink: ink)

        let wires = wires
        let order = drawing.paintOrder(wires.indices)
        for index in order where wires[index].keyType.isSympathetic
            && !drawing.completed.contains(index) && drawing.active != index {
            stroke(wires[index].string, in: context, transform: transform, color: ink.opacity(0.20), width: 0.4)
        }
        drawFretsAndBridges(in: context, transform: transform, ink: ink)

        for index in order {
            let wire = wires[index]
            let color = drawing.color(for: index)
            let marked = drawing.completed.contains(index) || drawing.active == index
            if !wire.keyType.isSympathetic || marked {
                let width = drawing.lineWidth(for: index, normal: wire.keyType.isSympathetic ? 0.68 : 0.55, focused: 1.48)
                stroke(wire.string, in: context, transform: transform,
                       color: marked ? color : color.opacity(0.64), width: width)
            }
            drawPeg(wire, in: context, transform: transform, ink: color, surface: surface, marked: marked)
            if index < 5 {
                let y = 297 + CGFloat(index % 2) * 4.2
                let x = wire.bridge.x + (wire.anchor.x - wire.bridge.x) * (y - wire.bridge.y) / (wire.anchor.y - wire.bridge.y)
                let bead = Path(ellipseIn: CGRect(x: x - 1.13, y: y - 1.65, width: 2.26, height: 3.3))
                stroke(bead, in: context, transform: transform, color: marked ? color : ink.opacity(0.54), width: 0.64)
            }
            drawing.drawContacts([wire.winding, wire.bridge, wire.anchor].map { $0.applying(transform) },
                                 for: index, in: context, diameter: wire.keyType.isSympathetic ? 1.5 : 1.85)
        }
    }

    private func drawStructure(in context: GraphicsContext, transform: CGAffineTransform, ink: Color) {
        // The crescent is the visible edge of the rear gourd in an orthographic view.
        let upperGourd = Path(tunerCommands: """
            M 75 51 C 86 55 92 63 93 72 C 95 85 88 96 74 100
            M 79 61 C 87 67 88 77 84 84 Q 82 89 79 91
            """)
        stroke(upperGourd, in: context, transform: transform, color: ink, width: 1.04)

        let body = Path(tunerCommands: """
            M 47 3.8 L 74 3.8 Q 75.8 3.8 75.8 5.7 L 75.8 71
            Q 75.8 73 74 73 L 74 213
            C 74 232 80 238 90 247 C 100 255 109 268 110 282
            C 112 299 104 311 92 317 C 84 321 76 322 67 320
            Q 64 323 60.5 325 Q 57 323 54 320
            C 45 322 37 321 29 317 C 17 311 9 299 11 282
            C 12 268 21 255 31 247 C 41 238 47 232 47 213
            L 47 73 Q 45.2 73 45.2 71 L 45.2 5.7 Q 45.2 3.8 47 3.8 Z
            """)
        stroke(body, in: context, transform: transform, color: ink, width: 1.62)

        let bindingAndCollar = Path(tunerCommands: """
            M 47.7 6.3 L 73.3 6.3 L 73.3 70.5 L 47.7 70.5 Z
            M 47 73 Q 60.5 74.4 74 73
            M 47 80 Q 60.5 77.5 74 80
            M 48.7 221 C 50 232 48 240 46 244
            C 50 251 54 254 60.5 256 Q 69 251 75 244
            C 73 239 71 232 72.3 221
            M 46.5 237 C 41 245 35 249 29 256 C 20 265 15 275 15 286
            C 15 302 23 311 35 315 Q 47 319 54 316
            M 74.5 237 C 80 245 86 249 92 256 C 101 265 106 275 106 286
            C 106 302 98 311 86 315 Q 74 319 67 316
            M 53.2 315.5 Q 56.2 312.8 57.1 308.8 Q 60.5 305.8 63.9 308.8 Q 64.8 312.8 67.8 315.5
            """)
        stroke(bindingAndCollar, in: context, transform: transform, color: ink.opacity(0.72), width: 0.86)

        let leftInlay = Path(tunerCommands: """
            M 27 291 C 24 283 28 272 37 268 Q 40 266 40 263
            M 28 286 Q 29 276 35 275 Q 40 275 41 278
            M 28 282 Q 24 282 22 277 Q 26 277 28 280
            """)
        let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 121, ty: 0)
        stroke(leftInlay, in: context, transform: transform, color: ink.opacity(0.63), width: 0.69)
        stroke(leftInlay.applying(mirror), in: context, transform: transform, color: ink.opacity(0.63), width: 0.69)
    }

    private func drawFretsAndBridges(in context: GraphicsContext, transform: CGAffineTransform, ink: Color) {
        let frets: [CGFloat] = [87, 96, 105.6, 116.9, 126.9, 137, 146.4, 155.3, 163.7,
                                171.7, 179.1, 186.0, 192.4, 198.5, 204.3, 209.8, 215]
        for y in frets {
            let fret = Path { path in
                path.move(to: CGPoint(x: Self.neckLeft, y: y))
                path.addQuadCurve(to: CGPoint(x: Self.neckRight, y: y),
                                  control: CGPoint(x: 60.5, y: y - 2.4))
            }
            stroke(fret, in: context, transform: transform, color: ink.opacity(0.65), width: 0.74)
        }
        for bridge in [Self.sympatheticBridge, Self.playingBridge] {
            let jawari = Path(roundedRect: bridge, cornerRadius: 0.8)
            stroke(jawari, in: context, transform: transform, color: ink, width: 1.12)
        }
    }

    private func drawPeg(_ wire: Wire, in context: GraphicsContext, transform: CGAffineTransform,
                         ink: Color, surface: Color, marked: Bool) {
        let type = wire.keyType
        let isSmall = type.isSympathetic
        if type != .face {
            var shaft = context
            if isSmall, !marked {
                let outsideNeck = CGRect(x: 0, y: 0, width: Self.neckLeft, height: Self.size.height)
                shaft.clip(to: Path(outsideNeck.applying(transform)))
            }
            stroke(wire.shaft, in: shaft, transform: transform, color: ink, width: isSmall ? 0.70 : 1.0)
        }

        let outline: Path
        let carving: Path
        switch type {
        case .face:
            outline = Path(tunerCommands: """
                M 0 -4.7 C 2 -5.1 4.7 -3.8 4.7 -1.1 Q 5.2 1.6 3.2 3.8
                C 1.2 5.2 -2.5 5.2 -4 2.8 Q -5.1 1.1 -4.8 -1
                C -4.7 -3.5 -2.4 -5.1 0 -4.7 Z
                """)
            carving = Path(ellipseIn: CGRect(x: -1.75, y: -1.75, width: 3.5, height: 3.5))
        case .side:
            outline = Path(tunerCommands: """
                M 6.6 -1.7 L 5.5 -1.7 C 3.5 -4.1 1 -5.2 -1.8 -5
                C -4.3 -4.8 -6.4 -3.1 -7 -1.8 C -9.1 -1.8 -9.3 1.8 -7 1.8
                C -6.4 3 -4.3 4.8 -1.8 5 C 1 5.2 3.5 4.1 5.5 1.7 L 6.6 1.7 Z
                """)
            carving = Path(tunerCommands: """
                M -6.9 -1.7 C -3.2 -4 0.1 -1.9 5.5 -1.7
                M -6.9 1.7 C -3.2 4 0.1 1.9 5.5 1.7
                """)
        case .sympathetic:
            outline = Path(tunerCommands: """
                M 3.3 -0.8 C 1.3 -0.8 0.9 -2.1 -0.8 -2.1
                C -2.4 -2.1 -3.5 -1 -3.5 0 C -3.5 1 -2.4 2.1 -0.8 2.1
                C 0.9 2.1 1.3 0.8 3.3 0.8 Z
                """)
            carving = Path()
        }

        let placement = CGAffineTransform(translationX: wire.key.x, y: wire.key.y).concatenating(transform)
        let key = outline.applying(placement)
        context.fill(key, with: .color(surface))
        context.stroke(key, with: .color(ink), style: StrokeStyle(lineWidth: isSmall ? 0.76 : 1.18, lineJoin: .round))
        if !isSmall {
            stroke(carving, in: context, transform: placement, color: ink, width: 0.75)
        }
    }

    private func stroke(_ path: Path, in context: GraphicsContext, transform: CGAffineTransform, color: Color, width: CGFloat) {
        context.stroke(path.applying(transform), with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func string(at point: CGPoint, in frame: CGRect) -> Int? {
        let local = point.applying(transform(frame).inverted())
        let wires = wires
        let distances = wires.map { hypot(local.x - $0.key.x, local.y - $0.key.y) }
        guard let index = distances.indices.min(by: { distances[$0] < distances[$1] }),
              distances[index] < (wires[index].keyType.isSympathetic ? 8 : 13) else { return nil }
        return index
    }
}
