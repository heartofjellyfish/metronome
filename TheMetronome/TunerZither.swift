import SwiftUI

protocol TunerWireDiagram {
    func frame(in bounds: CGRect) -> CGRect
    func draw(in context: GraphicsContext, frame: CGRect, surface: Color, drawing: TunerStringDrawing)
    func string(at point: CGPoint, in frame: CGRect) -> Int?
}

enum TunerZither: TunerWireDiagram {
    case guqin, koto

    static func forInstrument(_ name: String, stringCount: Int) -> Self? {
        switch (name, stringCount) {
        case ("Guqin", 7): .guqin
        case ("Koto", 13): .koto
        default: nil
        }
    }

    // Front-view geometry is normalized to a 540-unit wide canvas.
    private var height: CGFloat {
        switch self {
        case .guqin: 140
        case .koto: 137
        }
    }

    private struct Wire {
        let start: CGPoint
        var bridge: CGPoint? = nil
        let end: CGPoint

        var points: [CGPoint] { [start] + (bridge.map { [$0] } ?? []) + [end] }
    }

    private var wires: [Wire] {
        switch self {
        case .koto:
            return Self.bridged(
                rows: [16, 22, 29, 36, 44, 53, 63, 73, 83, 92, 101, 110, 119],
                bridges: [115, 130, 153, 177, 197, 224, 242, 267, 298, 319, 345, 367, 398],
                left: 60, right: 484, rise: 3
            )
        case .guqin:
            return (0..<7).map { index in
                let row = CGFloat(index)
                return Wire(start: CGPoint(x: 19, y: 55.5 + row * 5.8),
                            end: CGPoint(x: 502, y: 43.5 + row * 10.2))
            }
        }
    }

    private static let guqinHui: [CGFloat] = [
        1.0/8, 1.0/6, 1.0/5, 1.0/4, 1.0/3, 2.0/5, 1.0/2, 3.0/5, 2.0/3, 3.0/4, 4.0/5, 5.0/6, 7.0/8
    ]

    private static func bridged(rows: [CGFloat], bridges: [CGFloat],
                                left: CGFloat, right: CGFloat, rise: CGFloat) -> [Wire] {
        zip(rows, bridges).map { y, x in
            let anchor = left - max(0, y - rows[0]) * 0.06
            let t = (x - anchor) / (right - anchor)
            return Wire(start: CGPoint(x: anchor, y: y), bridge: CGPoint(x: x, y: y + rise * t),
                        end: CGPoint(x: right - max(0, y - 90) * 0.12, y: y + rise))
        }
    }

    private var outline: String {
        switch self {
        case .guqin: """
            M 8 61 C 14 40 26 35 46 34 Q 79 34 105 33
            C 122 33 133 40 151 38 Q 168 36 180 35
            C 193 34 204 40 229 30 L 383 20
            Q 391 20 398 25 C 415 37 458 29 510 17
            Q 521 14 528 27 C 544 51 543 88 530 111 Q 522 127 509 122
            C 454 108 421 101 400 113 Q 394 120 384 121
            L 228 115 C 204 105 192 111 177 110 Q 159 109 149 106
            C 130 102 120 111 108 111 Q 70 111 43 110
            C 27 110 11 95 8 84 Q 7 72 8 61 Z
            M 19 52 C 25 42 34 37 48 35 M 19 94 C 25 103 34 108 48 110
            M 16 52 L 21 52 L 21 94 L 16 94 Z
            M 495 32 C 504 30 509 35 511 44 C 515 63 515 88 511 105
            Q 509 113 495 113 Z
            """
        case .koto: """
            M 20 10 C 100 7 251 9 466 11 Q 503 11 522 16
            C 532 25 533 43 533 58 L 534 103 Q 533 123 525 129
            L 17 129 C 2 127 1 103 3 72 C 4 47 11 21 20 10 Z
            M 14 124 L 528 124
            M 57 8 C 43 34 38 101 45 129 M 64 8 C 51 39 45 102 52 129
            M 468 11 C 485 44 491 97 481 129 M 476 11 C 494 43 500 100 489 129
            """
        }
    }

