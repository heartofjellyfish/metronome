import SwiftUI

struct TunerArtworkRelief {
    let palette: InstrumentPalette

    private var face: Gradient {
        Gradient(colors: palette.dark ? [palette.top, palette.body]
                                      : [Color(hex: 0xF1ECE3), Color(hex: 0xE8E2D8)])
    }

    var ridge: Color { .white.opacity(palette.dark ? 0.12 : 0.67) }
    var edge: Color { palette.ink.opacity(palette.dark ? 0.23 : 0.32) }

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
        edgeLayer.stroke(shape.applying(inset), with: .color(ridge), style: style)
    }

    func raised(_ shape: Path, in context: GraphicsContext, height: CGFloat = 1) {
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(palette.dark ? 0.41 : 0.22),
                                    radius: 1.65 * height, x: height, y: 1.65 * height))
            fill(shape, in: layer)
        }
        context.stroke(shape, with: .color(edge.opacity(0.58)),
                       style: StrokeStyle(lineWidth: 0.72, lineCap: .round, lineJoin: .round))
        bevel(shape, in: context)
    }

    func recess(_ shape: Path, in context: GraphicsContext) {
        let bounds = shape.boundingRect
        let woodInShade = Color(hex: palette.dark ? 0x302D29 : 0xAAA298)
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
