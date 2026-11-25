import SwiftUI

enum TunerSolidPegHeadstock {
    case baglama, setar

    private struct Peg {
        let key: CGPoint
        let post: CGPoint
        let nutX: CGFloat
        let lineWidth: CGFloat

        init(_ keyX: CGFloat, _ y: CGFloat, _ postX: CGFloat, _ nutX: CGFloat, width: CGFloat = 0.72) {
            key = CGPoint(x: keyX, y: y)
            post = CGPoint(x: postX, y: y)
            self.nutX = nutX
            lineWidth = width
        }

        var left: Bool { key.x < 180 }
    }

    // From the thick side of the nut, the short-neck model has 2, 2 and 3 strings.
    // Each outer course has a wound string an octave below its steel string(s).
    static let baglamaOffsets = [[-12, 0], [0, 0], [0, 12, 12]]
    private static let baglamaCourses: [[Peg]] = [
        [.init(109, 192, 153, 157, width: 1.25), .init(113, 147, 156, 163)],
        [.init(116, 102, 160, 176, width: 0.90), .init(243, 80, 199, 182, width: 0.90)],
        [.init(246, 125, 205, 195, width: 1.05), .init(250, 170, 207, 201), .init(253, 215, 209, 207)]
    ]
    private static let setarCourses: [[Peg]] = [
        [.init(104, 158, 162, 167, width: 1.12)],
        [.init(109, 67, 166, 176, width: 0.67)],
        [.init(250, 112, 194, 185, width: 0.84)],
        [.init(255, 202, 200, 195, width: 0.67)]
    ]
    private var courses: [[Peg]] { self == .baglama ? Self.baglamaCourses : Self.setarCourses }

    var keys: [[CGPoint]] { courses.map { $0.map(\.key) } }

    var positions: [TunerHeadstock.StringPosition] {
        courses.map { course in
            let left = course.allSatisfy(\.left)
            let side = course.filter { $0.left == left }
            let y = (side[0].key.y + side[side.count - 1].key.y) / 2
            return .init(post: side[0].post, key: CGPoint(x: side[0].key.x, y: y), nutX: side[0].nutX,
                         label: CGPoint(x: left ? 46 : 313, y: y), left: left)
        }
    }

    var referenceWires: [Path] { courses.flatMap { $0 }.map(stringPath(for:)) }

    private func stringPath(for peg: Peg) -> Path {
        let x = peg.post.x, y = peg.post.y
        let direction: CGFloat = peg.left ? -1 : 1
        let nutY: CGFloat = self == .baglama ? 242 : 231
        let wrapX = x + direction * 3.5
        return Path(tunerCommands: """
                M \(wrapX + direction) \(y - 2.35)
                Q \(wrapX - direction * 2.7) \(y) \(wrapX) \(y + 2.35)
                L \(peg.nutX) \(nutY) L \(peg.nutX) 295
                """)
    }

    func draw(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing, ranges: [Range<Int>]) {
        let baglama = self == .baglama
        let nutY: CGFloat = baglama ? 242 : 231
        let outline = Path(tunerCommands: baglama ? """
            M 149 295 L 149 240 C 147 210 149 190 150 168 L 154 54
            C 155 35 164 24 180 24 C 196 24 205 35 206 54 L 210 165
            C 211 192 214 215 213 240 L 215 295 Z
            """ : """
            M 157 295 L 157 231 L 158 63 C 158 44 169 27 181 27
            C 193 27 201 44 202 63 L 203 231 L 204 295 Z
            """)
        context.stroke(outline, with: .color(drawing.outline), style: StrokeStyle(lineWidth: 1.40, lineJoin: .round))
        let guides = Path(tunerCommands: baglama
                          ? "M 149 240 L 213 240 M 149 244 L 213 244 M 149 264 L 214 264 M 149 282 L 215 282"
                          : "M 157 229 L 203 229 M 157 234 L 203 234 M 157 256 L 203 256 M 157 274 L 204 274")
        context.stroke(guides, with: .color(drawing.outline.opacity(0.82)), lineWidth: 0.86)

        let pegs = courses.flatMap { $0 }
        for index in drawing.paintOrder(pegs.indices) {
            let peg = pegs[index]
            let ink = drawing.color(for: index)
            let direction: CGFloat = peg.left ? -1 : 1
            let x = peg.post.x, y = peg.post.y
            let key = peg.key
            let shaft = Path(tunerCommands: """
                M \(key.x - direction * 10) \(y - 2.35) L \(x) \(y - 2.35)
                M \(key.x - direction * 10) \(y + 2.35) L \(x) \(y + 2.35)
                M \(x) \(y - 2.35) Q \(x - direction * 2.8) \(y - 2.0) \(x - direction * 2.8) \(y)
                Q \(x - direction * 2.8) \(y + 2.0) \(x) \(y + 2.35)
                """)
            context.stroke(shaft, with: .color(ink), style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
            let string = stringPath(for: peg)
            context.stroke(string, with: .color(ink),
                           style: StrokeStyle(lineWidth: drawing.lineWidth(for: index, normal: peg.lineWidth, focused: 1.75),
                                              lineCap: .round, lineJoin: .round))
            var grip = context
            grip.translateBy(x: key.x, y: y)
            grip.scaleBy(x: direction, y: 1)
            let shape = Path(tunerCommands: baglama ? """
                M -11 -2 Q -7 -3 -4 -7 C 2 -12 12 -10 14 -3 Q 15 0 14 3
                C 12 10 2 12 -4 7 Q -7 3 -11 2 Z
                """ : """
                M -11 -2 C -9 -4 -8 -9 -4 -11 Q 3 -15 13 -14
                C 15 -14 15 -12 13 -10 Q 5 0 13 10
                C 15 12 15 14 13 14 Q 3 15 -4 11 C -8 9 -9 4 -11 2 Z
                """)
            grip.fill(shape, with: .color(surface))
            grip.stroke(shape, with: .color(ink), style: StrokeStyle(lineWidth: 1.15, lineJoin: .round))
            drawing.drawContacts([CGPoint(x: peg.nutX, y: nutY)], for: index, in: context, diameter: 1.8)
        }
        for (course, wires) in zip(courses, ranges) where course.count > 1 && course.allSatisfy({ $0.left == course[0].left }) {
            guard let first = course.first, let last = course.last else { continue }
            let left = first.left
            let x = left ? min(first.key.x, last.key.x) - 21 : max(first.key.x, last.key.x) + 21
            let cap = x + (left ? 3 : -3)
            let top = min(first.key.y, last.key.y), bottom = max(first.key.y, last.key.y)
            let bracket = Path(tunerCommands: "M \(cap) \(top) L \(x) \(top) L \(x) \(bottom) L \(cap) \(bottom)")
            context.stroke(bracket, with: .color(drawing.color(for: wires).opacity(0.66)), lineWidth: 0.85)
        }
    }
}
