import SwiftUI

/// Applies a common relief material to instrument paths in their own drawing coordinates.
struct TunerArtworkRelief {
    let palette: InstrumentPalette

    private var face: Gradient {
        Gradient(colors: palette.dark ? [Color(hex: 0x5A5B58), Color(hex: 0x171919)]
                                      : [Color(hex: 0xEAE2D4), Color(hex: 0xDED5C7)])
    }

    var ridge: Color { .white.opacity(palette.dark ? 0.40 : 0.57) }
    var edge: Color { palette.dark ? .black.opacity(0.50) : palette.ink.opacity(0.32) }
    var socketEdge: Color { palette.dark ? .black.opacity(0.38) : palette.ink.opacity(0.62) }

    private func fill(_ shape: Path, in context: GraphicsContext) {
        let bounds = shape.boundingRect
        context.fill(shape, with: .linearGradient(face,
                     startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                     endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
    }

    func bevel(_ shape: Path, in context: GraphicsContext, width: CGFloat = 1.1) {
        var edgeLayer = context
        edgeLayer.clip(to: shape)
        let inset = CGAffineTransform(translationX: width * 0.55, y: width * 0.65)
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        edgeLayer.stroke(shape.applying(inset.inverted()), with: .color(edge), style: style)
        if palette.dark {
            let bounds = shape.boundingRect
            let reflection = Gradient(stops: [
                .init(color: .white.opacity(0.38), location: 0),
                .init(color: .white.opacity(0.12), location: 0.36),
                .init(color: .clear, location: 0.64)
            ])
            edgeLayer.stroke(shape.applying(inset), with: .linearGradient(reflection,
                startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)), style: style)
        } else {
            edgeLayer.stroke(shape.applying(inset), with: .color(ridge), style: style)
        }
    }

    // Reuse a fixed patch of short, tapered-looking grain on the instrument drawing canvas.
    private static let grain: Path = {
        var path = Path()
        var seed: UInt32 = 263
        func unit() -> CGFloat {
            seed = seed &* 1664525 &+ 1013904223
            return CGFloat(seed) / CGFloat(UInt32.max)
        }
        for _ in 0..<2400 {
            let x = unit() * 360, y = unit() * 370
            let length = 0.7 + unit() * 3.5
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + length * 0.08, y: y - length))
        }
        return path
    }()

    func raisedBody(_ shape: Path, in context: GraphicsContext) {

        let bounds = shape.boundingRect
        let sideWall = shape.applying(CGAffineTransform(translationX: 0, y: 1.35))
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.24), radius: 3.7, x: 0.6, y: 3.0,
                                    options: .shadowOnly))
            layer.fill(sideWall, with: .color(.black))
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.20), radius: 1.55, x: -0.2, y: 0.9))
            layer.fill(sideWall, with: .linearGradient(
                Gradient(colors: [Color(hex: palette.dark ? 0x262B2C : 0xD3CABB), Color(hex: palette.dark ? 0x0B0D0E : 0xA59885)]),
                startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
            ))
        }

        if palette.dark {
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x393937), Color(hex: 0x222322), Color(hex: 0x111212)]),
                startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
        } else {
            fill(shape, in: context)
        }
        var rim = context
        rim.clip(to: shape)
        if palette.dark {
            rim.stroke(Self.grain, with: .color(.white.opacity(0.045)), lineWidth: 0.24)
        }
        let crownLight = Gradient(stops: [
            .init(color: .white.opacity(palette.dark ? 0.75 : 0.92), location: 0),
            .init(color: .white.opacity(palette.dark ? 0.28 : 0.55), location: 0.14),
            .init(color: .white.opacity(palette.dark ? 0.025 : 0.12), location: 0.38)
        ])
        let crownStart = CGPoint(x: palette.dark ? bounds.minX : bounds.midX, y: bounds.minY)
        let crownEnd = CGPoint(x: palette.dark ? bounds.maxX : bounds.midX,
                               y: palette.dark ? bounds.minY + bounds.width * 0.5 : bounds.maxY)
        rim.stroke(shape.applying(CGAffineTransform(translationX: 0, y: 0.55)),
                   with: .linearGradient(crownLight, startPoint: crownStart, endPoint: crownEnd),
                   style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
    }

    func raisedNut(_ shape: Path, in context: GraphicsContext) {

        let bounds = shape.boundingRect
        let upper = CGPoint(x: bounds.midX, y: bounds.minY)
        let lower = CGPoint(x: bounds.midX, y: bounds.maxY)
        let sideWall = shape.applying(CGAffineTransform(translationX: 0, y: 0.85))
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.38), radius: 1.65, x: 0, y: 1.4))
            layer.fill(sideWall, with: .color(Color(hex: palette.dark ? 0x191C1D : 0xAA9F8E)))
        }
        context.fill(shape, with: .linearGradient(
            Gradient(colors: [Color(hex: palette.dark ? 0x757B7B : 0xF2EBDD), Color(hex: palette.dark ? 0x373C3D : 0xDAD1C2)]),
            startPoint: upper, endPoint: lower
        ))
        var edgeLight = context
        edgeLight.clip(to: shape)
        edgeLight.stroke(shape.applying(CGAffineTransform(translationX: 0, y: 0.55)),
                         with: .linearGradient(Gradient(colors: [.white.opacity(palette.dark ? 0.54 : 0.94), .clear]),
                                               startPoint: upper, endPoint: lower),
                         style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
    }

    func raised(_ shape: Path, in context: GraphicsContext, height: CGFloat = 1) {
        if !palette.dark, height >= 0.65 {
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.20), radius: 3.3 * height,
                                        x: 0.1 * height, y: 3.1 * height, options: .shadowOnly))
                layer.fill(shape, with: .color(.black))
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(palette.dark ? 0.41 : 0.31),
                                    radius: 1.65 * height, x: height, y: 1.65 * height))
            fill(shape, in: layer)
        }
        if !palette.dark {
            context.stroke(shape, with: .color(edge.opacity(0.58)),
                           style: StrokeStyle(lineWidth: 0.72, lineCap: .round, lineJoin: .round))
        }
        bevel(shape, in: context)
    }

    func shaftReflection(_ shape: Path, in context: GraphicsContext) {
        guard palette.dark else { return }
        let bounds = shape.boundingRect
        context.fill(shape, with: .linearGradient(Gradient(stops: [
            .init(color: .black.opacity(0.24), location: 0),
            .init(color: .white.opacity(0.47), location: 0.27),
            .init(color: .white.opacity(0.08), location: 0.50),
            .init(color: .black.opacity(0.32), location: 1)
        ]), startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
            endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
    }

    func recess(_ shape: Path, in context: GraphicsContext) {
        let bounds = shape.boundingRect
        let woodInShade = Color(hex: palette.dark ? 0x121514 : 0xAAA298)
        context.fill(shape, with: .color(woodInShade))
        let throatShade = Gradient(colors: [.black.opacity(palette.dark ? 0.22 : 0.17), .clear])
        context.fill(shape, with: .linearGradient(throatShade,
                     startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                     endPoint: CGPoint(x: bounds.midX, y: bounds.minY + 34)))
        var inside = context
        inside.clip(to: shape)
        let occluder = Path { path in
            path.addRect(bounds.insetBy(dx: -12, dy: -12))
            path.addPath(shape)
        }
        inside.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(palette.dark ? 0.70 : 0.53),
                                    radius: 3.1, x: 1.15, y: 2.7, options: .shadowOnly))
            layer.fill(occluder, with: .color(.black), style: FillStyle(eoFill: true))
        }
        let lowerLip = Path { path in
            path.move(to: CGPoint(x: bounds.minX + 1.2, y: bounds.maxY + 0.45))
            path.addLine(to: CGPoint(x: bounds.maxX - 1.2, y: bounds.maxY + 0.45))
        }
        context.stroke(lowerLip, with: .color(ridge.opacity(0.36)), lineWidth: 0.7)
    }
}
