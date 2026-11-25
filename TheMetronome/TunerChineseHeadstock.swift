import SwiftUI

enum TunerChineseHeadstock: String, TunerHeadstockDrawing {
    case morinKhuur = "Morin khuur"
    case liuqin = "Liuqin"
    case sanxian = "Large sanxian"
    case dombra = "Dombra"
    case gaohu = "Gaohu"
    case zhonghu = "Zhonghu"

    static func forInstrument(_ name: String, stringCount: Int) -> Self? {
        guard let layout = Self(rawValue: name), layout.pegs.count == stringCount else { return nil }
        return layout
    }

    private struct Peg {
        let keyX: CGFloat
        let axis: TunerPegAxis
        let stringX: CGFloat
        let left: Bool

        var key: CGPoint { axis.point(at: keyX) }
        var attachment: CGPoint { axis.origin }

        init(keyX: CGFloat, y: CGFloat, attachmentX: CGFloat, stringX: CGFloat, left: Bool = false,
             slope: CGFloat = 0) {
            self.keyX = keyX
            self.axis = TunerPegAxis(origin: CGPoint(x: attachmentX, y: y), slope: slope)
            self.stringX = stringX
            self.left = left
        }
    }

    private var pegs: [Peg] {
        switch self {
        case .morinKhuur:
            // Audience-facing. The thick low string is on the right.
            [.init(keyX: 259, y: 134, attachmentX: 188, stringX: 185),
             .init(keyX: 100, y: 163, attachmentX: 170, stringX: 175, left: true)]
        case .liuqin:
            // The four strings stay in the same order through the nut.
            [.init(keyX: 100, y: 177, attachmentX: 165, stringX: 165, left: true, slope: 0.16),
             .init(keyX: 100, y: 113, attachmentX: 175, stringX: 175, left: true, slope: 0.14),
             .init(keyX: 260, y: 144, attachmentX: 185, stringX: 185, slope: 0.15),
             .init(keyX: 260, y: 208, attachmentX: 195, stringX: 195, slope: 0.15)]
        case .sanxian:
            [.init(keyX: 100, y: 117, attachmentX: 170, stringX: 170, left: true, slope: -0.10),
             .init(keyX: 260, y: 78, attachmentX: 180, stringX: 180, slope: -0.15),
             .init(keyX: 260, y: 159, attachmentX: 190, stringX: 190, slope: 0.13)]
        case .dombra:
            [.init(keyX: 162, y: 56, attachmentX: 162, stringX: 162, left: true),
             .init(keyX: 198, y: 139, attachmentX: 198, stringX: 195)]
        case .gaohu:
            [.init(keyX: 249, y: 111, attachmentX: 117, stringX: 133),
             .init(keyX: 249, y: 164, attachmentX: 117, stringX: 137)]
        case .zhonghu:
            [.init(keyX: 250, y: 118, attachmentX: 116, stringX: 129),
             .init(keyX: 250, y: 180, attachmentX: 116, stringX: 134)]
        }
    }

    private static let capRadius: CGFloat = 9

    var isHeadless: Bool { false }
    var stringHitHeight: CGFloat { 44 }

    func stringNumber(at index: Int, count: Int) -> Int {
        isHuqin ? index + 1 : count - index
    }

    var positions: [TunerHeadstock.StringPosition] {
        pegs.map { peg in
            let labelInset: CGFloat = self == .dombra ? 91 : 36
            return .init(post: peg.attachment, key: peg.key, nutX: peg.stringX,
                         label: CGPoint(x: peg.left ? labelInset : 360 - labelInset, y: peg.key.y),
                         left: peg.left)
        }
    }

    var referenceWires: [Path] { pegs.map(string(for:)) }

    private var isHuqin: Bool { self == .gaohu || self == .zhonghu }

    private var neckEnd: CGFloat {
        switch self {
        case .morinKhuur: 304
        case .liuqin: 315
        case .sanxian: 309
        case .dombra: 308
        case .gaohu, .zhonghu: 297
        }
    }

