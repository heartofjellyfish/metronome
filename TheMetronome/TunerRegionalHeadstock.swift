import SwiftUI

enum TunerRegionalHeadstock: TunerHeadstockDrawing {
    case erhu, shamisen, arabicOud, turkishOud, baglama, setar

    static func forInstrument(_ name: String, stringCount: Int) -> Self? {
        switch (name, stringCount) {
        case ("Erhu", 2): .erhu
        case ("Shamisen", 3): .shamisen
        case ("Oud · Arabic", 6): .arabicOud
        case ("Oud · Turkish", 6): .turkishOud
        case ("Bağlama", 3): .baglama
        case ("Setar", 4): .setar
        default: nil
        }
    }

    private var transform: CGAffineTransform {
        switch self {
        case .erhu: CGAffineTransform(a: 0.88, b: 0, c: 0, d: 0.88, tx: 76, ty: 12)
        case .shamisen, .baglama, .setar: .identity
        case .arabicOud, .turkishOud: CGAffineTransform(a: 0.81, b: 0, c: 0, d: 0.81, tx: 78, ty: 12)
        }
    }

    var isHeadless: Bool { false }
    var stringHitHeight: CGFloat { 44 }
    func stringNumber(at index: Int, count: Int) -> Int {
        switch self {
        case .arabicOud, .turkishOud, .baglama, .setar: count - index
        case .erhu, .shamisen: index + 1
        }
    }
    func pitch(inCourse course: Int, wire: Int, base: Int) -> Int {
        self == .baglama ? base + TunerSolidPegHeadstock.baglamaOffsets[course][wire] : base
    }

    private static let erhuPegs: [(y: CGFloat, windingX: CGFloat)] = [(99, 189), (183, 197)]

    private struct ShamisenPeg {
        let y: CGFloat
        let windingX: CGFloat
        let stringX: CGFloat
        let left: Bool
        let slope: CGFloat

        var axis: TunerPegAxis { TunerPegAxis(origin: CGPoint(x: windingX, y: y), slope: slope) }
    }

    // Tsugaru front view. The thick, middle and thin strings wind top to bottom.
    private static let shamisenPegs: [ShamisenPeg] = [
        .init(y: 102, windingX: 167, stringX: 167, left: false, slope: -0.125),
        .init(y: 138, windingX: 177, stringX: 180, left: true, slope: 0),
        .init(y: 174, windingX: 188, stringX: 193, left: false, slope: 0.12)
    ]

