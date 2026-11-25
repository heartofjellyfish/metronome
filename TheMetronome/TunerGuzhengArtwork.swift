import SwiftUI

/// Player's view: the S-shaped rear bridge is on the left and the tuning box is on the right.
enum TunerGuzhengArtwork {
    static let size = CGSize(width: 540, height: 156)
    static let stringCount = 21

    private static let farRim: CGFloat = 16
    private static let nearRim: CGFloat = 140
    static let frontBridgeX: CGFloat = 466
    private static let tuningHoleX: CGFloat = 480
    private static let pinWallX: CGFloat = 494
    private static let tailFarX: CGFloat = 51
    private static let tailNearX: CGFloat = 144
    private static let stringSpacing: CGFloat = 5.35
    private static let playingCropLengthCm: CGFloat = 34

    // Representative bridge spacing for a full-size guzheng, ordered from string 1.
    private static let bridgeDistances: [CGFloat] = [
        15, 17.5, 20, 22.7, 25.3, 28, 30.4, 33, 35.6, 38.3, 40.9,
        43.3, 46, 49, 52, 55, 58.5, 62, 68, 73, 79
    ]

    struct Course {
        let tailHole: CGPoint
        let bridge: CGPoint
        let tuningHole: CGPoint
        let tuningPin: CGPoint
        let lineWidth: CGFloat
    }

    static func course(at index: Int) -> Course {
        // String 1 is closest to the player and belongs at the bottom.
        let row = CGFloat(stringCount - 1 - index)
        let y = 24 + stringSpacing * row
        let t = (y - farRim) / (nearRim - farRim)
        let tail = tailFarX + (tailNearX - tailFarX) * t * t * (3 - 2 * t)
        return Course(tailHole: CGPoint(x: tail + 6, y: y),
                      bridge: CGPoint(x: frontBridgeX - bridgeDistances[index] * 3.85, y: y),
                      tuningHole: CGPoint(x: tuningHoleX, y: y),
                      tuningPin: CGPoint(x: pinWallX, y: y),
                      lineWidth: 0.83 + 0.131 * CGFloat(index))
    }

    static func string(at point: CGPoint, in frame: CGRect) -> Int? {
        let x = (point.x - frame.minX) * size.width / frame.width
        let y = (point.y - frame.minY) * size.height / frame.height
        let row = Int(((y - course(at: stringCount - 1).tailHole.y) / stringSpacing).rounded())
        guard (0..<stringCount).contains(row) else { return nil }
        let index = stringCount - 1 - row
        let string = course(at: index)
        return (string.tailHole.x...string.tuningHole.x).contains(x) ? index : nil
    }

    private static let outline = Path(tunerCommands: """
        M 42 16 L 506 16 Q 535 16 535 30 L 535 126 Q 535 140 506 140 L 42 140
        C 19 140 5 113 5 78 C 5 43 19 16 42 16 Z
        """)

    private static let tailBridge = Path { path in
        let step = (nearRim - farRim) / 3
        path.move(to: CGPoint(x: tailFarX, y: farRim))
        path.addCurve(to: CGPoint(x: tailNearX, y: nearRim),
                      control1: CGPoint(x: tailFarX, y: farRim + step),
                      control2: CGPoint(x: tailNearX, y: nearRim - step))
    }

    private static let saddle = Path(tunerCommands: """
        M -2.6 -4.5 Q 0 -5.8 2.6 -4.5 L 3.2 4.5 Q 0 5.8 -3.2 4.5 Z
        """)

    private static let shaft = Path(tunerCommands: """
        M 0 -5 L 17 -5 L 20 -3.7 L 27 -3.7 L 29 -2 L 29 2 L 27 3.7 L 20 3.7 L 17 5 L 0 5 Z
        """)

    private static let shaftDetails = Path(tunerCommands: """
        M 20 -3.7 L 20 3.7
        M 25 -3.7 L 25 3.7
        """)

    private static let winding = Path(tunerCommands: """
        M 4 -5.6 C 6 -2 6 2 4 5.6 M 7.2 -5.6 C 9.2 -2 9.2 2 7.2 5.6
        """)

