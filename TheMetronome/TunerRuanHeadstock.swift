import SwiftUI

struct TunerRuanHeadstock: TunerHeadstockDrawing {
    // Modern four-string ruan, in the Chinese orchestral tuning used by each size.
    // Order is the front view at the nut, from string 4 (thickest) to string 1.
    static let profiles: [TunerProfile] = [
        .init("Zhongruan", TunerProfile.chineseFamily, [43, 50, 55, 62]),
        .init("Daruan", TunerProfile.chineseFamily, [38, 45, 50, 57]),
        .init("Xiaoruan", TunerProfile.chineseFamily, [50, 57, 62, 69]),
        .init("Gaoyinruan", TunerProfile.chineseFamily, [55, 62, 67, 74]),
        .init("Diyinruan", TunerProfile.chineseFamily, [31, 38, 43, 50]),
    ]

    static func forInstrument(_ id: String, stringCount: Int = 4) -> Self? {
        guard stringCount == 4, profiles.contains(where: { $0.id == id }) else { return nil }
        return Self()
    }

    private struct Peg {
        let post: CGPoint
        let nutX: CGFloat
        let side: CGFloat

        var key: CGPoint { CGPoint(x: 538 + side * 361, y: post.y) }
        var left: Bool { side < 0 }
    }

    // The front-view 2+2 drawing follows the approved ruyi silhouette. The hidden
    // winding is behind the cap. Each string stops on the edge of that cap.
    private static let pegs: [Peg] = [
        .init(post: CGPoint(x: 468, y: 741), nutX: 460, side: -1),
        .init(post: CGPoint(x: 496, y: 542), nutX: 510, side: -1),
        .init(post: CGPoint(x: 583, y: 621), nutX: 566, side: 1),
        .init(post: CGPoint(x: 618, y: 849), nutX: 610, side: 1),
    ]

    private static let transform = CGAffineTransform(a: 0.238, b: 0, c: 0, d: 0.238, tx: 52, ty: -21)
    private static let nutY: CGFloat = 1011
    private static let endY: CGFloat = 1400
    private static let postRadius: CGFloat = 20

    private static let profile = Path(tunerCommands: """
        M 418 478 L 399 973 Q 397 995 405 1011 L 405 1036
        C 423 1057 438 1091 438 1124 L 438 1400 L 638 1400 L 638 1124
        C 638 1094 653 1059 671 1036 L 671 1011 Q 680 994 676 971 L 650 479
        M 538 123 C 563 123 566 148 615 152 Q 653 153 668 181
        C 679 205 711 197 715 230 C 721 254 706 286 707 311
        C 706 350 733 386 717 414 C 711 430 690 431 682 450
        Q 673 477 647 478 C 609 480 573 488 548 513 Q 538 523 528 513
        C 503 488 467 480 429 478 Q 403 477 394 450
        C 386 431 365 430 359 414 C 343 386 370 350 369 311
        C 370 286 355 254 361 230 C 365 197 397 205 408 181
        Q 423 153 461 152 C 510 148 513 123 538 123 Z
        """)
    private static let fittings = Path(tunerCommands: """
        M 438 1177 L 638 1177 M 438 1191 L 638 1191
        """)
    private static let nut = Path(tunerCommands: """
        M 405 1011 Q 398 1011 398 1018 L 398 1029 Q 398 1036 405 1036
        L 671 1036 Q 678 1036 678 1029 L 678 1018 Q 678 1011 671 1011 Z
        """)
    private static let handle = Path(tunerCommands: """
        M 117 -19 C 207 -24 331 -61 431 -54 C 473 -51 483 -30 483 0
        C 483 30 473 51 431 54 C 331 61 207 24 117 19
        Q 106 19 106 10 L 106 -10 Q 106 -19 117 -19 Z
        """)
    private static let endCap = Path(tunerCommands: "M 448 -50 C 462 -37 462 37 448 50")
    private static let collar = Path(tunerCommands: "M 140 -20 Q 148 -18 148 -11 L 148 11 Q 148 18 140 20")

    var isHeadless: Bool { false }
    var stringHitHeight: CGFloat { 44 }

    var positions: [TunerHeadstock.StringPosition] {
        Self.pegs.map { peg in
            let key = peg.key.applying(Self.transform)
            return .init(post: peg.post.applying(Self.transform), key: key,
                         nutX: CGPoint(x: peg.nutX, y: 0).applying(Self.transform).x,
                         label: CGPoint(x: peg.left ? 35 : 325, y: key.y), left: peg.left)
        }
    }

    func draw(in context: GraphicsContext, surface: Color, drawing: TunerStringDrawing) {
        Self.render(in: context, transform: Self.transform, ink: drawing.outline,
                    picker: false, drawing: drawing)
    }

    static func pickerIcon(_ p: InstrumentPalette, selected: Bool) -> some View {
        Canvas { context, size in
            let scale = size.height / 1350
            let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                              tx: size.width / 2 - 538 * scale, ty: -86 * scale)
            render(in: context, transform: transform, ink: selected ? Color(hex: 0xF5F0E2) : p.ink, picker: true)
        }
        .frame(width: 35, height: 32)
    }

    var referenceWires: [Path] { Self.pegs.map { Self.stringPath(for: $0, picker: false).applying(Self.transform) } }

    private static func stringPath(for peg: Peg, picker: Bool) -> Path {
        Path { path in
            path.move(to: CGPoint(x: peg.nutX, y: endY))
            if picker {
                path.addLine(to: CGPoint(x: peg.nutX, y: 1100))
            } else {
                path.addLine(to: CGPoint(x: peg.nutX, y: nutY))
                let dx = peg.nutX - peg.post.x, dy = nutY - peg.post.y
                let scale = postRadius / hypot(dx, dy)
                path.addLine(to: CGPoint(x: peg.post.x + dx * scale, y: peg.post.y + dy * scale))
            }
        }
    }

    private static func render(in context: GraphicsContext, transform: CGAffineTransform, ink: Color,
                               picker: Bool, drawing: TunerStringDrawing? = nil) {
        func stroke(_ path: Path, color: Color, width: CGFloat, in canvas: GraphicsContext? = nil) {
            (canvas ?? context).stroke(path.applying(transform), with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }

        let width: CGFloat = picker ? 0.65 : 1.32
        stroke(profile, color: ink, width: width)
        if !picker {
            stroke(fittings, color: ink, width: 1)
            stroke(nut, color: ink, width: 1.02)
        }

        var outside = context
        outside.clip(to: profile.applying(transform), options: .inverse)
        for index in drawing?.paintOrder(pegs.indices) ?? Array(pegs.indices) {
            let peg = pegs[index]
            let color = drawing?.color(for: index) ?? ink
            let placement = CGAffineTransform(a: peg.side, b: 0, c: 0, d: 1, tx: 538, ty: peg.post.y)
            stroke(handle.applying(placement), color: color, width: width, in: outside)
            if !picker {
                stroke(endCap.applying(placement), color: color, width: 0.9)
                stroke(collar.applying(placement), color: color, width: 0.82, in: outside)
            }

            let cap = CGRect(x: peg.post.x - postRadius, y: peg.post.y - postRadius,
                             width: postRadius * 2, height: postRadius * 2)
            let string = stringPath(for: peg, picker: picker)
            let normal = 1.04 - 0.08 * CGFloat(index)
            stroke(string, color: color,
                   width: picker ? 0.37 : drawing?.lineWidth(for: index, normal: normal, focused: 1.65) ?? normal)
            if !picker { stroke(Path(ellipseIn: cap), color: color, width: 1.13) }
        }
    }
}
