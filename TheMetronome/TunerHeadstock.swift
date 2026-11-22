import SwiftUI

protocol TunerHeadstockDrawing {
    var positions: [TunerHeadstock.StringPosition] { get }
    var isHeadless: Bool { get }
    var stringHitHeight: CGFloat { get }
    var courseKeys: [[CGPoint]] { get }
    func stringNumber(at index: Int, count: Int) -> Int
    func draw(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing)
}

extension TunerHeadstockDrawing {
    var courseKeys: [[CGPoint]] { positions.map { [$0.key] } }
    var wireRanges: [Range<Int>] {
        var next = 0
        return courseKeys.map {
            let first = next
            next += $0.count
            return first..<next
        }
    }
    func stringNumber(at index: Int, count: Int) -> Int { count - index }
}

enum TunerHeadstock: String, Hashable, TunerHeadstockDrawing {
    case guitar, inlineGuitar, headlessGuitar, guitarSeven, inlineGuitarSeven, headlessGuitarSeven
    case guitarTwelve, bass, pairedBass, threePlusOneBass, jazzBassFive, ukulele, violin, viola, cello
    case banjo, mandolin, doubleBass, sixStringBass, baritoneUkulele, pipa

    static func standard(for instrument: String) -> Self? {
        switch instrument {
        case "Guitar": .guitar
        case "7-string guitar": .guitarSeven
        case "12-string guitar": .guitarTwelve
        case "Bass": .bass
        case "5-string bass": .jazzBassFive
        case "6-string bass": .sixStringBass
        case "Ukulele": .ukulele
        case "Baritone ukulele": .baritoneUkulele
        case "Violin": .violin
        case "Viola": .viola
        case "Cello": .cello
        case "5-string banjo": .banjo
        case "Mandolin": .mandolin
        case "Double bass": .doubleBass
        case "Pipa": .pipa
        default: nil
        }
    }

    var options: [Self] {
        switch self {
        case .guitar, .inlineGuitar, .headlessGuitar: [.guitar, .inlineGuitar, .headlessGuitar]
        case .guitarSeven, .inlineGuitarSeven, .headlessGuitarSeven: [.guitarSeven, .inlineGuitarSeven, .headlessGuitarSeven]
        case .bass, .pairedBass, .threePlusOneBass: [.bass, .threePlusOneBass, .pairedBass]
        default: []
        }
    }

    var title: String {
        switch self {
        case .guitar: "3 + 3"
        case .inlineGuitar: "6 in line"
        case .guitarSeven: "3 + 4"
        case .inlineGuitarSeven: "7 in line"
        case .guitarTwelve: "6 + 6"
        case .headlessGuitar, .headlessGuitarSeven: "Headless"
        case .bass: "4 in line"
        case .pairedBass: "2 + 2"
        case .threePlusOneBass: "3 + 1"
        case .jazzBassFive: "4 + 1"
        default: ""
        }
    }

    private var nut: CGRect {
        switch self {
        case .guitar: CGRect(x: 143, y: 287, width: 74, height: 7)
        case .inlineGuitar: CGRect(x: 145, y: 297, width: 70, height: 6)
        case .guitarSeven: CGRect(x: 140, y: 281, width: 80, height: 6)
        case .inlineGuitarSeven: CGRect(x: 141, y: 301, width: 78, height: 6)
        case .guitarTwelve: CGRect(x: 132, y: 296, width: 96, height: 6)
        case .headlessGuitar: CGRect(x: 73, y: 157, width: 214, height: 6)
        case .headlessGuitarSeven: CGRect(x: 58, y: 157, width: 244, height: 6)
        case .bass: CGRect(x: 178, y: 278, width: 51, height: 6)
        case .threePlusOneBass: CGRect(x: 153, y: 276, width: 54, height: 6)
        case .jazzBassFive: CGRect(x: 151, y: 285, width: 62, height: 6)
        case .pairedBass: CGRect(x: 146, y: 278, width: 68, height: 6)
        case .sixStringBass: CGRect(x: 130, y: 253, width: 100, height: 7)
        case .baritoneUkulele: CGRect(x: 142, y: 249, width: 76, height: 6)
        case .ukulele: CGRect(x: 152, y: 274, width: 56, height: 6)
        case .banjo: CGRect(x: 154, y: 258, width: 52, height: 6)
        case .mandolin: CGRect(x: 158, y: 275, width: 44, height: 6)
        case .doubleBass: CGRect(x: 137, y: 274, width: 86, height: 8)
        case .pipa: Self.pipaNut
        case .violin, .viola, .cello: CGRect(x: 150, y: 260, width: 59, height: 8)
        }
    }

    private var isUkulele: Bool { self == .ukulele || self == .baritoneUkulele }
    private var neckEnd: CGFloat {
        switch self {
        case .pipa: Self.pipaNeckEnd
        case .ukulele, .baritoneUkulele: 308
        default: 320
        }
    }

    var isHeadless: Bool { self == .headlessGuitar || self == .headlessGuitarSeven }
    private var clampSlant: CGFloat { self == .headlessGuitarSeven ? 0.17 : 0 }
    private var clampPlate: CGRect { CGRect(x: nut.minX + 3, y: 103, width: nut.width - 6, height: 49) }
    private var clampTransform: CGAffineTransform {
        CGAffineTransform(a: 1, b: clampSlant, c: 0, d: 1, tx: 0, ty: -180 * clampSlant)
    }

    var stringHitHeight: CGFloat {
        switch self {
        case .inlineGuitar: 36
        case .inlineGuitarSeven, .guitarTwelve: 40
        case .mandolin: 62
        default: 44
        }
    }

    struct StringPosition {
        let post: CGPoint
        let key: CGPoint
        let nutX: CGFloat
        let label: CGPoint
        let left: Bool
    }