    static func drawOverview(in context: GraphicsContext, frame: CGRect, surface: Color, drawing: TunerStringDrawing) {
        let xScale = frame.width / size.width
        let yScale = frame.height / size.height
        let placement = CGAffineTransform(a: xScale, b: 0, c: 0, d: yScale, tx: frame.minX, ty: frame.minY)
        let ink = drawing.outline
        context.stroke(outline.applying(placement), with: .color(ink), lineWidth: 1.05)
        context.stroke(tailBridge.applying(placement), with: .color(ink.opacity(0.90)), lineWidth: 1.12)

        let top = frame.minY + farRim * yScale
        let bottom = frame.minY + nearRim * yScale
        for x in [frontBridgeX, pinWallX] {
            let rail = verticalLine(x: frame.minX + x * xScale, top: top, bottom: bottom)
            context.stroke(rail, with: .color(ink.opacity(0.67)), lineWidth: 0.68)
        }

        for index in drawing.paintOrder(0..<stringCount) {
            let course = course(at: index)
            let start = course.tailHole.applying(placement)
            let bridge = course.bridge.applying(placement)
            let hole = course.tuningHole.applying(placement)
            let color = stringInk(index, drawing: drawing)
            strokeString(from: start, to: hole, width: course.lineWidth * 0.42,
                         ink: .color(color), in: context)
            drawContact(at: start, diameter: 1.65, lineWidth: 0.48, ink: color, surface: surface, in: context)
            drawSaddle(at: bridge, scale: CGSize(width: 0.54, height: 0.23),
                       ink: color, surface: surface, in: context)
            drawContact(at: hole, diameter: 1.65, lineWidth: 0.48, ink: color, surface: surface, in: context)
        }
    }