    func frame(in bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / 540, bounds.height / height)
        let size = CGSize(width: 540 * scale, height: height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func layout(in frame: CGRect) -> CGAffineTransform {
        CGAffineTransform(a: frame.width / 540, b: 0, c: 0, d: frame.height / height, tx: frame.minX, ty: frame.minY)
    }

    func draw(in context: GraphicsContext, frame: CGRect, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let transform = layout(in: frame)
        let outlineStyle = StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
        context.stroke(Path(tunerCommands: outline).applying(transform), with: .color(ink), style: outlineStyle)
        let wires = wires
        switch self {
        case .guqin:
            let first = wires[0]
            for fraction in Self.guqinHui {
                let x = first.start.x + (first.end.x - first.start.x) * fraction
                let y = first.start.y + (first.end.y - first.start.y) * fraction - 8
                let marker = CGRect(x: x - 1.75, y: y - 1.75, width: 3.5, height: 3.5)
                context.stroke(Path(ellipseIn: marker).applying(transform), with: .color(ink), lineWidth: 0.75)
            }
        case .koto:
            let endCurls = Path(tunerCommands: """
                M 510 24 C 520 24 526 33 526 44 C 526 53 520 60 514 60
                C 504 60 499 51 499 40 C 499 31 503 24 510 24 Z
                M 513 67 C 522 67 528 76 528 87 C 528 98 523 106 515 106
                C 506 106 500 97 500 87 C 500 76 505 67 513 67 Z
                """)
            context.stroke(endCurls.applying(transform), with: .color(ink), lineWidth: 1.0)
        }

        let drawOrder = drawing.paintOrder(wires.indices)
        for index in drawOrder {
            let points = wires[index].points.map { $0.applying(transform) }
            let path = Path { path in
                path.move(to: points[0])
                for point in points.dropFirst() { path.addLine(to: point) }
            }
            let color = drawing.color(for: index)
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: drawing.lineWidth(for: index, normal: 0.76, focused: 1.65),
                                              lineCap: .round, lineJoin: .round))
            drawing.drawContacts([points[0], points[points.count - 1]], for: index, in: context, diameter: 2)
            if self == .guqin {
                let anchor = wires[index].end
                let loop = Path(ellipseIn: CGRect(x: anchor.x, y: anchor.y - 1.8, width: 4.0, height: 3.6))
                context.stroke(loop.applying(transform), with: .color(color), lineWidth: 0.85)
                let tied = Path(tunerCommands: "M \(anchor.x + 2.2) \(anchor.y - 1.6) L \(anchor.x + 2.2) \(anchor.y + 1.6)")
                context.stroke(tied.applying(transform), with: .color(color), lineWidth: 0.6)
            }
        }
        // The bridges sit in front of the wires at their own contact points.
        for index in drawOrder {
            guard let point = wires[index].bridge else { continue }
            let x = point.x, y = point.y
            let foot = min(y + 9, 123)
            let bridge = Path(tunerCommands: """
                M \(x - 8) \(foot) L \(x - 3) \(y + 1)
                Q \(x - 2) \(y) \(x) \(y)
                Q \(x + 2) \(y) \(x + 3) \(y + 1) L \(x + 8) \(foot) Z
                """)
            let placed = bridge.applying(transform)
            context.fill(placed, with: .color(surface))
            context.stroke(placed, with: .color(drawing.color(for: index)), lineWidth: 0.9)
        }
    }

    func string(at point: CGPoint, in frame: CGRect) -> Int? {
        let local = point.applying(layout(in: frame).inverted())
        var nearest: Int?
        var bestDistance: CGFloat = 11
        for (index, wire) in wires.enumerated() {
            guard local.x >= wire.start.x - 6, local.x <= wire.end.x + 6 else { continue }
            let points = wire.points
            for (start, end) in zip(points, points.dropFirst()) where local.x >= start.x - 6 && local.x <= end.x + 6 {
                let t = (local.x - start.x) / (end.x - start.x)
                let distance = abs(local.y - (start.y + t * (end.y - start.y)))
                if distance < bestDistance {
                    bestDistance = distance
                    nearest = index
                }
            }
        }
        return nearest
    }
}