    var positions: [StringPosition] {
        switch self {
        case .guitar:
            return (0..<6).map { index in
                let left = index < 3
                let y = CGFloat(67 + abs(index - (left ? 2 : 3)) * 79)
                return StringPosition(post: CGPoint(x: left ? 140 : 220, y: y),
                                      key: CGPoint(x: left ? 89.5 : 270.5, y: y),
                                      nutX: CGFloat(150 + index * 12),
                                      label: CGPoint(x: left ? 41 : 319, y: y), left: left)
            }
        case .inlineGuitar:
            return (0..<6).map { index in
                let step = CGFloat(index)
                return string(147 + step * 11.55, 237 - step * 36.2, nutX: 151 + step * 11.6,
                              left: true, offset: 35, angle: 18, labelX: 73 + step * 11.55)
            }
        case .guitarSeven:
            return (0..<7).map { index in
                let left = index < 3
                let row = CGFloat(abs(index - (left ? 2 : 3)))
                let post = left ? CGPoint(x: 151 - row * 11, y: 109 + row * 61)
                                : CGPoint(x: 197 + row * 11, y: 72 + row * 49)
                return string(post.x, post.y, nutX: 146 + CGFloat(index) * (68.0 / 6),
                              left: left, offset: left ? 43 : 42, labelX: left ? 42 : 318)
            }
        case .inlineGuitarSeven:
            return (0..<7).map { index in
                let step = CGFloat(index)
                let peg = string(133 + step * 12.5, 279 - step * 40,
                                 nutX: 149 + step * (62.0 / 6), left: true,
                                 offset: 39, angle: 19, labelX: 55 + step * 12.5)
                guard index == 0 else { return peg }
                // The outline turns inward here. Move the post clear of the
                // edge while keeping the machine head aligned with its row.
                return StringPosition(post: CGPoint(x: 141, y: peg.post.y),
                                      key: peg.key, nutX: peg.nutX, label: peg.label, left: peg.left)
            }
        case .guitarTwelve:
            return (0..<12).map { index in
                let left = index < 6
                let row = CGFloat(abs(index - (left ? 5 : 6)))
                let nutX = 136 + CGFloat(index / 2) * 16.6 + CGFloat(index % 2) * 5
                return string(left ? 129 + row * 0.8 : 231 - row * 0.8, 45 + row * 40,
                              nutX: nutX, left: left, offset: 42, labelX: left ? 43 : 317)
            }
        case .headlessGuitar, .headlessGuitarSeven:
            let seven = self == .headlessGuitarSeven
            let count = seven ? 7 : 6
            return (0..<count).map { index in
                let x = (seven ? 78.0 : 90.0) + CGFloat(index) * (seven ? 34 : 36)
                let upper = index.isMultiple(of: 2) != seven
                let post = CGPoint(x: x, y: (upper ? 119 : 141) + (x - 180) * clampSlant)
                return StringPosition(post: post, key: post, nutX: x,
                                      label: CGPoint(x: x, y: 292), left: false)
            }
        case .bass:
            return Self.precisionBassPositions
        case .threePlusOneBass:
            return Self.threePlusOneBassPositions
        case .jazzBassFive:
            let railTop = CGPoint(x: 163, y: 39)
            let railBottom = CGPoint(x: 123, y: 244)
            var pegs = [CGPoint(x: 149, y: 234), CGPoint(x: 162, y: 177),
                        CGPoint(x: 175, y: 117), CGPoint(x: 188, y: 58)]
                .enumerated().map { index, post in
                    Self.bassPeg(post, nutX: 157 + CGFloat(index) * 12.5,
                                 railTop: railTop, railBottom: railBottom, labelX: 49)
                }
            pegs.append(string(215, 207, nutX: 207, left: false, offset: 47, angle: -12, labelX: 317))
            return pegs
        case .pairedBass:
            return [
                string(148, 181, nutX: 154, left: true, offset: 54, labelX: 49),
                string(150, 103, nutX: 171, left: true, offset: 56, labelX: 49),
                string(210, 103, nutX: 189, left: false, offset: 56, labelX: 311),
                string(212, 181, nutX: 206, left: false, offset: 54, labelX: 311)
            ]
        case .sixStringBass:
            return (0..<6).map { index in
                let left = index < 3
                let row = CGFloat(left ? 2 - index : index - 3)
                let x = 146 - row * 9
                return string(left ? x : 360 - x, 81 + row * 58, nutX: 140 + CGFloat(index) * 16,
                              left: left, offset: 44, angle: left ? 9 : -9, labelX: left ? 39 : 321)
            }
        case .baritoneUkulele:
            return [
                string(145, 165, nutX: 153, left: true, offset: 43, labelX: 56),
                string(147, 88, nutX: 170, left: true, offset: 45, labelX: 56),
                string(213, 88, nutX: 190, left: false, offset: 45, labelX: 304),
                string(215, 165, nutX: 207, left: false, offset: 43, labelX: 304)
            ]
        case .ukulele:
            return [
                string(149, 192, nutX: 159, left: true, offset: 39, angle: -4.0, labelX: 65),
                string(144, 105, nutX: 173, left: true, offset: 40, angle: -4.0, labelX: 59),
                string(216, 105, nutX: 187, left: false, offset: 40, angle: 4.0, labelX: 301),
                string(211, 192, nutX: 201, left: false, offset: 39, angle: 4.0, labelX: 295)
            ]
        case .banjo:
            return [
                string(153, 305, nutX: 151, left: true, offset: 38, labelX: 66),
                string(151, 181, nutX: 160, left: true, offset: 45, labelX: 67),
                string(142, 82, nutX: 173, left: true, offset: 46, labelX: 57),
                string(218, 82, nutX: 187, left: false, offset: 46, labelX: 303),
                string(209, 181, nutX: 200, left: false, offset: 45, labelX: 293)
            ]
        case .mandolin:
            return [
                StringPosition(post: CGPoint(x: 155, y: 182), key: CGPoint(x: 124, y: 197),
                               nutX: 163, label: CGPoint(x: 64, y: 197), left: true),
                StringPosition(post: CGPoint(x: 157, y: 104), key: CGPoint(x: 117, y: 121),
                               nutX: 174, label: CGPoint(x: 57, y: 121), left: true),
                StringPosition(post: CGPoint(x: 204, y: 104), key: CGPoint(x: 244, y: 121),
                               nutX: 186, label: CGPoint(x: 304, y: 121), left: false),
                StringPosition(post: CGPoint(x: 206, y: 182), key: CGPoint(x: 238, y: 197),
                               nutX: 197, label: CGPoint(x: 298, y: 197), left: false)
            ]
        case .doubleBass:
            return [
                Self.uprightBassPeg(158, 244, nutX: 150, left: true),
                Self.uprightBassPeg(169, 170, nutX: 169, left: true),
                Self.uprightBassPeg(192, 133, nutX: 191, left: false),
                Self.uprightBassPeg(202, 207, nutX: 209, left: false)
            ]
        case .pipa:
            return pipaPegs.map { peg in
                let zoom = Self.pipaDetailTransform
                let key = peg.key.applying(zoom)
                return StringPosition(post: peg.post.applying(zoom), key: key,
                                      nutX: CGPoint(x: peg.nutX, y: 0).applying(zoom).x,
                                      label: CGPoint(x: peg.left ? 28 : 332, y: key.y), left: peg.left)
            }
        case .violin, .viola, .cello:
            let cello = self == .cello
            let leftLabel = Self.bowedLabelInset
            // From the front: two lower strings on the left, two higher strings on the right.
            return [
                string(161, 226, nutX: 159, left: true, offset: cello ? 63 : 73, labelX: leftLabel),
                string(169, 154, nutX: 171, left: true, offset: cello ? 72 : 77, labelX: leftLabel),
                string(189, 126, nutX: 184, left: false, offset: cello ? 69 : 76, labelX: 360 - leftLabel),
                string(196, 190, nutX: 196, left: false, offset: cello ? 61 : 68, labelX: 360 - leftLabel)
            ]
        }
    }

    private func string(_ x: CGFloat, _ y: CGFloat, nutX: CGFloat, left: Bool,
                        offset: CGFloat, angle: CGFloat = 0, labelX: CGFloat) -> StringPosition {
        let radians = angle * .pi / 180
        let distance = left ? -offset : offset
        let key = CGPoint(x: x + distance * cos(radians), y: y + distance * sin(radians))
        return StringPosition(post: CGPoint(x: x, y: y), key: key,
                              nutX: nutX, label: CGPoint(x: labelX, y: key.y), left: left)
    }

    private func mandolinPegs(for course: StringPosition) -> [StringPosition] {
        [-1.0, 1.0].map { row in
            let dy = CGFloat(row) * 19
            let side: CGFloat = course.left ? -1 : 1
            return StringPosition(post: CGPoint(x: course.post.x, y: course.post.y + dy),
                                  key: CGPoint(x: course.key.x, y: course.key.y + dy),
                                  nutX: course.nutX + CGFloat(row) * side * 2.1,
                                  label: course.label, left: course.left)
        }
    }

    var courseKeys: [[CGPoint]] {
        positions.map { position in
            (self == .mandolin ? mandolinPegs(for: position) : [position]).map(\.key)
        }
    }