    static func drawDetail(in context: GraphicsContext, frame: CGRect, wires: Range<Int>,
                           firstWireY: CGFloat, rowHeight: CGFloat, surface: Color, drawing: TunerStringDrawing) {
        let showsFarRim = wires.upperBound == stringCount
        let showsNearRim = wires.lowerBound == 0
        let hardwareScale = frame.width / 402
        let right = frame.maxX
        // With the cover open, leave room for the wrench beyond the pin heads.
        let pinX = right - frame.width * 0.18
        let front = pinX - (pinWallX - frontBridgeX) * hardwareScale
        let holeX = pinX - (pinWallX - tuningHoleX) * hardwareScale
        let bridgeScale = (front - frame.minX) / playingCropLengthCm
        let top = frame.minY
        let bottom = frame.maxY
        let ink = drawing.outline.opacity(0.78)
        let bodyStroke: GraphicsContext.Shading = .linearGradient(
            Gradient(stops: [
                .init(color: showsFarRim ? ink : ink.opacity(0), location: 0),
                .init(color: ink, location: 0.12),
                .init(color: ink, location: 0.88),
                .init(color: showsNearRim ? ink : ink.opacity(0), location: 1)
            ]),
            startPoint: CGPoint(x: front, y: top),
            endPoint: CGPoint(x: front, y: bottom)
        )
        let radius: CGFloat = 7
        let rim = Path { path in
            path.move(to: CGPoint(x: right - (showsFarRim ? radius : 0), y: top))
            if showsFarRim {
                path.addQuadCurve(to: CGPoint(x: right, y: top + radius), control: CGPoint(x: right, y: top))
            }
            path.addLine(to: CGPoint(x: right, y: bottom - (showsNearRim ? radius : 0)))
            if showsNearRim {
                path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom), control: CGPoint(x: right, y: bottom))
            }
        }
        context.stroke(rim, with: bodyStroke, lineWidth: 1)
        context.stroke(verticalLine(x: front, top: top, bottom: bottom), with: bodyStroke, lineWidth: 0.78)
        context.stroke(verticalLine(x: pinX, top: top, bottom: bottom), with: bodyStroke, lineWidth: 0.63)
        if showsNearRim || showsFarRim {
            let y = showsFarRim ? top : bottom
            let start = CGPoint(x: frame.minX, y: y)
            let end = CGPoint(x: right - radius, y: y)
            strokeString(from: start, to: end, width: 1, ink: croppedInk(ink, from: start), in: context)
        }

        for index in drawing.paintOrder(wires) {
            let course = course(at: index)
            let y = firstWireY + CGFloat(wires.upperBound - 1 - index) * rowHeight
            let start = CGPoint(x: frame.minX, y: y)
            let hole = CGPoint(x: holeX, y: y)
            let pin = CGPoint(x: pinX, y: y)
            let color = stringInk(index, drawing: drawing)
            strokeString(from: start, to: hole, width: course.lineWidth,
                         ink: croppedInk(color, from: start), in: context)
            if showsNearRim {
                let bridge = CGPoint(x: front - bridgeDistances[index] * bridgeScale, y: y)
                drawSaddle(at: bridge, scale: CGSize(width: 1, height: 1),
                           ink: color, surface: surface, in: context)
            }
            drawContact(at: hole, diameter: 3.4 * hardwareScale, lineWidth: 0.83 * hardwareScale,
                        ink: color, surface: surface, in: context)
            drawTuningPin(at: pin, scale: CGSize(width: hardwareScale, height: 0.72),
                          ink: color, surface: surface, in: context)
        }
    }

    private static func stringInk(_ index: Int, drawing: TunerStringDrawing) -> Color {
        if drawing.auditioning == index || drawing.completed.contains(index) { return drawing.color(for: index) }
        return drawing.palette.ink.opacity(drawing.active == index ? 1 : 0.67)
    }

    private static func verticalLine(x: CGFloat, top: CGFloat, bottom: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
    }

    private static func croppedInk(_ ink: Color, from start: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [ink.opacity(0), ink]), startPoint: start,
                        endPoint: CGPoint(x: start.x + 27, y: start.y))
    }

    private static func strokeString(from start: CGPoint, to end: CGPoint, width: CGFloat,
                                     ink: GraphicsContext.Shading, in context: GraphicsContext) {
        let wire = Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        context.stroke(wire, with: ink, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private static func drawContact(at point: CGPoint, diameter: CGFloat, lineWidth: CGFloat,
                                    ink: Color, surface: Color, in context: GraphicsContext) {
        let contact = Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                            width: diameter, height: diameter))
        context.fill(contact, with: .color(surface))
        context.stroke(contact, with: .color(ink), lineWidth: lineWidth)
    }

    private static func drawSaddle(at bridge: CGPoint, scale: CGSize, ink: Color, surface: Color,
                                   in context: GraphicsContext) {
        let placement = CGAffineTransform(a: scale.width, b: 0, c: 0, d: scale.height, tx: bridge.x, ty: bridge.y)
        let foot = saddle.applying(placement)
        context.fill(foot, with: .color(surface))
        context.stroke(foot, with: .color(ink), lineWidth: 0.72 * scale.width)
        strokeString(from: CGPoint(x: bridge.x - 1.5 * scale.width, y: bridge.y),
                     to: CGPoint(x: bridge.x + 1.5 * scale.width, y: bridge.y),
                     width: 0.66 * scale.width, ink: .color(ink), in: context)
    }

    private static func drawTuningPin(at pin: CGPoint, scale: CGSize, ink: Color, surface: Color,
                                      in context: GraphicsContext) {
        let placement = CGAffineTransform(a: scale.width, b: 0, c: 0, d: scale.height, tx: pin.x, ty: pin.y)
        let body = shaft.applying(placement)
        context.fill(body, with: .color(surface))

        // The run from the hole to the pin turns down behind the front rail.
        // Only the turns around the exposed shaft are visible from above.
        context.stroke(body, with: .color(ink), lineWidth: 1.28 * scale.width)
        context.stroke(shaftDetails.applying(placement), with: .color(ink), lineWidth: 0.93 * scale.width)
        context.stroke(winding.applying(placement), with: .color(ink), lineWidth: 1.05 * scale.width)
    }

    static func pickerIcon(_ palette: InstrumentPalette, selected: Bool) -> some View {
        Canvas { context, size in
            let scale = (size.width - 1) / Self.size.width
            let placement = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                              tx: 0.5, ty: (size.height - Self.size.height * scale) / 2)
            let ink = selected ? palette.tunerDrawingSurface : palette.ink
            context.stroke(outline.applying(placement), with: .color(ink), lineWidth: 0.9)
            context.stroke(tailBridge.applying(placement), with: .color(ink), lineWidth: 0.65)
            let rail = verticalLine(x: frontBridgeX, top: farRim, bottom: nearRim)
            context.stroke(rail.applying(placement), with: .color(ink), lineWidth: 0.65)
            for index in [2, 7, 12, 17] {
                let course = course(at: index)
                strokeString(from: course.tailHole.applying(placement), to: course.tuningHole.applying(placement),
                             width: 0.45, ink: .color(ink), in: context)
            }
        }
    }
}