    var positions: [TunerHeadstock.StringPosition] {
        switch self {
        case .erhu:
            Self.erhuPegs.map { peg in
                position(post: (peg.windingX, peg.y), at: (66, peg.y), labelX: 78, left: true)
            }
        case .shamisen:
            Self.shamisenPegs.map { peg in
                let key = peg.axis.point(at: peg.left ? 109 : 251)
                return position(post: (peg.windingX, peg.y), at: (key.x, key.y),
                         labelX: peg.left ? 38 : 322, left: peg.left)
            }
        case .baglama: TunerSolidPegHeadstock.baglama.positions
        case .setar: TunerSolidPegHeadstock.setar.positions
        case .arabicOud, .turkishOud:
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
        switch self {
        case .arabicOud, .turkishOud: Self.oudCourses.map { $0.map { point($0.key, $0.y) } }
        case .baglama: TunerSolidPegHeadstock.baglama.keys
        case .erhu, .shamisen, .setar: positions.map { [$0.key] }
        }
    }

    func middleEasternPickerIcon(_ p: InstrumentPalette, selected: Bool) -> some View {
        Canvas { context, size in
            let ink = selected ? Color(hex: 0xF5F0E2) : p.ink
            let frame = CGRect(x: size.width / 2 - 15, y: size.height / 2 - 15, width: 30, height: 30)
            var drawing = context
            drawing.translateBy(x: frame.minX, y: frame.minY)
            let saz = self == .baglama
            let solid = saz || self == .setar
            let path = Path(tunerCommands: solid ? """
                M 12 29 L 12 5 Q 12 1 15 1 Q 18 1 18 5 L 18 29 Z M 12 23 L 18 23 M 12 26 L 18 26
                """ : """
                M 10 29 L 10 24 C 10 17 13 6 13 4
                Q 13 1 15 1 Q 17 1 17 4 C 17 6 20 17 20 24 L 20 29 Z
                M 13 23 Q 12 21 15 6 Q 18 21 17 23 Z M 10 24 L 20 24
                """)
            drawing.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            let count = self == .setar ? 4 : saz ? 7 : 11
            let pegSpacing: CGFloat = self == .setar ? 4.8 : saz ? 2.55 : 1.58
            for index in 0..<count {
                let left = index.isMultiple(of: 2) != saz
                let y = 6 + CGFloat(index) * pegSpacing
                let x = solid ? 12 : 13 - (y - 6) * 0.17
                let start = left ? x : 30 - x
                let end = left ? 6.2 : 23.8
                let key = Path { path in
                    path.move(to: CGPoint(x: start, y: y))
                    path.addLine(to: CGPoint(x: end, y: y))
                    path.addEllipse(in: CGRect(x: left ? end - 2 : end, y: y - 0.8, width: 2, height: 1.6))
                }
                drawing.stroke(key, with: .color(ink), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
            }
        }.frame(width: 36, height: 32)
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
        case .shamisen: drawShamisen(in: context, surface: surface, drawing: drawing)
        case .arabicOud, .turkishOud: drawOud(in: context, surface: surface, drawing: drawing)
        case .baglama: TunerSolidPegHeadstock.baglama.draw(in: context, surface: surface, drawing: drawing, ranges: wireRanges)
        case .setar: TunerSolidPegHeadstock.setar.draw(in: context, surface: surface, drawing: drawing, ranges: wireRanges)
        }
    }

    private func stroke(_ commands: String, in context: GraphicsContext, color: Color, width: CGFloat = 1.35,
                        fill: Color? = nil, placement: CGAffineTransform = .identity) {
        let path = Path(tunerCommands: commands).applying(placement).applying(transform)
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

    private func drawShamisen(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        stroke("""
            M 159 284 L 159 238 C 154 229 150 217 147 206 Q 146 202 149 198
            L 155 188 L 155 81 L 143 75 L 143 48 Q 143 45 146 43
            C 166 28 194 28 214 43 Q 217 45 217 48 L 217 75 L 205 81 L 205 188
            L 211 198 Q 214 202 213 206 C 210 217 206 229 201 238 L 201 284 Z
            M 163 73 L 197 73 L 197 188 L 163 188 Z
            M 143 72 L 155 72 M 205 72 L 217 72
            """, in: context, color: ink)
        stroke("M 158 188 L 202 188 Q 204 188 204 190 Q 204 192 202 192 L 158 192 Q 156 192 156 190 Q 156 188 158 188 Z",
               in: context, color: ink, width: 1.0, fill: surface)

        let pegs = Self.shamisenPegs
        for index in drawing.paintOrder(pegs.indices) {
            let peg = pegs[index]
            let color = drawing.color(for: index)
            let grip = peg.axis.placement(from: peg.left ? 360 : 0, direction: peg.left ? -1 : 1)
            stroke("""
                M 205 -4 Q 214 -4 222 -8 L 290 -11 Q 293 -11 294 -9
                L 297 -6 L 297 6 L 294 9 Q 293 11 290 11
                L 222 8 Q 214 4 205 4
                M 224 -3 L 296 -5 M 155 -5 Q 150 -5 150 -2 L 150 2 Q 150 5 155 5
                M 210 -4 L 210 4
                """, in: context, color: color, width: 1.15, placement: grip)
            stroke("M 163 -4 L 197 -4 M 163 4 L 197 4",
                   in: context, color: color, width: 0.78, placement: peg.axis.placement(from: 0))
        }
        // The strings pass in front of the lower shafts and leave the winding at its lower edge.
        for index in drawing.paintOrder(pegs.indices) {
            let peg = pegs[index]
            let x = peg.windingX, stringX = peg.stringX
            let color = drawing.color(for: index)
            stroke("""
                M 1.7 -4 C 0.3 -2 -0.7 2 0 4
                M 5 -4 C 3.6 -2 2.6 2 3.3 4
                """, in: context, color: color, width: 0.86, placement: peg.axis.placement(from: x))
            stroke("M \(x) \(peg.y + 4) L \(stringX) 190 L \(stringX) 284",
                   in: context, color: color,
                   width: drawing.lineWidth(for: index, normal: 1.03 - CGFloat(index) * 0.15, focused: 1.75))
            drawing.drawContacts([point(stringX, 190)], for: index, in: context, diameter: 1.8)
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

    // Six low-to-high courses. The middle pair straddles the pegbox at the tip.
    private static let oudCourses: [[OudPeg]] = [
        [.init(31, 273, 87, 85)],
        [.init(35, 229, 95, 96), .init(39, 185, 100, 102)],
        [.init(43, 141, 104, 112), .init(47, 97, 110, 118)],
        [.init(51, 53, 118, 128), .init(202, 75, 134, 134)],
        [.init(207, 119, 144, 144), .init(212, 163, 150, 150)],
        [.init(217, 207, 156, 160), .init(222, 251, 162, 166)]
    ]

    private func drawOud(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let turkish = self == .turkishOud
        let contour = turkish ? """
            M 73 366 L 73 309 C 70 232 90 153 94 84 L 95 40
            C 95 17 106 9 127 9 C 148 9 158 17 158 40 L 159 84
            C 163 153 183 232 180 309 L 180 366 Z
            """ : """
            M 73 366 L 73 309 C 70 237 89 152 95 81 L 97 25
            Q 98 12 111 11 L 141 11 Q 154 12 155 25 L 157 81
            C 163 152 182 237 179 309 L 179 366 Z
            """
        let channel = """
            M 83 309 C 80 232 99 153 103 86 L 105 45
            Q 105 35 115 34 L 137 34 Q 147 35 147 45 L 149 86
            C 153 153 172 232 169 309
            """
        var outside = context
        outside.clip(to: Path(tunerCommands: contour).applying(transform), options: .inverse)
        var inside = context
        inside.clip(to: Path(tunerCommands: channel + " Z").applying(transform))
        stroke(contour, in: context, color: ink)
        stroke(channel, in: context, color: ink.opacity(0.78), width: 0.88)
        stroke("M 73 309 L 179 309 M 73 317 L 179 317", in: context, color: ink, width: 1.05)

        let pegs = Self.oudCourses.flatMap { $0 }
        let gauges = Self.oudCourses.enumerated().flatMap { index, course in
            Array(repeating: 1.12 - 0.08 * CGFloat(index), count: course.count)
        }
        let arabicGrip = Path(tunerCommands: """
            M -11 -3 Q -7 -4 -6 -8 C -2 -12 10 -12 13 -6 Q 16 0 13 6
            C 10 12 -2 12 -6 8 Q -7 4 -11 3 Z
            """)
        let turkishGrip = Path(tunerCommands: """
            M -12 -2 C -8 -2 -6 -10 2 -11 C 9 -12 14 -6 14 0
            C 14 6 9 12 2 11 C -6 10 -8 2 -12 2 Z
            """)
        for (course, wires) in zip(Self.oudCourses, wireRanges) {
            for (peg, index) in zip(course, wires) {
                let color = drawing.color(for: index)
                let edge = peg.key + (peg.left ? 11 : -11)
                let shaft = """
                    M \(edge) \(peg.y - 2.25) L \(peg.winding) \(peg.y - 2.25)
                    M \(edge) \(peg.y + 2.25) L \(peg.winding) \(peg.y + 2.25)
                    """
                stroke(shaft, in: outside, color: color, width: 0.84)
                let engaged = drawing.active == index || drawing.completed.contains(index)
                stroke("M 76 \(peg.y - 2.25) L 176 \(peg.y - 2.25) M 76 \(peg.y + 2.25) L 176 \(peg.y + 2.25)",
                       in: inside, color: color.opacity(engaged ? 0.90 : 0.40), width: 0.59)
                var key = context
                let center = point(peg.key, peg.y)
                key.translateBy(x: center.x, y: center.y)
                key.scaleBy(x: peg.left ? -1 : 1, y: 1)
                let path = turkish ? turkishGrip : arabicGrip
                key.fill(path, with: .color(surface))
                key.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.17, lineJoin: .round))
            }
            if course.count == 2, course[0].left == course[1].left {
                let left = course[0].left
                let x = left ? min(course[0].key, course[1].key) - 23 : max(course[0].key, course[1].key) + 23
                let cap = x + (left ? 3 : -3)
                let top = min(course[0].y, course[1].y), bottom = max(course[0].y, course[1].y)
                stroke("M \(cap) \(top) L \(x) \(top) L \(x) \(bottom) L \(cap) \(bottom)",
                       in: context, color: drawing.color(for: wires).opacity(0.63), width: 0.8)
            }
        }
        // The rails and shafts remain behind the strings regardless of the active wire.
        for index in drawing.paintOrder(pegs.indices) {
            let peg = pegs[index], x = peg.winding, y = peg.y
            let turn: CGFloat = peg.left ? -1 : 1
            let color = drawing.color(for: index)
            stroke("""
                M \(x + turn) \(y - 2.25) Q \(x + turn * 3) \(y) \(x) \(y + 2.25)
                L \(peg.nut) 309 L \(peg.nut) 366
                """, in: context, color: color,
                   width: drawing.lineWidth(for: index, normal: gauges[index], focused: 1.7))
            stroke("""
                M \(x + turn * 3.2) \(y - 2.25)
                Q \(x + turn * 5.2) \(y) \(x + turn * 2.2) \(y + 2.25)
                """, in: inside, color: color, width: 0.68)
            drawing.drawContacts([point(peg.nut, 309), point(peg.nut, 317)], for: index, in: context, diameter: 1.9)
        }
    }
}