    private var outline: String {
        switch self {
        case .guitar:
            "M 143 320 L 143 290 Q 139 271 122 240 L 112 32 Q 180 -22 248 32 L 238 240 Q 222 270 217 290 L 217 320 Z"
        case .inlineGuitar:
            """
            M 145 320 L 145 297
            C 145 284 140 277 129 268 C 123 263 119 257 123 249
            L 187 48 C 194 26 208 13 228 13
            C 252 13 270 31 270 50 C 270 65 262 76 247 85
            C 234 92 232 98 233 108
            C 234 136 245 154 251 183 C 255 200 258 216 255 225
            C 252 229 246 231 240 235
            C 224 246 215 266 215 297 L 215 320 Z
            """
        case .guitarSeven:
            """
            M 140 320 L 140 281 C 140 263 127 252 112 244
            Q 105 240 108 231 C 129 185 135 128 135 54
            Q 135 50 139 50 C 177 49 193 16 218 12
            Q 222 11 222 16 C 223 109 227 179 253 229
            Q 258 238 251 242 C 232 252 220 264 220 281 L 220 320 Z
            """
        case .inlineGuitarSeven:
            """
            M 141 320 L 141 301 C 141 285 121 283 115 273
            Q 111 267 114 260 L 187 28
            Q 189 21 195 23 C 211 31 226 13 241 8 Q 246 6 245 13
            C 234 112 231 200 246 247 Q 249 257 241 263
            C 225 277 219 287 219 301 L 219 320 Z
            """
        case .guitarTwelve:
            """
            M 132 320 L 132 296 C 132 280 127 270 119 259
            Q 115 254 115 247 L 107 34
            Q 107 30 111 30 Q 137 24 155 9 Q 157 7 160 8
            Q 180 12 200 8 Q 203 7 205 9 Q 223 24 249 30
            Q 253 30 253 34 L 245 247 Q 245 254 241 259
            C 233 270 228 280 228 296 L 228 320 Z
            """
        case .headlessGuitar:
            "M 73 261 L 73 164 L 61 154 L 68 68 C 132 39 211 119 290 82 L 299 150 L 287 163 L 287 261 Z"
        case .headlessGuitarSeven:
            "M 58 261 L 58 142 L 45 134 L 52 59 C 124 37 221 117 303 91 L 313 174 L 302 183 L 302 261 Z"
        case .bass:
            """
            M 178 314 L 178 279
            C 175 263 169 254 154 248
            C 143 242 147 232 \(Self.bassRailBottom.x) \(Self.bassRailBottom.y)
            L \(Self.bassRailTop.x) \(Self.bassRailTop.y)
            C 194 17 209 6 227 6
            C 250 6 265 26 265 46
            C 266 63 258 71 248 79
            C 227 97 240 127 249 155
            C 259 183 264 207 261 227
            C 260 232 247 233 238 247
            C 231 258 229 267 229 279
            L 229 314 Z
            """
        case .threePlusOneBass:
            """
            M 153 320 L 153 265
            C 152 247 133 238 124 226
            C 117 216 120 203 \(Self.threePlusOneRailBottom.x) \(Self.threePlusOneRailBottom.y)
            L \(Self.threePlusOneRailTop.x) \(Self.threePlusOneRailTop.y)
            C 175 25 186 11 205 11
            C 223 10 241 21 249 41
            C 253 50 249 53 243 58
            C 226 73 223 95 227 117
            C 231 143 237 166 241 189
            C 244 209 243 217 233 226
            C 218 237 208 247 207 265
            L 207 320 Z
            """
        case .jazzBassFive:
            """
            M 151 320 L 151 290
            C 149 274 138 271 126 261 Q 120 256 123 244
            L 163 39 C 169 18 183 7 202 7
            C 223 6 243 23 244 41 C 245 61 236 74 223 82
            C 211 89 210 101 213 118 C 217 145 233 176 239 207
            Q 242 221 241 230 C 225 245 213 259 213 290
            L 213 320 Z
            """
        case .pairedBass:
            // The Höfner crest rises to the right above the two paired rows.
            """
            M 146 320 L 146 278
            C 144 251 135 234 123 219 Q 120 216 122 208
            C 126 180 131 146 129 117 C 128 84 123 59 117 35
            Q 115 29 121 32
            C 149 43 177 37 198 20 C 215 6 233 2 243 13
            Q 246 15 244 21
            C 238 45 231 83 230 118 C 229 148 233 183 238 208
            Q 240 216 236 219 C 224 234 216 251 214 278
            L 214 320 Z
            """
        case .sixStringBass:
            // Profile traced from the generated straight-on six-string bass reference.
            """
            M 130 320 L 130 255 C 126 238 120 225 106 216
            Q 99 211 102 199 C 110 161 125 110 124 79
            C 124 65 120 57 116 46 Q 109 34 122 30
            C 145 25 156 24 174 13 Q 180 9 186 13 C 204 24 215 25 238 30
            Q 251 34 244 46 C 240 57 236 65 236 79
            C 235 110 250 161 258 199 Q 261 211 254 216
            C 240 225 234 238 230 255 L 230 320 Z
            """
        case .baritoneUkulele:
            """
            M 142 308 L 142 251 C 142 224 128 206 123 193
            Q 121 188 122 180 C 126 134 124 82 118 40
            Q 118 37 122 35 C 145 20 162 15 180 15 C 198 15 215 20 238 35
            Q 242 37 242 40 C 236 82 234 134 238 180
            Q 239 188 237 193 C 232 206 218 224 218 251 L 218 308 Z
            """
        case .ukulele:
            """
            M 152 308 L 152 276
            C 152 250 148 235 136 224 Q 130 218 130 205
            L 120 66 Q 120 58 127 57
            C 149 57 167 53 180 46
            C 193 53 211 57 233 57 Q 240 58 240 66
            L 230 205 Q 230 218 224 224
            C 212 235 208 250 208 276 L 208 308 Z
            """
        case .banjo:
            """
            M 145 320 L 145 301 Q 145 296 154 291 L 154 258
            C 153 245 150 231 141 224
            C 152 211 118 209 123 174 Q 124 172 129 171
            C 151 168 151 143 129 124 Q 126 122 129 118
            C 138 106 129 96 109 98 Q 106 98 108 92
            C 120 58 141 56 144 37 Q 145 34 149 34
            C 162 36 171 22 178 14 Q 180 11 182 14
            C 189 22 198 36 211 34 Q 215 34 216 37
            C 219 56 240 58 252 92 Q 254 98 251 98
            C 231 96 222 106 231 118 Q 234 122 231 124
            C 209 143 209 168 231 171 Q 236 172 237 174
            C 242 209 208 211 219 224
            C 210 231 207 245 206 258 L 206 320 Z
            """
        case .mandolin:
            // Traced from the front-facing 1923 F-5. Both scroll openings
            // run continuously to the outside of the peghead.
            """
            M 158 320 L 158 275
            C 158.2 251 153.1 234.4 131.3 224.6
            C 136.9 211.8 140.2 197.1 140.2 180
            C 140.2 146.7 138 119.7 126.8 102.1
            C 120.1 91.7 106.2 78.8 105.5 68.2
            C 104.9 59.9 111.5 54 119.4 54
            C 126.4 54 130.6 58.5 128.4 63.4
            Q 127.7 64.9 126.4 63.6
            C 124.2 61.5 119.9 63.2 119.4 66.6
            C 118.9 70.1 124 71.1 127.7 68.8
            Q 130.2 66.9 132.9 63.8
            L 178.3 12.5 Q 179.4 11 180.6 12.5
            C 189 25.7 197.4 31.6 213 32.6
            C 225.3 33.4 239.6 33 250 38
            C 258.6 42.1 264.7 49.3 264.7 57.4
            C 264.7 66.7 257.9 75.6 247.7 78.3
            C 238.2 80.8 226.5 76.4 223.8 68.3
            C 222 62.9 225.6 56.8 231.3 54
            Q 236.7 51.4 241.8 52.3
            Q 243.2 52.5 242.1 51.4
            C 237.1 48.5 230.3 48.7 225.3 52
            C 219.1 56.1 216.7 62.7 218.2 69.9
            C 220 78.5 230.5 84.8 239.3 85.6
            Q 242.1 85.9 245.1 86.1
            C 234.3 98.7 228.7 112.4 225.4 125.6
            C 218.6 149.6 217.5 187.3 225.4 210.4
            Q 227.6 219.7 231 224.1
            C 209.7 234.8 201.8 252 201.8 275 L 202 320 Z
            """
        case .doubleBass:
            """
            M 153 86 C 151 121 144 156 139 208 Q 133 255 137 282
            L 137 320 L 223 320 L 223 282 Q 227 255 221 208
            C 216 156 209 121 207 86 Z
            """
        case .pipa:
            Self.pipaCrown + " " + Self.pipaNeck
        case .violin, .viola, .cello:
            // Shared front profile traced from the selected violin drawing.
            """
            M 150 320 L 150 267 C 143 233 146 177 151 135
            L 158.58 100.51 \(Self.bowedScrollOutline)
            L 209 135 C 215 177 217 233 209 267 L 209 320 Z
            """
        }
    }

    // Outline coordinates are in the same canvas as the pegs and nut.
    private func contour(_ commands: String) -> Path {
        Path(tunerCommands: commands)
    }

