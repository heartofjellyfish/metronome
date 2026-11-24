import SwiftUI

protocol TunerWireDiagram {
    func frame(in bounds: CGRect) -> CGRect
    func draw(in context: GraphicsContext, frame: CGRect, surface: Color, drawing: TunerStringDrawing)
    func string(at point: CGPoint, in frame: CGRect) -> Int?
}

enum TunerZither: TunerWireDiagram, Equatable {
    case guqin
    case koto([Int])

    static func forInstrument(_ name: String, strings: [Int]) -> Self? {
        switch (name, strings.count) {
        case ("Guqin", 7): .guqin
        case ("Koto", 13): .koto(strings)
        default: nil
        }
    }

    var isKoto: Bool {
        if case .koto = self { return true }
        return false
    }

    // Front-view geometry is normalized to a 540-unit wide canvas.
    private var height: CGFloat {
        switch self {
        case .guqin: 140
        case .koto: 99
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
        case .koto(let notes):
            // Player's view, dragon head at right. String 1 is farthest away.
            // The reference preset follows the diagonal row seen from above.
            // Other presets can move an individual removable bridge.
            let reference = [62, 55, 57, 58, 62, 63, 67, 69, 70, 74, 75, 79, 81]
            return notes.indices.map { index in
                let row = CGFloat(index)
                let start = CGPoint(x: 34, y: 22 + row * 4.55)
                let end = CGPoint(x: 505, y: 11.5 + row * 6.35)
                let referenceX = 177 + row * 22
                let shifted = end.x - (end.x - referenceX) * pow(2, CGFloat(reference[index] - notes[index]) / 12)
                let x = min(483, max(start.x + 14, shifted))
                let y = start.y + (end.y - start.y) * (x - start.x) / (end.x - start.x)
                return Wire(start: start, bridge: CGPoint(x: x, y: y), end: end)
            }
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
            M 14 16 C 156 12 366 5 523 4 Q 531 4 533 13
            Q 539 49 533 86 Q 531 95 523 95
            C 366 94 156 88 14 83 Q 8 83 6 76 Q 1 49.5 6 23 Q 8 16 14 16 Z
            M 505 4 L 505 95
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
        case .koto: break
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
            if isKoto {
                for anchor in [points[0], points[points.count - 1]] {
                    let marker = Path(ellipseIn: CGRect(x: anchor.x - 0.95, y: anchor.y - 0.95, width: 1.9, height: 1.9))
                    context.fill(marker, with: .color(surface))
                    context.stroke(marker, with: .color(color), lineWidth: 0.65)
                }
            } else {
                drawing.drawContacts([points[0], points[1]], for: index, in: context, diameter: 2)
            }
            if self == .guqin {
                let anchor = wires[index].end
                let loop = Path(ellipseIn: CGRect(x: anchor.x, y: anchor.y - 1.8, width: 4.0, height: 3.6))
                context.stroke(loop.applying(transform), with: .color(color), lineWidth: 0.85)
                let tied = Path(tunerCommands: "M \(anchor.x + 2.2) \(anchor.y - 1.6) L \(anchor.x + 2.2) \(anchor.y + 1.6)")
                context.stroke(tied.applying(transform), with: .color(color), lineWidth: 0.6)
            }
        }
        // Short waists read as the top of the removable kotoji; each touches one string.
        for index in drawOrder {
            guard let point = wires[index].bridge else { continue }
            let x = point.x, y = point.y
            let bridge = Path(tunerCommands: """
                M \(x - 3) \(y - 5.4) L \(x + 3) \(y - 5.4)
                Q \(x + 1.3) \(y - 1.8) \(x + 1.3) \(y)
                Q \(x + 1.3) \(y + 1.8) \(x + 3) \(y + 5.4)
                L \(x - 3) \(y + 5.4)
                Q \(x - 1.3) \(y + 1.8) \(x - 1.3) \(y)
                Q \(x - 1.3) \(y - 1.8) \(x - 3) \(y - 5.4) Z
                """)
            let placed = bridge.applying(transform)
            context.fill(placed, with: .color(surface))
            let color = drawing.color(for: index)
            context.stroke(placed, with: .color(color), style: StrokeStyle(lineWidth: 0.86, lineJoin: .round))
            let contact = Path(tunerCommands: "M \(x - 2) \(y) L \(x + 2) \(y)").applying(transform)
            context.stroke(contact, with: .color(color), lineWidth: 0.76)
        }
    }

    func string(at point: CGPoint, in frame: CGRect) -> Int? {
        let local = point.applying(layout(in: frame).inverted())
        let wires = wires
        var nearest: Int?
        var bestDistance: CGFloat = 11
        for (index, wire) in wires.enumerated() {
            // A bridge projects beyond its tightly spaced string lane.
            if let bridge = wire.bridge,
               abs(local.x - bridge.x) <= 4, abs(local.y - bridge.y) <= 5.4 { return index }
        }
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
