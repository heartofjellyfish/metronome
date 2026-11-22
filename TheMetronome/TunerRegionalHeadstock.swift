import SwiftUI

enum TunerRegionalHeadstock: TunerHeadstockDrawing {
    case erhu, shamisen, arabicOud

    static func forInstrument(_ name: String, stringCount: Int) -> Self? {
        switch (name, stringCount) {
        case ("Erhu", 2): .erhu
        case ("Shamisen", 3): .shamisen
        case ("Oud · Arabic", 6): .arabicOud
        default: nil
        }
    }

    private var transform: CGAffineTransform {
        switch self {
        case .erhu: CGAffineTransform(a: 0.88, b: 0, c: 0, d: 0.88, tx: 76, ty: 12)
        case .shamisen: CGAffineTransform(a: 0.51, b: 0, c: 0, d: 0.51, tx: 57.6, ty: 27)
        case .arabicOud: CGAffineTransform(a: 0.81, b: 0, c: 0, d: 0.81, tx: 78, ty: 12)
        }
    }

    var isHeadless: Bool { false }
    var stringHitHeight: CGFloat { self == .arabicOud ? 49 : 44 }
    func stringNumber(at index: Int, count: Int) -> Int { index + 1 }

    private static let erhuPegs: [(y: CGFloat, windingX: CGFloat)] = [(99, 189), (183, 197)]

    var positions: [TunerHeadstock.StringPosition] {
        switch self {
        case .erhu:
            Self.erhuPegs.map { peg in
                position(post: (peg.windingX, peg.y), at: (66, peg.y), labelX: 78, left: true)
            }
        case .shamisen:
            [position(post: (224, 160), at: (388, 155), labelX: 328),
             position(post: (239, 196), at: (79, 195), labelX: 32, left: true),
             position(post: (254, 268), at: (389, 276), labelX: 328)]
        case .arabicOud:
            Self.oudCourses.map { course in
                let right = course.filter { !$0.left }
                let pegs = right.isEmpty ? course : right
                let first = pegs[0], last = pegs[pegs.count - 1]
                return position(post: (first.winding, first.y), at: ((first.key + last.key) / 2, (first.y + last.y) / 2),
                                labelX: first.left ? 51 : 308, left: first.left)
            }
        }
    }