    private var stringGuide: CGFloat {
        switch self {
        case .morinKhuur: 267
        case .liuqin: 247
        case .sanxian: 230
        case .dombra: 202
        case .gaohu: 282
        case .zhonghu: 284
        }
    }

    private var outline: Path {
        switch self {
        case .morinKhuur:
            Path(tunerCommands: """
                M 165 304 L 165 213 C 165 190 158 171 158 149
                L 158 114 Q 155 106 154 95 C 153 83 150 75 151 62
                Q 150 51 157 41 Q 151 28 154 14 Q 156 9 160 15 L 171 31
                Q 180 27 189 31 L 200 15 Q 204 9 206 14 Q 209 29 202 41
                Q 210 49 209 61 C 210 73 205 84 205 95
                Q 205 107 202 114 L 202 149 C 202 171 195 190 195 213
                L 195 304 Z
                """)
        case .liuqin:
            Path(tunerCommands: """
                M 148 315 L 153 251 L 153 243 L 158 101
                C 154 96 147 96 144 89 Q 142 84 138 81
                C 132 77 131 68 135 62 Q 139 59 140 53 Q 141 47 150 43
                L 144 18 Q 143 14 147 16 Q 164 25 178 10 Q 180 7 183 10
                Q 196 24 213 16 Q 217 14 216 19 L 210 43
                Q 219 47 220 53 Q 221 59 225 62 C 229 68 228 77 222 81
                Q 218 84 216 89 C 213 96 206 96 202 101
                L 207 243 L 207 251 L 212 315 Z
                """)
        case .sanxian:
            Path(tunerCommands: """
                M 163 309 L 163 235 Q 150 230 149 214 L 149 190
                Q 149 187 152 187 L 160 187 L 160 62
                L 137 53 Q 134 52 134 48 C 133 32 125 20 116 18
                Q 111 17 111 14 Q 111 10 116 10 L 244 10 Q 249 10 249 14
                Q 249 17 244 18 C 235 20 227 32 226 48 Q 226 52 223 53
                L 200 62 L 200 187 L 208 187 Q 211 187 211 190
                L 211 214 Q 210 230 197 235 L 197 309 Z
                """)
        case .dombra:
            Path(tunerCommands: """
                M 155 308 L 155 208 L 151 204 L 151 199 C 149 185 141 171 133 153
                C 118 130 121 111 125 92 C 129 73 131 60 122 45
                C 112 25 122 13 140 12 C 161 7 179 16 196 23
                C 210 29 228 28 237 37 C 248 47 246 62 239 76
                C 231 92 233 105 236 123 C 240 148 228 167 215 184
                Q 209 194 209 199 L 209 204 L 205 208 L 205 308 Z
                """)
        case .gaohu:
            Path(tunerCommands: """
                M 160 297 L 160 71 C 160 42 175 28 199 14
                Q 204 10 207 12 Q 226 21 235 34 Q 237 38 232 38
                Q 215 36 206 34 C 186 41 178 56 178 72 L 178 297 Z
                """)
        case .zhonghu:
            Path(tunerCommands: """
                M 158 297 L 158 216 Q 158 210 154 203 L 154 88 L 158 82
                C 158 50 169 26 194 13 Q 201 8 207 12
                Q 220 17 225 26 Q 227 31 222 32 L 205 30
                C 185 43 179 61 179 82 L 183 88 L 183 203
                Q 179 211 179 216 L 179 297 Z
                """)
        }
    }

