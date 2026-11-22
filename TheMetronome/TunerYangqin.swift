import SwiftUI

struct TunerYangqin: TunerWireDiagram {
    struct Course {
        let bridge: Int
        let number: Int
        let pitch: Int?
        let wires: Range<Int>
        let y: CGFloat

        var name: String {
            let names = ["Treble bridge", "Upper tenor bridge", "Tenor bridge", "Lower tenor bridge", "Bass bridge"]
            return tunerText(names[bridge]) + " · \(number)"
        }
    }

    // 410 measured specimen, Sinin et al., BioResources 21(1), tables 1–2.
    // The display uses one reference pitch per physical course. The three pitches
    // missing from table 2 are supplied by the player, never inferred.
    static let courses: [Course] = {
        let counts = [
            [4, 2, 4, 4, 4, 4, 4, 4, 4, 2],
            [4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
            [3, 2, 3, 3, 3, 3, 3, 2, 2],
            [2, 2, 2, 2, 2, 2, 2, 1, 1],
            [2, 2, 2, 2, 2, 2, 2, 2, 2]
        ]
        let notes: [[Int?]] = [
            [73, 75, 77, 79, 81, 83, 85, 87, 89, nil],
            [61, 59, 65, 67, 69, 71, 73, 75, 77, nil],
            [56, 58, 60, 62, 64, 66, 68, 69, 70],
            [50, 52, 53, 55, 57, 59, 61, 63, nil],
            [43, 45, 47, 48, 50, 52, 54, 56, 58]
        ]
        let lanes = (0..<10).reversed().flatMap { row in
            counts.indices.compactMap { bridge -> (Int, Int)? in
                counts[bridge].indices.contains(row) ? (bridge, row) : nil
            }
        }
        var offset = 0
        return counts.indices.flatMap { bridge in
            counts[bridge].indices.map { row in
                let y = 37 + CGFloat(lanes.firstIndex { $0 == (bridge, row) }!) * 4.42
                let size = counts[bridge][row]
                defer { offset += size }
                return Course(bridge: bridge, number: row + 1, pitch: notes[bridge][row],
                              wires: offset..<(offset + size), y: y)
            }
        }
    }()

    static func courseIndex(of wire: Int) -> Int? {
        courses.firstIndex { $0.wires.contains(wire) }
    }

    private struct BridgeRow {
        let upperX: CGFloat
        let lowerX: CGFloat

        func x(at y: CGFloat) -> CGFloat {
            upperX + (lowerX - upperX) * (y - 37) / 204
        }
    }

    private static let size = CGSize(width: 540, height: 284)
    // Measured from the 410 face study: the left rows converge toward the near edge,
    // the right rows fan out, and each course gets its own saddle.
    private static let bridgeRows = [
        BridgeRow(upperX: 180, lowerX: 163), BridgeRow(upperX: 230, lowerX: 225),
        BridgeRow(upperX: 294, lowerX: 299), BridgeRow(upperX: 335, lowerX: 351),
        BridgeRow(upperX: 371, lowerX: 401)
    ]

    private func endpoints(course: Course, wire: Int) -> (anchor: CGPoint, bridge: CGPoint, pin: CGPoint) {
        let offset = CGFloat(wire - course.wires.lowerBound)
        let y = course.y + (offset - CGFloat(course.wires.count - 1) / 2) * 0.98
        let left = 120 - (y - 9) * 0.304
        let right = 540 - left
        return (CGPoint(x: left + offset * 1.15, y: y),
                CGPoint(x: Self.bridgeRows[course.bridge].x(at: y), y: y),
                CGPoint(x: right - offset * 1.15, y: y))
    }

    func frame(in bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / Self.size.width, bounds.height / Self.size.height)
        let size = CGSize(width: Self.size.width * scale, height: Self.size.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func transform(_ frame: CGRect) -> CGAffineTransform {
        CGAffineTransform(a: frame.width / Self.size.width, b: 0, c: 0, d: frame.height / Self.size.height,
                          tx: frame.minX, ty: frame.minY)
    }

    func draw(in context: GraphicsContext, frame: CGRect, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let transform = transform(frame)
        let outline = Path(tunerCommands: """
            M 116 7 C 98 9 77 10 61 16 Q 49 21 44 37
            L 8 233 C 4 257 16 270 36 271 L 504 271
            C 524 270 536 257 532 233 L 496 37 Q 491 21 479 16
            C 463 10 442 9 424 7 Q 421 7 419 12 L 121 12 Q 119 7 116 7 Z
            M 116 9 L 35 271 M 122 12 L 41 270
            M 424 9 L 505 271 M 418 12 L 499 270
            M 171 12 L 100 270 M 369 12 L 440 270
            M 250 12 C 256 79 260 172 268 270
            M 286 12 C 281 79 279 172 289 270
            M 43 265 L 497 265
            """)
        context.stroke(outline.applying(transform), with: .color(ink),
                       style: StrokeStyle(lineWidth: 1.30, lineCap: .round, lineJoin: .round))

        let allWires = Self.courses.flatMap { course in course.wires.map { (course, $0) } }
        for (course, index) in allWires where drawing.active != index && !drawing.completed.contains(index) {
            drawWire(index, in: course, context: context, transform: transform, drawing: drawing, emphasized: false)
        }
        for index in Self.bridgeRows.indices {
            let bridge = Self.bridgeRows[index]
            let courses = Self.courses.filter { $0.bridge == index }
            guard let upper = courses.map(\.y).min(), let lower = courses.map(\.y).max() else { continue }
            let top = upper - 6, bottom = lower + 6
            let slat = Path(tunerCommands: """
                M \(bridge.x(at: top) - 2.7) \(top)
                L \(bridge.x(at: bottom) - 2.7) \(bottom)
                Q \(bridge.x(at: bottom)) \(bottom + 3) \(bridge.x(at: bottom) + 2.7) \(bottom)
                L \(bridge.x(at: top) + 2.7) \(top)
                Q \(bridge.x(at: top)) \(top - 3) \(bridge.x(at: top) - 2.7) \(top) Z
                """)
            context.stroke(slat.applying(transform), with: .color(ink.opacity(0.73)), lineWidth: 0.68)

            for item in courses {
                let x = bridge.x(at: item.y)
                let height = CGFloat(item.wires.count - 1) * 0.98 + 2.4
                let saddle = Path(roundedRect: CGRect(x: x - 3.15, y: item.y - height / 2,
                                                     width: 6.3, height: height), cornerRadius: 0.95)
                    .applying(transform)
                context.fill(saddle, with: .color(surface))
                context.stroke(saddle, with: .color(ink.opacity(0.82)), lineWidth: 0.6)
            }
        }
        for (course, index) in allWires where drawing.active == index || drawing.completed.contains(index) {
            drawWire(index, in: course, context: context, transform: transform, drawing: drawing, emphasized: true)
        }
    }

    private func drawWire(_ index: Int, in course: Course, context: GraphicsContext,
                          transform: CGAffineTransform, drawing: TunerStringDrawing, emphasized: Bool) {
        let ends = endpoints(course: course, wire: index)
        let color = drawing.color(for: index)
        let path = Path { path in
            path.move(to: ends.anchor)
            path.addLine(to: ends.bridge)
            path.addLine(to: ends.pin)
        }
        context.stroke(path.applying(transform), with: .color(color.opacity(emphasized ? 1 : 0.45)),
                       lineWidth: drawing.lineWidth(for: index, normal: 0.26, focused: 1.35))
        for point in [ends.anchor, ends.pin] {
            let pin = Path(ellipseIn: CGRect(x: point.x - 1.65, y: point.y - 0.9, width: 3.3, height: 1.8))
            context.stroke(pin.applying(transform), with: .color(color), lineWidth: emphasized ? 0.9 : 0.34)
        }
        drawing.drawContacts([ends.anchor, ends.bridge, ends.pin].map { $0.applying(transform) },
                             for: index, in: context, diameter: 1.85)
    }

    func string(at point: CGPoint, in frame: CGRect) -> Int? {
        let local = point.applying(transform(frame).inverted())
        guard let course = Self.courses.min(by: { abs(local.y - $0.y) < abs(local.y - $1.y) }),
              abs(local.y - course.y) < 7 else { return nil }
        guard let index = course.wires.min(by: {
            abs(local.y - endpoints(course: course, wire: $0).anchor.y)
                < abs(local.y - endpoints(course: course, wire: $1).anchor.y)
        }) else { return nil }
        let ends = endpoints(course: course, wire: index)
        return ((ends.anchor.x - 5)...(ends.pin.x + 5)).contains(local.x) ? index : nil
    }
}