    private static let outlineStroke = StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)

    func draw(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        switch self {
        case .guitar:
            drawAcousticGuitar(in: context, surface: surface, drawing: drawing)
        case .headlessGuitar, .headlessGuitarSeven:
            drawHeadless(in: context, surface: surface, drawing: drawing)
        case .bass, .threePlusOneBass, .jazzBassFive:
            drawCloverBass(in: context, surface: surface, drawing: drawing)
        case .inlineGuitar, .guitarSeven, .inlineGuitarSeven, .guitarTwelve, .pairedBass, .sixStringBass,
             .ukulele, .baritoneUkulele, .banjo, .mandolin:
            drawGearedHeadstock(in: context, surface: surface, drawing: drawing)
        case .doubleBass:
            drawUprightBass(in: context, surface: surface, drawing: drawing)
        case .pipa:
            var detail = context
            detail.concatenate(Self.pipaDetailTransform)
            drawPipa(in: detail, surface: surface, drawing: drawing)
        case .violin, .viola, .cello:
            drawPegbox(in: context, surface: surface, drawing: drawing)
        }
    }

    private func drawHeadless(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let plate = clampPlate
        let slope = clampTransform
        let housing = Path(roundedRect: plate, cornerRadius: 9).applying(slope)
        let fret = Path(CGRect(x: nut.minX, y: 222, width: nut.width, height: 3)).applying(slope)
        context.stroke(contour(outline), with: .color(ink), style: Self.outlineStroke)
        context.stroke(Path(nut).applying(slope), with: .color(ink), lineWidth: 1.2)
        context.stroke(fret, with: .color(ink), lineWidth: 0.8)
        context.fill(housing, with: .color(surface))
        context.stroke(housing, with: .color(ink), style: Self.outlineStroke)
        for (index, string) in positions.enumerated() {
            let color = drawing.color(for: index)
            let x = string.nutX
            let start = CGPoint(x: x, y: plate.maxY).applying(slope)
            let clampTop = CGPoint(x: x, y: plate.minY - 5).applying(slope)
            let clampBase = CGPoint(x: x, y: plate.minY).applying(slope)
            let lines = Path { path in
                path.move(to: clampTop)
                path.addLine(to: clampBase)
                path.move(to: start)
                path.addLine(to: CGPoint(x: x, y: 261))
            }
            context.stroke(lines, with: .color(color),
                           lineWidth: drawing.lineWidth(for: index, normal: max(0.85, 1.55 - CGFloat(index) * 0.12), focused: 2.2))
            if index > 0 {
                let boundary = x - (self == .headlessGuitarSeven ? 17 : 18)
                let rake: CGFloat = index.isMultiple(of: 2) ? 4 : -4
                let seam = Path { path in
                    path.move(to: CGPoint(x: boundary - rake, y: plate.minY + 3).applying(slope))
                    path.addLine(to: CGPoint(x: boundary + rake, y: plate.maxY - 3).applying(slope))
                }
                context.stroke(seam, with: .color(ink.opacity(0.55)), lineWidth: 0.7)
            }
            drawPost(at: string.post, radius: 7.5, inner: 3, in: context, ink: color, surface: surface)
            drawing.drawContacts([clampBase, start], for: index, in: context)
        }
    }

    private func drawAcousticGuitar(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let pegs = positions
        drawOutline(contour(outline), in: context, ink: ink)
        for (index, peg) in pegs.enumerated() {
            let color = drawing.color(for: index)
            let shaftEnd = CGPoint(x: peg.key.x + (peg.left ? 11.5 : -11.5), y: peg.key.y)
            context.stroke(Path { p in p.move(to: shaftEnd); p.addLine(to: peg.post) },
                           with: .color(color), style: Self.outlineStroke)
            let key = Path(roundedRect: CGRect(x: peg.key.x - 11.5, y: peg.key.y - 12, width: 23, height: 24),
                           cornerRadius: 7)
            context.fill(key, with: .color(surface))
            context.stroke(key, with: .color(color), style: Self.outlineStroke)
        }
        for (index, peg) in pegs.enumerated() {
            let color = drawing.color(for: index)
            context.stroke(wire(from: peg.post, at: peg.nutX), with: .color(color),
                           lineWidth: drawing.lineWidth(for: index, normal: 1.15, focused: 2.2))
            drawPost(at: peg.post, radius: 7.5, inner: 4, in: context, ink: color, surface: surface)
            drawNutContacts(at: peg.nutX, index: index, in: context, drawing: drawing)
        }
    }

    private func drawNutContacts(at x: CGFloat, index: Int, in context: GraphicsContext, drawing: TunerStringDrawing) {
        drawing.drawContacts([CGPoint(x: x, y: nut.minY), CGPoint(x: x, y: nut.maxY)], for: index, in: context)
    }

    private func drawOutline(_ body: Path, in context: GraphicsContext, ink: Color) {
        context.stroke(body, with: .color(ink), style: Self.outlineStroke)
        context.stroke(Path(roundedRect: nut, cornerRadius: 1.5), with: .color(ink), lineWidth: 1.2)
    }

    // Enlarge the cropped headstock around its crown, keeping the tuner readout clear.
    private static let pipaDetailTransform: CGAffineTransform = {
        let scale: CGFloat = 1.22
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                 tx: 180 * (1 - scale), ty: 13 * (1 - scale))
    }()

    private var pipaPegs: [StringPosition] {
        // In the front view, the lowest peg carries string 1 (A3 in standard tuning).
        [
            string(174, 117, nutX: 164, left: true, offset: 74, labelX: 45),
            string(177, 142, nutX: 175, left: false, offset: 83, labelX: 315),
            string(183, 173, nutX: 185, left: true, offset: 87, labelX: 45),
            string(190, 192, nutX: 196, left: false, offset: 77, labelX: 315)
        ]
    }

    private static let pipaCrown = """
        M 180 13 C 175 19 165 18 157 17 Q 152 16 151 24
        Q 144 22 144 30 C 145 40 138 48 140 59
        C 141 72 149 83 162 86 Q 173 87 180 92
        Q 187 87 198 86 C 211 83 219 72 220 59
        C 222 48 215 40 216 30 Q 216 22 209 24 Q 208 16 203 17 C 195 18 185 19 180 13 Z
        """
    private static let pipaNeckEnd: CGFloat = 261
    private static let pipaNeck = """
        M 162 80 L 198 80 C 199 115 199 153 203 183
        L 203 208 Q 203 211 199 212 Q 199 239 202 \(pipaNeckEnd)
        L 158 \(pipaNeckEnd) Q 161 239 161 212 Q 157 211 157 208
        L 157 183 C 161 153 161 115 162 80 Z
        """
    private static let pipaNut = CGRect(x: 157, y: 183, width: 46, height: 12)
    private static let pipaKeyOutline = Path(tunerCommands: """
        M 53 -3.1 C 32 -3.2 9 -10.6 -7 -10.8
        C -14 -11 -17 -7 -17 0 C -17 7 -14 11 -7 10.8
        C 9 10.6 32 3.2 53 3.1 Z
        """)
    private static let pipaKey = Path { path in
        path.addPath(pipaKeyOutline)
        path.move(to: CGPoint(x: -11, y: -10))
        path.addQuadCurve(to: CGPoint(x: -11, y: 10), control: CGPoint(x: -15, y: 0))
    }
    private static let pipaStem = CGRect(x: 52, y: -3.5, width: 23, height: 7)

    private func drawPipa(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let crown = contour(Self.pipaCrown)
        let neck = contour(Self.pipaNeck)
        // The opening ends at the mountain gate. The lowest roller sits behind it.
        let cavity = contour("""
            M 171 109 Q 171 104 177 104 L 183 104 Q 189 104 189 109
            L 198 \(nut.minY) L 162 \(nut.minY) Z
            """)
        var inside = context
        inside.clip(to: cavity)
        var outside = context
        outside.clip(to: neck, options: .inverse)
        let pegs = pipaPegs
        let halfShaft = Self.pipaStem.height / 2
        for (index, peg) in pegs.enumerated() {
            let color = drawing.color(for: index)
            drawKey(peg, handle: Self.pipaKey, stem: Self.pipaStem, in: outside, ink: color, surface: surface)
            if cavity.contains(peg.post) {
                let shaft = Path(CGRect(x: neck.boundingRect.minX, y: peg.post.y - halfShaft,
                                        width: neck.boundingRect.width, height: 2 * halfShaft))
                inside.stroke(shaft, with: .color(color), lineWidth: 0.85)
            }
        }

        drawPipaProfile(crown: crown, neck: neck, in: context, ink: ink, stroke: Self.outlineStroke)
        context.stroke(cavity, with: .color(ink), lineWidth: 0.9)
        context.stroke(Path(roundedRect: nut, cornerRadius: 2), with: .color(ink), lineWidth: 1.2)

        let firstXiang = contour("M 161 228 L 199 228 L 199.5 233 L 160.5 233 Z")
        context.stroke(firstXiang, with: .color(ink), lineWidth: 0.85)

        for index in drawing.paintOrder(pegs.indices) {
            let peg = pegs[index]
            let color = drawing.color(for: index)
            let weight = drawing.lineWidth(for: index, normal: 0.88, focused: 1.65)
            if cavity.contains(peg.post) {
                drawPegboxWinding(peg, halfShaft: halfShaft, in: context, inside: inside, color: color, weight: weight)
            } else {
                // The solid heel of the pegbox hides the lowest shaft and its winding.
                let nutContact = CGPoint(x: peg.nutX, y: nut.minY)
                context.stroke(wire(from: nutContact, at: peg.nutX), with: .color(color), lineWidth: weight)
            }
            drawNutContacts(at: peg.nutX, index: index, in: context, drawing: drawing)
        }
    }

    private func drawPipaProfile(crown: Path, neck: Path, in context: GraphicsContext,
                                 ink: Color, stroke: StrokeStyle) {
        var behindCrown = context
        behindCrown.clip(to: crown, options: .inverse)
        behindCrown.stroke(neck, with: .color(ink), style: stroke)
        context.stroke(crown, with: .color(ink), style: stroke)
    }

    private func wire(from start: CGPoint, at nutX: CGFloat) -> Path {
        Path { path in
            path.move(to: start)
            path.addLine(to: CGPoint(x: nutX, y: nut.minY))
            path.addLine(to: CGPoint(x: nutX, y: neckEnd))
        }
    }

    private func drawPost(at point: CGPoint, radius: CGFloat, inner: CGFloat, in context: GraphicsContext,
                          ink: Color, surface: Color) {
        for r in [radius, inner] {
            let ring = Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
            context.fill(ring, with: .color(surface))
            context.stroke(ring, with: .color(ink), lineWidth: r == radius ? 1.7 : 1)
        }
    }

    private var machineHandle: Path {
        switch self {
        case .inlineGuitar:
            contour("M 8 -3.3 Q 4 -3.3 3 -7 C 1 -11 -2 -12 -6 -11 C -12 -10 -15 -5 -15 0 C -15 5 -12 10 -6 11 C -2 12 1 11 3 7 Q 4 3.3 8 3.3 Z")
        case .guitarSeven:
            contour("M 5 -3.5 Q 1 -3.5 1 -8 Q 1 -11 -3 -11 C -12 -11 -16 -5 -16 0 C -16 5 -12 11 -3 11 Q 1 11 1 8 Q 1 3.5 5 3.5 Z")
        case .inlineGuitarSeven:
            contour("M 5 -3 Q 2 -3 1 -6 L -3 -10 L -12 -10 Q -14 -10 -15 -7 L -16 -5 L -16 5 L -15 7 Q -14 10 -12 10 L -3 10 L 1 6 Q 2 3 5 3 Z")
        case .guitarTwelve:
            contour("M 6 -3.5 C -2 -3.5 -5 -11 -10 -11 C -16 -11 -18 -6 -18 0 C -18 6 -16 11 -10 11 C -5 11 -2 3.5 6 3.5 Z")
        case .mandolin:
            contour("M 5 -3 Q 1 -3 0 -6 C -3 -10 -10 -10 -13 -6 C -16 -3 -16 3 -13 6 C -10 10 -3 10 0 6 Q 1 3 5 3 Z")
        case .banjo:
            contour("M 6 -2.9 C 2 -3 1 -5 -1 -7 C -5 -10 -11 -7 -11 0 C -11 7 -5 10 -1 7 C 1 5 2 3 6 2.9 Z")
        case .doubleBass:
            contour("M 10 -3 Q 7 -4 6 -8 C 4 -13 -5 -14 -10 -9 C -15 -5 -15 5 -10 9 C -5 14 4 13 6 8 Q 7 4 10 3 Z")
        case .sixStringBass:
            contour("M 11 -4 C 3 -4 1 -9 -2 -15 C -6 -22 -16 -20 -19 -13 C -20 -9 -26 -6 -26 0 C -26 6 -20 9 -19 13 C -16 20 -6 22 -2 15 C 1 9 3 4 11 4 Z")
        case .baritoneUkulele:
            Path(ellipseIn: CGRect(x: -15, y: -19, width: 29, height: 38))
        case .pairedBass:
            contour("""
            M 12 -3.7 C 2 -5 -5 -10 -12 -16
            C -17 -20 -22 -17 -20 -10 Q -17 0 -20 10
            C -22 17 -17 20 -12 16 C -5 10 2 5 12 3.7 Z
            """)
        default:
            contour("M 8 -3 C 4 -3 2 -8 0 -10 C -4 -14 -12 -11 -13 -6 C -14 -3 -14 3 -13 6 C -12 11 -4 14 0 10 C 2 8 4 3 8 3 Z")
        }
    }

    private func drawKey(_ peg: StringPosition, handle: Path, stem: CGRect, in outside: GraphicsContext,
                         ink: Color, surface: Color) {
        let angle = self == .mandolin
            ? (peg.left ? CGFloat.zero : .pi)
            : atan2(peg.post.y - peg.key.y, peg.post.x - peg.key.x)
        let placement = CGAffineTransform(rotationAngle: angle)
            .concatenating(CGAffineTransform(translationX: peg.key.x, y: peg.key.y))
        let shaft = Path(roundedRect: stem, cornerRadius: 1).applying(placement)
        outside.fill(shaft, with: .color(surface))
        outside.stroke(shaft, with: .color(ink), lineWidth: 1.05)
        let key = handle.applying(placement)
        outside.fill(key, with: .color(surface))
        outside.stroke(key, with: .color(ink), style: Self.outlineStroke)
    }

    private func drawGearedHeadstock(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let body = contour(outline)
        var outside = context
        outside.clip(to: body, options: .inverse)
        let doubled = self == .guitarTwelve || self == .mandolin
        let radius: CGFloat = doubled ? 5.6 : self == .pairedBass ? 12.5 : self == .sixStringBass ? 9 : isUkulele ? 7.5 : 7
        let handle = machineHandle
        let stemWidth: CGFloat = self == .pairedBass || self == .sixStringBass ? 5.4 : 4.2
        drawOutline(body, in: context, ink: ink)
        if self == .banjo {
            context.stroke(contour("M 154 291 L 206 291"),
                           with: .color(ink.opacity(0.53)), lineWidth: 0.9)
        }
        if self == .sixStringBass || self == .baritoneUkulele {
            let fret = Path(CGRect(x: nut.minX, y: 291, width: nut.width, height: 2))
            context.stroke(fret, with: .color(ink), lineWidth: 0.9)
        }
        let ranges = wireRanges
        for (course, position) in positions.enumerated() {
            let wires = ranges[course]
            let pegs = self == .mandolin ? mandolinPegs(for: position) : [position]
            if self == .mandolin {
                let towardKeys: CGFloat = position.left ? 1 : -1
                let x = position.key.x - towardKeys * 24
                let top = pegs[0].key.y
                let bottom = pegs[1].key.y
                let middle = position.key.y
                let bracket = Path { path in
                    path.move(to: CGPoint(x: x + towardKeys * 3, y: top))
                    path.addLine(to: CGPoint(x: x, y: top))
                    path.addLine(to: CGPoint(x: x, y: bottom))
                    path.addLine(to: CGPoint(x: x + towardKeys * 3, y: bottom))
                    path.move(to: CGPoint(x: x, y: middle))
                    path.addLine(to: CGPoint(x: x - towardKeys * 8, y: middle))
                }
                context.stroke(bracket, with: .color(drawing.color(for: wires).opacity(0.72)),
                               style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            }
            for (peg, index) in zip(pegs, wires) {
                let color = drawing.color(for: index)
                drawKey(peg, handle: handle, stem: CGRect(x: 4, y: -stemWidth / 2, width: self == .banjo ? 46 : 43, height: stemWidth),
                        in: outside, ink: color, surface: surface)
                if self == .banjo && index == 0 {
                    let drone = Path { path in
                        path.move(to: peg.post)
                        path.addQuadCurve(to: CGPoint(x: peg.nutX, y: 310), control: CGPoint(x: peg.nutX, y: 307))
                        path.addLine(to: CGPoint(x: peg.nutX, y: neckEnd))
                    }
                    context.stroke(drone, with: .color(color), style: StrokeStyle(lineWidth: drawing.lineWidth(for: index, normal: 1.05, focused: 2.1), lineCap: .round))
                    drawPost(at: peg.post, radius: 3.5, inner: 1.3, in: context, ink: color, surface: surface)
                    drawing.drawContacts([CGPoint(x: peg.nutX, y: 310)], for: index, in: context)
                    continue
                }
                // Come off the inside shoulder of the post, as on a strung instrument.
                let start = CGPoint(x: peg.post.x + (peg.left ? 1 : -1) * radius * 0.82,
                                    y: peg.post.y + radius * 0.54)
                let gauge: CGFloat
                if self == .guitarTwelve {
                    gauge = index < 8 && index.isMultiple(of: 2) ? 0.85 : 1.15
                } else if self == .mandolin {
                    gauge = course < 2 ? 1.13 : 0.86
                } else if self == .banjo {
                    gauge = 1.45 - CGFloat(index - 1) * 0.16
                } else {
                    gauge = isUkulele ? 1.15 : max(0.95, 1.6 - CGFloat(index) * 0.13)
                }
                let activeGauge = self == .mandolin ? 1.6 : 2.2
                context.stroke(wire(from: start, at: peg.nutX), with: .color(color),
                               style: StrokeStyle(lineWidth: drawing.lineWidth(for: index, normal: gauge, focused: activeGauge), lineCap: .round))
                drawPost(at: peg.post, radius: radius, inner: radius * 0.58, in: context, ink: color, surface: surface)
                drawNutContacts(at: peg.nutX, index: index, in: context, drawing: drawing)
            }
        }
        if self == .inlineGuitar {
            // The butterfly retainer sits over the highest two strings.
            let tree = contour("M 195 196 Q 197 193 200 195 Q 204 198 208 195 Q 211 193 213 196 L 213 201 Q 211 204 208 202 Q 204 199 200 202 Q 197 204 195 201 Z")
            context.fill(tree, with: .color(surface))
            context.stroke(tree, with: .color(ink), lineWidth: 1)
            var inside = context
            inside.clip(to: tree)
            for index in 4..<6 where drawing.completed.contains(index) || drawing.active == index {
                let peg = positions[index]
                let start = CGPoint(x: peg.post.x + radius * 0.82, y: peg.post.y + radius * 0.54)
                inside.stroke(wire(from: start, at: peg.nutX), with: .color(drawing.color(for: index)), lineWidth: 1.45)
            }
        }
    }

    private static let bowedScrollOutline = """
        C 155.85 101.22 152.49 102.82 150.6 101.14 C 147.03 98.41 149 94.42 150.31 90.72
        L 151.82 85.35 L 139.05 85.35 C 134.93 85.35 132.46 80.98 132.33 75.39
        C 130.23 74.97 130.23 72.16 130.23 67.96 L 130.23 60.82 C 130.23 57.63 131.07 54.94 133.59 54.94
        L 145.14 54.94 C 147.03 46.54 147.87 39.99 151.44 39.99 L 158.96 39.99
        L 162.61 14.62 C 163.2 11.43 164.71 10.13 167.11 10.04
        C 169.29 10.04 171.81 12.1 174.12 12.1 C 176.22 12.1 178.28 10.04 180 10.04
        C 181.72 10.04 183.91 12.1 185.96 12.1 C 188.27 12.1 191.47 10.04 193.23 10.04
        C 195.62 10.13 197.14 11.43 197.6 14.62 L 201.55 39.99 L 208.35 39.99
        C 211.88 39.99 212.93 46.54 214.86 54.94 L 225.57 54.94
        C 228.34 54.94 228.93 57.63 228.93 60.82 L 228.93 67.96 C 228.93 72.16 228.93 74.97 226.62 75.39
        C 227 80.98 224.18 85.35 220.53 85.35 L 208.69 85.35
        L 210.11 90.72 C 211.54 94.42 213.22 98.41 209.74 101.14 C 207.85 102.82 204.4 101.14 201.63 100.51
        """
    private static let bowedScrollSeam = "C 192.81 97.78 187.35 101.98 180 102.32 C 172.65 101.98 167.61 97.78 158.58 100.51"

    private static let bowedScrollRails = """
        M 158.96 39.99 C 156.31 59.56 154.51 74.26 151.82 85.35
        M 201.55 39.99 C 204.4 59.56 206.21 74.26 208.69 85.35
        M 145.14 54.94 C 142.54 66.07 142.07 81.9 134.51 83.33
        M 214.86 54.94 C 217.38 66.07 218.14 81.9 224.81 83.33
        M 132.33 75.39 L 140.94 75.39 M 226.62 75.39 L 219.06 75.39
        """
    private static let bowedScrollEngraving = """
        M 167.11 10.04 C 165.3 29.74 159.42 87.91 151.82 101.48
        M 193.23 10.04 C 195.04 29.74 201.13 87.91 208.81 101.48
        M 180 10.04 L 180 102.32
        M 133.59 54.94 L 133.59 71.74 Q 133.59 73.84 132.33 75.39
        M 225.57 54.94 L 225.57 71.74 Q 225.57 73.84 226.62 75.39
        """

    private static let uprightScrollTransform = CGAffineTransform(a: 1.28, b: 0, c: 0, d: 0.92, tx: -50.4, ty: 1)

    private var uprightScrollOutline: Path {
        contour("M 158.58 100.51 " + Self.bowedScrollOutline + " " + Self.bowedScrollSeam + " Z")
            .applying(Self.uprightScrollTransform)
    }

    private func drawBowedScrollDetails(in context: GraphicsContext, ink: Color, transform: CGAffineTransform = .identity) {
        context.stroke(contour(Self.bowedScrollRails).applying(transform), with: .color(ink), lineWidth: 1.05)
        context.stroke(contour(Self.bowedScrollEngraving).applying(transform), with: .color(ink), lineWidth: 0.68)
    }

    private static let bowedLabelInset: CGFloat = 36
    private static let uprightBassKeyReach: CGFloat = 44

    private static func uprightBassMount(at y: CGFloat, left: Bool) -> CGAffineTransform {
        let outward: CGFloat = left ? -1 : 1
        let slope: CGFloat = 0.10
        let cheek = 180 + outward * (28 + (y - 86) * slope)
        return CGAffineTransform(rotationAngle: -atan(slope))
            .concatenating(CGAffineTransform(scaleX: outward, y: 1))
            .concatenating(CGAffineTransform(translationX: cheek, y: y))
    }

    private static func uprightBassPeg(_ x: CGFloat, _ y: CGFloat, nutX: CGFloat, left: Bool) -> StringPosition {
        let key = CGPoint(x: uprightBassKeyReach, y: 0).applying(uprightBassMount(at: y, left: left))
        return StringPosition(post: CGPoint(x: x, y: y), key: key, nutX: nutX,
                              label: CGPoint(x: left ? bowedLabelInset : 360 - bowedLabelInset, y: key.y), left: left)
    }

    private func drawUprightBass(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let body = contour(outline)
        let cavity = contour("M 163 101 L 197 101 L 213 274 L 147 274 Z")
        let halfShaft: CGFloat = 4
        let pegs = positions
        var outside = context
        outside.clip(to: body, options: .inverse)
        var inside = context
        inside.clip(to: cavity)

        drawOutline(body, in: context, ink: ink)
        context.stroke(cavity, with: .color(ink), lineWidth: 0.9)
        let crown = uprightScrollOutline
        context.fill(crown, with: .color(surface))
        context.stroke(crown, with: .color(ink), style: Self.outlineStroke)
        drawBowedScrollDetails(in: context, ink: ink, transform: Self.uprightScrollTransform)

        let plate = Path(roundedRect: CGRect(x: -1, y: -16, width: 11, height: 34), cornerRadius: 2.5)
        let gear = contour("M 2 -10 L 10 -10 L 11 -7 L 14 -7 L 14 -4 L 12 -4 L 12 -1 L 14 -1 L 14 2 L 12 2 L 12 5 L 14 5 L 14 8 L 11 8 L 10 11 L 2 11 Z")
        let handle = machineHandle
        for (index, peg) in pegs.enumerated() {
            let y = peg.post.y
            let color = drawing.color(for: index)
            // The stem is the normal to the cheek; the cross-shaft inside stays horizontal.
            let mounting = Self.uprightBassMount(at: y, left: peg.left)
            let keyStem = Path(roundedRect: CGRect(x: 12, y: -2.65,
                                                   width: Self.uprightBassKeyReach - 20, height: 5.3), cornerRadius: 0.8)
            outside.stroke(keyStem.applying(mounting), with: .color(color), lineWidth: 1.05)
            for hardware in [plate, gear] {
                let shape = hardware.applying(mounting)
                outside.fill(shape, with: .color(surface))
                outside.stroke(shape, with: .color(color), lineWidth: 1.05)
            }
            for screwY in [CGFloat(-13), 14] {
                let screw = Path(ellipseIn: CGRect(x: 4, y: screwY - 0.9, width: 1.8, height: 1.8))
                outside.fill(screw.applying(mounting), with: .color(color))
            }
            let keyPlacement = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: Self.uprightBassKeyReach, ty: 0)
            let key = handle.applying(keyPlacement.concatenating(mounting))
            outside.fill(key, with: .color(surface))
            outside.stroke(key, with: .color(color), style: Self.outlineStroke)
            let roller = Path(CGRect(x: 141, y: y - halfShaft, width: 78, height: 2 * halfShaft))
            inside.stroke(roller, with: .color(color), lineWidth: 0.85)
        }
        for (index, peg) in pegs.enumerated() {
            drawPegboxWinding(peg, halfShaft: halfShaft, in: context, inside: inside,
                             color: drawing.color(for: index),
                             weight: drawing.lineWidth(for: index, normal: 1.55 - CGFloat(index) * 0.16, focused: 1.9))
            drawNutContacts(at: peg.nutX, index: index, in: context, drawing: drawing)
        }
    }

    private func drawPegbox(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let cello = self == .cello
        let body = contour(outline)
        let cavity = contour("M 168 109 L 193 109 L 206 260 L 153 260 Z")
        let handle = contour(cello
            ? """
              M -25 0
              C -25 -14 -14 -22 1 -22 Q 10 -22 10 -17
              Q 8.5 -8 8.5 0 Q 8.5 8 10 17
              Q 10 22 1 22 C -14 22 -25 14 -25 0 Z
              """
            : """
              M 10 -7.56
              C 9.79 -8.61 9.12 -9.03 9.29 -10.58 C 9.96 -17.39 4.46 -23.94 -3.1 -23.94
              C -14.65 -24.57 -23.01 -13.31 -23.52 -1.85
              C -24.27 8.4 -18.98 18.4 -9.82 22.05 C -2.98 25.2 4.75 21.88 8.32 15.92
              C 9.83 13.48 9.75 10 9.03 7.39 Q 9.79 6.51 10 6.51 Z
              """)
        let handleCarving = contour("""
              M 9.29 -10.58 C 8.66 -4.41 1.85 -0.46 -3.36 -6.72
              M 9.03 7.39 C 6.26 1.13 0.47 1.68 -3.36 6.47
              """)
        let pegs = positions
        let halfShaft: CGFloat = cello ? 5.2 : 4.5
        let shaftThickness = 2 * halfShaft
        var outside = context
        outside.clip(to: body, options: .inverse)
        var inside = context
        inside.clip(to: cavity)

        // The same shaft bounds are used through the cavity and outside the wooden cheek.
        for (index, peg) in pegs.enumerated() {
            let color = drawing.color(for: index)
            let direction: CGFloat = peg.left ? 1 : -1
            let joint = peg.key.x + direction * 10
            let top = peg.post.y - halfShaft
            let bottom = peg.post.y + halfShaft
            let outsideShaft = Path { path in
                path.move(to: CGPoint(x: joint, y: top))
                path.addLine(to: CGPoint(x: 180, y: top))
                path.move(to: CGPoint(x: joint, y: bottom))
                path.addLine(to: CGPoint(x: 180, y: bottom))
            }
            outside.stroke(outsideShaft, with: .color(color), lineWidth: 0.85)
            let insideShaft = Path(CGRect(x: 143, y: top, width: 74, height: shaftThickness))
            inside.stroke(insideShaft, with: .color(color), lineWidth: 0.85)

            let placement = CGAffineTransform(scaleX: direction, y: 1)
                .concatenating(CGAffineTransform(translationX: peg.key.x, y: peg.key.y))
            let button = handle.applying(placement)
            outside.fill(button, with: .color(surface))
            outside.stroke(button, with: .color(color), style: Self.outlineStroke)
            let collarX = cello ? joint - 1 : min(joint, joint + direction * 1.7)
            let collarOverhang: CGFloat = cello ? 1 : 1.4
            let collar = Path(roundedRect: CGRect(x: collarX, y: top - collarOverhang,
                                                  width: cello ? 2 : 1.7, height: shaftThickness + 2 * collarOverhang),
                              cornerRadius: 0.65)
            outside.fill(collar, with: .color(surface))
            outside.stroke(collar, with: .color(color), lineWidth: 0.85)
            if !cello {
                outside.stroke(handleCarving.applying(placement), with: .color(color),
                               style: StrokeStyle(lineWidth: 0.72, lineCap: .round))
            }
            let finialBounds = cello ? CGRect(x: -29.5, y: -2.25, width: 4.5, height: 4.5)
                                     : CGRect(x: -29.5, y: -3.1, width: 6.2, height: 6.2)
            let finial = Path(ellipseIn: finialBounds)
            outside.stroke(finial.applying(placement), with: .color(color), style: Self.outlineStroke)
        }

        context.stroke(cavity, with: .color(ink), lineWidth: 0.9)
        drawBowedScrollDetails(in: context, ink: ink)
        context.stroke(contour("M 201.63 100.51 " + Self.bowedScrollSeam), with: .color(ink), lineWidth: 1.05)
        drawOutline(body, in: context, ink: ink)
        for (index, peg) in pegs.enumerated() {
            drawPegboxWinding(peg, halfShaft: halfShaft, in: context, inside: inside,
                             color: drawing.color(for: index), weight: drawing.lineWidth(for: index, normal: 1.05, focused: 1.9))
            drawNutContacts(at: peg.nutX, index: index, in: context, drawing: drawing)
        }
    }

    private func drawPegboxWinding(_ peg: StringPosition, halfShaft: CGFloat, in context: GraphicsContext,
                                   inside: GraphicsContext, color: Color, weight: CGFloat) {
        let direction: CGFloat = peg.left ? -1 : 1
        let top = peg.post.y - halfShaft
        let bottom = peg.post.y + halfShaft

        func addTurn(to path: inout Path, x: CGFloat) {
            path.move(to: CGPoint(x: x - direction * 0.8, y: top))
            path.addCurve(to: CGPoint(x: x, y: bottom),
                          control1: CGPoint(x: x + direction * 1.7, y: top),
                          control2: CGPoint(x: x + direction * 1.5, y: bottom - 3))
        }

        // Both turns meet the top and bottom edges of the roller.
        let secondTurn = Path { addTurn(to: &$0, x: peg.post.x + direction * 2.6) }
        inside.stroke(secondTurn, with: .color(color), lineWidth: weight)
        let strand = Path { path in
            addTurn(to: &path, x: peg.post.x)
            path.addLine(to: CGPoint(x: peg.nutX, y: nut.minY))
            path.addLine(to: CGPoint(x: peg.nutX, y: neckEnd))
        }
        context.stroke(strand, with: .color(color),
                       style: StrokeStyle(lineWidth: weight, lineCap: .butt, lineJoin: .round))
    }

    private static let bassRailTop = CGPoint(x: 187, y: 39)
    private static let bassRailBottom = CGPoint(x: 149, y: 224)
    // Keep the inline handles equally exposed along the perpendicular to the rail.
    private static func bassPeg(_ post: CGPoint, nutX: CGFloat, railTop: CGPoint, railBottom: CGPoint,
                                labelX: CGFloat) -> StringPosition {
        let angle = atan2(railTop.x - railBottom.x, railBottom.y - railTop.y)
        let horizontal = cos(angle)
        let vertical = sin(angle)
        let inset = (post.x - railTop.x) * horizontal + (post.y - railTop.y) * vertical
        let offset = inset + 25
        let key = CGPoint(x: post.x - offset * horizontal, y: post.y - offset * vertical)
        return StringPosition(post: post, key: key, nutX: nutX,
                              label: CGPoint(x: labelX, y: key.y), left: true)
    }

    private static let precisionBassPositions = [
        CGPoint(x: 181, y: 226), CGPoint(x: 192, y: 172),
        CGPoint(x: 204, y: 118), CGPoint(x: 216, y: 62)
    ].enumerated().map { index, post in
        bassPeg(post, nutX: 187 + CGFloat(index) * 12.4,
                railTop: bassRailTop, railBottom: bassRailBottom, labelX: 74)
    }

    private static let threePlusOneRailTop = CGPoint(x: 169, y: 45)
    private static let threePlusOneRailBottom = CGPoint(x: 125, y: 184)
    private static let threePlusOneBassPositions: [StringPosition] = {
        let leftPosts = [CGPoint(x: 150, y: 206), CGPoint(x: 164, y: 146), CGPoint(x: 183, y: 88)]
        let leftPegs = leftPosts.enumerated().map { index, post in
            bassPeg(post, nutX: 159 + CGFloat(index) * 14,
                    railTop: threePlusOneRailTop, railBottom: threePlusOneRailBottom, labelX: 47)
        }
        let highG = TunerHeadstock.threePlusOneBass.string(
            212, 187, nutX: 201, left: false, offset: 54, angle: -16, labelX: 319
        )
        return leftPegs + [highG]
    }()

    private static let bassBody = TunerHeadstock.bass.contour(TunerHeadstock.bass.outline)
    private static let threePlusOneBassBody = TunerHeadstock.threePlusOneBass.contour(TunerHeadstock.threePlusOneBass.outline)
    private static let jazzBassFiveBody = TunerHeadstock.jazzBassFive.contour(TunerHeadstock.jazzBassFive.outline)
    private static let cloverKey = TunerHeadstock.bass.contour("""
        M 32 -5.5 C 18 -5.5 12 -11 8 -18
        C 4 -25 -9 -25 -14 -17
        C -21 -16 -25 -8 -25 0
        C -25 8 -21 16 -14 17
        C -9 25 4 25 8 18
        C 12 11 18 5.5 32 5.5 Z
        """)
    private static let bassKeyShaft = Path(roundedRect: CGRect(x: 9, y: -2.8, width: 23, height: 5.6),
                                          cornerRadius: 2.8)

    private func drawCloverBass(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        let ink = drawing.outline
        let stroke = StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
        let body: Path
        let retainers: [CGPoint]
        switch self {
        case .bass:
            body = Self.bassBody
            retainers = [CGPoint(x: 217, y: 187)]
        case .threePlusOneBass:
            body = Self.threePlusOneBassBody
            retainers = [CGPoint(x: 180, y: 199)]
        default:
            body = Self.jazzBassFiveBody
            retainers = [CGPoint(x: 179, y: 213), CGPoint(x: 201, y: 250)]
        }
        var outside = context
        outside.clip(to: body, options: .inverse)
        let gauges: [CGFloat] = self == .jazzBassFive ? [1.95, 1.75, 1.45, 1.2, 1.0] : [1.75, 1.45, 1.2, 1.0]
        for (index, peg) in positions.enumerated() {
            let color = drawing.color(for: index)
            let angle = atan2(peg.post.y - peg.key.y, peg.post.x - peg.key.x)
            let transform = CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: peg.key.x, y: peg.key.y))
            let key = Self.cloverKey.applying(transform)
            outside.stroke(key, with: .color(color), style: stroke)
            // In the reference, the metal shaft sits inside the tapered neck,
            // and both disappear together behind the wood.
            let shaft = Self.bassKeyShaft.applying(transform)
            outside.fill(shaft, with: .color(surface))
            outside.stroke(shaft, with: .color(color), lineWidth: 1)
        }
        context.stroke(body, with: .color(ink), style: stroke)
        context.stroke(Path { path in
            path.move(to: CGPoint(x: nut.minX, y: nut.minY))
            path.addLine(to: CGPoint(x: nut.maxX, y: nut.minY))
            path.move(to: CGPoint(x: nut.minX, y: nut.maxY))
            path.addLine(to: CGPoint(x: nut.maxX, y: nut.maxY))
        }, with: .color(ink), lineWidth: 1.05)

        for (index, peg) in positions.enumerated() {
            let color = drawing.color(for: index)
            let wire = bassWire(for: peg)
            context.stroke(wire, with: .color(color), style: StrokeStyle(
                lineWidth: drawing.lineWidth(for: index, normal: gauges[index], focused: 2.3), lineCap: .round
            ))
            let outer = Path(ellipseIn: CGRect(x: peg.post.x - 12.5, y: peg.post.y - 12.5, width: 25, height: 25))
            let inner = Path(ellipseIn: CGRect(x: peg.post.x - 8.5, y: peg.post.y - 8.5, width: 17, height: 17))
            // An open centre lets the string read as one continuous route from the post.
            context.stroke(outer, with: .color(color), lineWidth: 1.45)
            context.fill(inner, with: .color(surface))
            context.stroke(inner, with: .color(color), lineWidth: 1)
            let slot = Path { path in
                path.move(to: CGPoint(x: peg.post.x - 6, y: peg.post.y - 3))
                path.addLine(to: CGPoint(x: peg.post.x + 6, y: peg.post.y + 3))
            }
            context.stroke(slot, with: .color(color), lineWidth: 1.1)
            drawNutContacts(at: peg.nutX, index: index, in: context, drawing: drawing)
        }

        for retainer in retainers {
            drawBassRetainer(at: retainer, in: context, ink: ink, surface: surface)
            var inside = context
            inside.clip(to: Path(ellipseIn: CGRect(x: retainer.x - 10, y: retainer.y - 10, width: 20, height: 20)))
            for (index, peg) in positions.enumerated() where drawing.completed.contains(index) || drawing.active == index {
                inside.stroke(bassWire(for: peg), with: .color(drawing.color(for: index)), lineWidth: 1.4)
            }
        }
    }

    private func bassWire(for peg: StringPosition) -> Path {
        Path { path in
            path.move(to: CGPoint(x: peg.post.x + (peg.left ? 7 : -7), y: peg.post.y))
            path.addLine(to: CGPoint(x: peg.nutX, y: nut.midY))
            path.addLine(to: CGPoint(x: peg.nutX, y: self == .bass ? 314 : neckEnd))
        }
    }

    private func drawBassRetainer(at center: CGPoint, in context: GraphicsContext, ink: Color, surface: Color) {
        let retainer = Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20))
        let centerRing = Path(ellipseIn: CGRect(x: -6, y: -6, width: 12, height: 12))
        let screw = contour("M -2 0 L 2 0 M 0 -2 L 0 2")
        let shift = CGAffineTransform(translationX: center.x, y: center.y)
        context.fill(retainer.applying(shift), with: .color(surface))
        context.stroke(retainer.applying(shift), with: .color(ink), lineWidth: 1.15)
        context.stroke(centerRing.applying(shift), with: .color(ink.opacity(0.8)), lineWidth: 0.85)
        context.stroke(screw.applying(shift), with: .color(ink.opacity(0.8)), lineWidth: 0.8)
    }

    func pickerIcon(_ palette: InstrumentPalette, selected: Bool) -> some View {
        Canvas { canvas, size in
            var context = canvas
            let scale = size.height / 330
            context.translateBy(x: (size.width - 360 * scale) / 2, y: 0)
            context.scaleBy(x: scale, y: scale)
            let ink = selected ? Color(hex: 0xF5F0E2) : palette.ink
            let stroke = StrokeStyle(lineWidth: 6.2, lineCap: .round, lineJoin: .round)
            if self == .pipa {
                let neck = contour(Self.pipaNeck)
                drawPipaProfile(crown: contour(Self.pipaCrown), neck: neck, in: context, ink: ink, stroke: stroke)
                var outside = context
                outside.clip(to: neck, options: .inverse)
                for peg in pipaPegs {
                    let placement = CGAffineTransform(scaleX: peg.left ? 1 : -1, y: 1)
                        .concatenating(CGAffineTransform(translationX: peg.key.x, y: peg.key.y))
                    let stem = Path { path in
                        path.move(to: CGPoint(x: Self.pipaStem.minX, y: 0))
                        path.addLine(to: CGPoint(x: Self.pipaStem.maxX, y: 0))
                    }
                    outside.stroke(stem.applying(placement), with: .color(ink), lineWidth: 4.8)
                    outside.stroke(Self.pipaKeyOutline.applying(placement), with: .color(ink), style: stroke)
                }
                return
            }
            let shape = contour(outline)
            if self == .doubleBass {
                let crown = uprightScrollOutline
                var body = context
                body.clip(to: crown, options: .inverse)
                body.stroke(shape, with: .color(ink), style: stroke)
                context.stroke(crown, with: .color(ink), style: stroke)
            } else {
                context.stroke(shape, with: .color(ink), style: stroke)
            }
            if isHeadless {
                let plate = Path(roundedRect: clampPlate, cornerRadius: 9).applying(clampTransform)
                context.stroke(plate, with: .color(ink), lineWidth: 5.7)
                for peg in positions {
                    let screw = CGRect(x: peg.post.x - 5.5, y: peg.post.y - 5.5, width: 11, height: 11)
                    context.stroke(Path(ellipseIn: screw), with: .color(ink), lineWidth: 4.6)
                }
            } else {
                var outside = context
                outside.clip(to: shape, options: .inverse)
                let pegs = self == .mandolin ? positions.flatMap { mandolinPegs(for: $0) } : positions
                let keySize = self == .doubleBass ? CGSize(width: 24, height: 16) : CGSize(width: 18, height: 18)
                for peg in pegs {
                    let shaft = Path { path in
                        let anchor = self == .mandolin ? CGPoint(x: peg.post.x, y: peg.key.y) : peg.post
                        path.move(to: anchor)
                        let dx = peg.key.x - anchor.x
                        let dy = peg.key.y - anchor.y
                        let edge = 1 - (keySize.width / 2) / max(abs(dx), abs(dy))
                        path.addLine(to: CGPoint(x: anchor.x + dx * edge, y: anchor.y + dy * edge))
                    }
                    outside.stroke(shaft, with: .color(ink), lineWidth: 4.8)
                    let key = CGRect(x: peg.key.x - keySize.width / 2, y: peg.key.y - keySize.height / 2,
                                     width: keySize.width, height: keySize.height)
                    let keyPath = Path(roundedRect: key, cornerRadius: self == .doubleBass ? 8 : 5)
                    outside.stroke(keyPath, with: .color(ink), lineWidth: 5.6)
                }
            }
        }.accessibilityHidden(true)
    }
}