    private var details: Path {
        switch self {
        case .morinKhuur:
            Path(tunerCommands: """
                M 159 42 Q 180 28 201 42
                M 155 67 Q 159 62 166 65 M 194 65 Q 201 62 205 67
                M 172 58 Q 170 79 165 86 Q 161 92 164 102
                C 166 116 194 116 196 102 Q 199 92 195 86 Q 190 79 188 58
                M 170 99 Q 174 96 177 99 M 183 99 Q 186 96 190 99
                M 162 194 Q 180 200 198 194
                M 165 264 L 195 264 L 195 270 L 165 270 Z
                """)
        case .liuqin:
            Path(tunerCommands: """
                M 150 43 Q 158 43 163 38 Q 173 31 180 32 Q 187 31 197 38 Q 202 43 210 43
                M 158 101 Q 168 110 180 110 Q 192 110 202 101
                M 164 107 L 159 243 M 196 107 L 201 243
                M 154 243 L 206 243 L 206 251 L 154 251 Z
                M 151 288 L 209 288
                """)
        case .sanxian:
            Path(tunerCommands: """
                M 164 225 L 165 68 Q 165 63 170 63 L 190 63 Q 195 63 195 68 L 196 225
                M 156 226 L 204 226 L 204 232 L 156 232 Z
                """)
        case .dombra:
            Path(tunerCommands: """
                M 151 199 Q 180 196 209 199 L 209 204 Q 180 202 151 204 Z
                M 155 208 L 205 208 M 155 282 L 205 282
                """)
        case .gaohu:
            Path(tunerCommands: "M 198 15 Q 205 21 213 34 M 129 279 L 178 279 L 178 285 L 129 285 Z")
        case .zhonghu:
            Path(tunerCommands: "M 193 14 Q 200 20 209 30 M 126 281 L 179 281 L 179 287 L 126 287 Z")
        }
    }

    func draw(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        render(in: context, ink: drawing.outline, drawing: drawing)
    }

    func pickerIcon(_ palette: InstrumentPalette, selected: Bool) -> some View {
        Canvas { canvas, size in
            let scale = size.height / 325
            var context = canvas
            context.translateBy(x: (size.width - 360 * scale) / 2, y: 0)
            context.scaleBy(x: scale, y: scale)
            let ink = selected ? Color(hex: 0xF5F0E2) : palette.ink
            render(in: context, ink: ink)
        }
        .frame(width: 35, height: 32)
    }