    var courseKeys: [[CGPoint]] {
        self == .arabicOud ? Self.oudCourses.map { $0.map { point($0.key, $0.y) } } : positions.map { [$0.key] }
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y).applying(transform)
    }

    private func position(post: (CGFloat, CGFloat), at key: (CGFloat, CGFloat), labelX: CGFloat,
                          left: Bool = false) -> TunerHeadstock.StringPosition {
        let key = point(key.0, key.1)
        return .init(post: point(post.0, post.1), key: key, nutX: 0,
                     label: CGPoint(x: labelX, y: key.y), left: left)
    }

    func draw(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        switch self {
        case .erhu: drawErhu(in: context, surface: surface, drawing: drawing)
        case .shamisen: drawShamisen(in: context, drawing: drawing)
        case .arabicOud: drawOud(in: context, surface: surface, drawing: drawing)
        }
    }

    private func stroke(_ commands: String, in context: GraphicsContext, color: Color, width: CGFloat = 1.35,
                        fill: Color? = nil) {
        let path = Path(tunerCommands: commands).applying(transform)
        if let fill { context.fill(path, with: .color(fill)) }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func drawErhu(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        // Dunhuang 04A head and neck through the qianjin.
        let neck = Path(tunerCommands: """
            M 149 348 L 149 94 C 149 77 156 61 151 45
            C 144 26 128 17 112 16 Q 113 9 124 4 Q 132 1 136 4
            C 167 20 178 45 171 84 Q 170 90 170 94 L 170 348 Z
            """).applying(transform)
        context.stroke(neck, with: .color(ink), style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
        stroke("M 125 18 Q 126 10 135 5 M 131 21 Q 132 13 141 8", in: context, color: ink)

        // The neck hides the middle of each continuous shaft.
        var outsideNeck = context
        outsideNeck.clip(to: neck, options: .inverse)
        let shaft = """
            M 202 -4 L 147 -4 C 118 -4 86 -16 56 -15
            C 40 -15 38 -9 38 0 C 38 9 41 15 54 15
            C 85 16 117 4 147 4 L 202 4 Q 206 4 206 0 Q 206 -4 202 -4 Z
            M 50 -14 C 44 -9 44 9 50 14 M 55 -14 C 50 -9 50 9 55 14
            """

        let guide = "M 147 241 L 194 241 Q 197 241 197 244 L 197 250 Q 197 253 194 253 L 147 253 Z"
        stroke(guide, in: context, color: ink, width: 0.92, fill: surface)
        stroke("M 148 245 L 196 245 M 148 249 L 196 249", in: context, color: ink, width: 0.54)

        for index in drawing.paintOrder(Self.erhuPegs.indices) {
            let (y, windingX) = Self.erhuPegs[index]
            let color = drawing.color(for: index)
            var peg = outsideNeck
            peg.translateBy(x: 0, y: y * transform.d)
            stroke(shaft, in: peg, color: color, width: 1.1)

            let guideX = CGFloat(185 + index * 5)
            stroke("""
                M \(windingX) -4 C \(windingX - 3) -4 \(windingX - 3) 4 \(windingX) 4
                M \(windingX + 3) -4 C \(windingX) -3 \(windingX) 3 \(windingX + 3) 4
                """, in: peg, color: color, width: 0.7)
            stroke("M \(windingX) \(y + 4) L \(guideX) 247 L \(guideX + CGFloat(index) * 2) 348",
                   in: context, color: color,
                   width: drawing.lineWidth(for: index, normal: 0.82, focused: 1.8))
            drawing.drawContacts([point(guideX, 247)], for: index, in: context, diameter: 1.85)
        }
    }

    private func drawShamisen(in context: GraphicsContext, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        stroke("""
            M 207 533 L 207 367 C 190 354 187 335 190 312 L 199 300 L 199 123
            L 164 102 L 155 34 Q 236 -20 318 34 L 308 102 L 276 123 L 277 299
            L 287 312 C 291 333 283 354 270 366 L 270 533 Z
            M 215 115 L 259 115 L 260 303 L 215 303 Z
            """, in: context, color: ink)
        let handles = [
            "M 276 151 L 300 150 L 301 146 L 465 128 C 475 132 475 171 467 177 L 301 175 L 298 170 L 276 170 Z M 305 153 L 469 137",
            "M 198 188 L 178 186 L 177 182 L 15 170 C 4 172 4 214 12 219 L 177 210 L 179 204 L 198 205 Z M 10 179 L 173 189",
            "M 277 259 L 298 259 L 301 255 L 468 258 C 477 264 475 295 468 308 L 300 283 L 297 279 L 277 278 Z M 305 263 L 470 268"
        ]
        let shafts: [CGFloat] = [160, 196, 268]
        let posts: [CGFloat] = [224, 239, 253]
        let wires = [
            "M 224 168 C 224 224 224 254 224 303 L 224 533",
            "M 239 204 Q 242 266 239 303 L 239 533",
            "M 253 276 Q 254 293 253 303 L 253 533"
        ]
        for index in shafts.indices {
            let y = shafts[index], x = posts[index]
            let color = drawing.color(for: index)
            stroke(handles[index], in: context, color: color, width: 1.15)
            stroke("M 215 \(y - 8) L 259 \(y - 8) M 215 \(y + 8) L 259 \(y + 8)",
                   in: context, color: color, width: 0.82)
            stroke("""
                M \(x - 4) \(y + 8) C \(x - 7) \(y + 4) \(x - 7) \(y - 8) \(x - 4) \(y - 8)
                C \(x - 1) \(y - 8) \(x - 2) \(y + 5) \(x) \(y + 8)
                M \(x + 2) \(y + 8) Q \(x + 4) \(y + 4) \(x + 4) \(y)
                Q \(x + 4) \(y - 7) \(x + 2) \(y - 8)
                """, in: context, color: color, width: drawing.lineWidth(for: index, normal: 0.85, focused: 1.35))
        }
        for index in drawing.paintOrder(wires.indices) {
            stroke(wires[index], in: context, color: drawing.color(for: index),
                   width: drawing.lineWidth(for: index, normal: 1.12 - CGFloat(index) * 0.1, focused: 1.95))
        }
    }

    private struct OudPeg {
        let key: CGFloat
        let y: CGFloat
        let winding: CGFloat
        let nut: CGFloat
        var left: Bool { key < 126 }

        init(_ key: CGFloat, _ y: CGFloat, _ winding: CGFloat, _ nut: CGFloat) {
            self.key = key
            self.y = y
            self.winding = winding
            self.nut = nut
        }
    }

    // Centerlines taken from tuner-oud-arabic-face. One bass single and five double courses.
    private static let oudCourses: [[OudPeg]] = [
        [.init(32, 263, 76, 79)],
        [.init(32, 225, 83, 89), .init(37, 187, 84, 93)],
        [.init(45, 149, 91, 103), .init(48, 111, 92, 107)],
        [.init(50, 73, 101, 119), .init(202, 92, 139, 123)],
        [.init(205, 130, 147, 134), .init(211, 168, 149, 138)],
        [.init(217, 206, 157, 149), .init(220, 244, 158, 153)]
    ]

    private func drawOud(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let contour = """
            M 69 366 L 69 311 Q 69 299 59 270 C 48 230 69 163 74 103 Q 76 79 74 53
            C 72 20 96 6 126 6 C 156 6 180 20 178 53 Q 176 79 178 103
            C 183 163 204 230 193 270 Q 183 299 183 311 L 183 366 Z
            """
        let channel = """
            M 80 309 Q 70 275 67 250 C 66 212 82 147 84 102 Q 87 77 85 54
            C 84 30 103 17 126 17 C 149 17 168 30 167 54 Q 165 77 168 102
            C 170 147 186 212 185 250 Q 182 275 172 309
            """
        var outside = context
        outside.clip(to: Path(tunerCommands: contour).applying(transform), options: .inverse)
        var inside = context
        inside.clip(to: Path(tunerCommands: channel + " Z").applying(transform))
        stroke(contour, in: context, color: ink)
        stroke(channel, in: context, color: ink.opacity(0.78), width: 0.88)
        stroke("M 69 309 L 183 309 M 69 317 L 183 317", in: context, color: ink, width: 1.05)

        for (course, wires) in zip(Self.oudCourses, wireRanges) {
            for (peg, index) in zip(course, wires) {
                let color = drawing.color(for: index)
                let edge = peg.key + (peg.left ? 11 : -11)
                let shaft = """
                    M \(edge) \(peg.y - 2.25) L \(peg.winding) \(peg.y - 2.25)
                    M \(edge) \(peg.y + 2.25) L \(peg.winding) \(peg.y + 2.25)
                    """
                stroke(shaft, in: outside, color: color, width: 0.84)
                stroke(shaft, in: inside, color: color, width: 0.72)
                stroke("""
                    M \(peg.winding) \(peg.y + 2.25)
                    Q \(peg.winding - (peg.left ? 1 : -1)) \(peg.y - 5) \(peg.winding + (peg.left ? 2.4 : -2.4)) \(peg.y - 1)
                    L \(peg.nut) 309 L \(peg.nut) 366
                    """, in: context, color: color, width: drawing.lineWidth(for: index, normal: 0.85, focused: 1.7))
                let center = point(peg.key, peg.y)
                let key = Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 6.6, width: 20, height: 13.2))
                context.fill(key, with: .color(surface))
                context.stroke(key, with: .color(color), lineWidth: 1.2)
                drawing.drawContacts([point(peg.nut, 309), point(peg.nut, 317)], for: index, in: context)
            }
            if course.count == 2, course[0].left == course[1].left {
                let left = course[0].left
                let x = left ? min(course[0].key, course[1].key) - 20 : max(course[0].key, course[1].key) + 20
                let cap = x + (left ? 3 : -3)
                let top = min(course[0].y, course[1].y), bottom = max(course[0].y, course[1].y)
                stroke("M \(cap) \(top) L \(x) \(top) L \(x) \(bottom) L \(cap) \(bottom)",
                       in: context, color: drawing.color(for: wires).opacity(0.63), width: 0.8)
            }
        }
    }
}