struct TunerHeadstockView<Layout: TunerHeadstockDrawing>: View {
    let p: InstrumentPalette
    let layout: Layout
    let strings: [Int]
    let drawing: TunerStringDrawing
    let select: (Int) -> Void

    var body: some View {
        let positions = layout.positions
        let ranges = layout.wireRanges
        ZStack {
            Canvas { context, _ in
                layout.draw(in: context, surface: p.tunerDrawingSurface, drawing: drawing)
            }
            .accessibilityHidden(true)
            ForEach(Array(zip(strings, positions).enumerated()), id: \.offset) { index, pair in
                let (note, peg) = pair
                let key = peg.key
                let label = peg.label
                let wires = ranges[index]
                let isCourse = wires.count > 1
                let hitWidth: CGFloat = isCourse ? 44 : abs(key.x - label.x) + 66
                Button {
                    select(drawing.active.flatMap { wires.contains($0) ? $0 : nil }
                           ?? wires.first { !drawing.completed.contains($0) } ?? wires.lowerBound)
                } label: {
                    if layout.isHeadless {
                        ZStack {
                            VStack(spacing: 3) {
                                noteLabel(note, size: 17)
                                mark(wires)
                            }.position(x: 17, y: 213)
                        }.frame(width: 34, height: 236).contentShape(Rectangle())
                    } else {
                        ZStack {
                            HStack(spacing: 4) {
                                if peg.left { mark(wires) }
                                noteLabel(note, size: 19)
                                if !peg.left { mark(wires) }
                            }.position(x: isCourse ? hitWidth / 2 : peg.left ? 33 : hitWidth - 33,
                                       y: layout.stringHitHeight / 2)
                        }.frame(width: hitWidth, height: layout.stringHitHeight).contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain).foregroundStyle(drawing.color(for: wires))
                .accessibilityLabel("\(layout.stringNumber(at: index, count: strings.count)), " + TunerPitch.label(note))
                .accessibilityValue(drawing.isConfirmed(wires) ? tunerText("In tune") : "")
                .accessibilityAddTraits(drawing.active.map(wires.contains) == true ? .isSelected : [])
                .accessibilityIdentifier("tuner-string-\(index)")
                .position(x: isCourse ? label.x : (key.x + label.x) / 2,
                          y: layout.isHeadless ? label.y - 89 : label.y)
                if isCourse {
                    ForEach(Array(zip(wires, layout.courseKeys[index]).enumerated()), id: \.offset) { offset, wire in
                        Button { select(wire.0) } label: {
                            Color.clear.frame(width: 42, height: 30).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(TunerPitch.label(note) + ", \(offset + 1)")
                        .accessibilityValue(drawing.completed.contains(wire.0) ? tunerText("In tune") : "")
                        .accessibilityIdentifier("tuner-course-\(index)-wire-\(offset)")
                        .position(wire.1)
                    }
                }
            }
        }
    }

    private func noteLabel(_ note: Int, size: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(TunerPitch.name(note)).font(InstrumentType.value(size))
            Text(String(note / 12 - 1)).font(InstrumentType.value(11))
        }
    }

    private func mark(_ wires: Range<Int>) -> some View {
        Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
            .foregroundStyle(p.tuningGreen).opacity(drawing.isConfirmed(wires) ? 1 : 0)
    }
}