    private func render(in context: GraphicsContext, ink: Color, drawing: TunerStringDrawing? = nil) {
        func stroke(_ path: Path, _ color: Color, _ width: CGFloat, in canvas: GraphicsContext? = nil) {
            (canvas ?? context).stroke(path, with: .color(color),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }

        let picker = drawing == nil
        let width: CGFloat = picker ? 6.25 : 1.45
        let frame = outline
        let pegs = self.pegs
        var outside = context
        outside.clip(to: frame, options: .inverse)

        stroke(frame, ink, width)
        if !picker { stroke(details, ink, 0.9) }

        // Draw all rollers before all strings. Completing a different string
        // should change its ink, never which neighboring wire is visible.
        for (index, peg) in pegs.enumerated() {
            let color = drawing?.color(for: index) ?? ink
            if self == .dombra {
                let radius = Self.capRadius
                let cap = CGRect(x: peg.attachment.x - radius, y: peg.attachment.y - radius,
                                 width: 2 * radius, height: 2 * radius)
                stroke(Path(ellipseIn: cap), color, picker ? 5 : 1.3)
            } else {
                stroke(handle(for: peg, picker: picker), color, width, in: outside)
            }
            if !picker {
                let shaftColor = drawing?.active == index || drawing?.completed.contains(index) == true ? color
                    : color.opacity(isHuqin ? 0.86 : 0.63)
                stroke(exposedShaft(for: peg), shaftColor, 0.88)
            }
        }
        if let drawing {
            for index in drawing.paintOrder(pegs.indices) {
                let strokeWidth = drawing.lineWidth(for: index, normal: 1.04 - CGFloat(index) * 0.07, focused: 1.64)
                stroke(string(for: pegs[index]), drawing.color(for: index), strokeWidth)
            }
        }
    }

    private func handle(for peg: Peg, picker: Bool) -> Path {
        // Bent-head handles are rounded turned wood. The two open-box lutes use a
        // more tapered grip, represented without spirals or carved decoration.
        let body: String
        switch self {
        case .morinKhuur:
            body = """
                M 197 -4 L 218 -4 Q 224 -4 231 -7 C 246 -11 265 -12 279 -10
                Q 291 -8 292 0 Q 291 8 279 10 C 265 12 246 11 231 7
                Q 224 4 218 4 L 197 4 Z
                """
        case .liuqin:
            body = """
                M 192 -4 L 213 -4 C 232 -6 258 -12 278 -14
                Q 292 -16 292 0 Q 292 16 278 14 C 258 12 232 6 213 4 L 192 4 Z
                """
        case .sanxian:
            body = """
                M 192 -4 L 211 -4 Q 230 -6 245 -8 L 277 -11
                Q 287 -12 290 -7 Q 294 0 290 7 Q 287 12 277 11
                L 245 8 Q 230 6 211 4 L 192 4 Z
                """
        case .gaohu:
            body = """
                M 171 -3 L 192 -3 C 214 -4 246 -11 265 -11 Q 281 -11 282 0
                Q 281 11 265 11 C 246 11 214 4 192 3 L 171 3 Z
                """
        case .zhonghu:
            body = """
                M 176 -3.5 L 196 -3.5 C 214 -6 243 -13 263 -14 Q 287 -14 287 0
                Q 287 14 263 14 C 243 13 214 6 196 3.5 L 176 3.5 Z
                """
        case .dombra:
            return Path()
        }

        let placement = peg.axis.placement(from: peg.left ? 360 : 0, direction: peg.left ? -1 : 1)
        var path = Path(tunerCommands: body)
        if !picker {
            let end: CGFloat = self == .gaohu ? 274 : 282
            path.addPath(Path(tunerCommands: "M \(end) -8 Q \(end + 4) 0 \(end) 8"))
        }
        return path.applying(placement)
    }

    private func exposedShaft(for peg: Peg) -> Path {
        let y = peg.key.y
        switch self {
        case .liuqin, .sanxian:
            let left = self == .liuqin ? 164 - (y - 107) * 5 / 136 : 165
            return Path { path in
                for offset: CGFloat in [-3, 3] {
                    path.move(to: peg.axis.point(at: left, offset: offset))
                    path.addLine(to: peg.axis.point(at: 360 - left, offset: offset))
                }
            }
        case .gaohu, .zhonghu:
            let x = peg.attachment.x
            let edge: CGFloat = self == .gaohu ? 160 : 154
            return Path(tunerCommands: """
                M \(edge) \(y - 3) L \(x) \(y - 3) Q \(x - 3) \(y) \(x) \(y + 3) L \(edge) \(y + 3)
                """)
        case .morinKhuur, .dombra:
            return Path()
        }
    }

    private func string(for peg: Peg) -> Path {
        Path { path in
            let x = peg.stringX
            path.move(to: CGPoint(x: x, y: neckEnd))
            path.addLine(to: CGPoint(x: x, y: stringGuide))

            switch self {
            case .liuqin, .sanxian:
                path.addLine(to: peg.axis.point(at: x, offset: 3))
                // One visible turn, exactly the height of the roller.
                path.addQuadCurve(to: peg.axis.point(at: x + 1.5, offset: -3),
                                  control: peg.axis.point(at: x - 2.3, offset: -1))
            case .dombra:
                let dx = x - peg.attachment.x
                let radius = Self.capRadius
                let capY = peg.attachment.y + (radius * radius - dx * dx).squareRoot()
                path.addLine(to: CGPoint(x: x, y: capY))
            case .morinKhuur:
                // The wood face covers the pegs and winding.
                path.addLine(to: CGPoint(x: x, y: 197))
            case .gaohu, .zhonghu:
                let start = peg.attachment
                let x = start.x + (peg.stringX - (self == .gaohu ? 131 : 127)) * 1.55
                path.addLine(to: CGPoint(x: x, y: start.y + 3))
                path.addQuadCurve(to: CGPoint(x: x, y: start.y - 3),
                                  control: CGPoint(x: x + 3.2, y: start.y))
            }
        }
    }
}
