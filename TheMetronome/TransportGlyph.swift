import SwiftUI

/// One contour throughout the transition: no symbol replacement or overlapping layers.
struct TransportGlyph: View {
    let playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TransportContour(progress: playing ? 1 : 0)
            .fill()
            .frame(width: 34, height: 34)
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.12), value: playing)
            .accessibilityHidden(true)
    }
}

struct TransportContour: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(1, max(0, progress))
        // The triangle is optically centered; the square is slightly smaller for equal visual weight.
        let play: [CGPoint] = [.init(x: 0.20, y: 0.04), .init(x: 0.98, y: 0.50),
                               .init(x: 0.98, y: 0.50), .init(x: 0.20, y: 0.96)]
        let stop: [CGPoint] = [.init(x: 0.12, y: 0.12), .init(x: 0.88, y: 0.12),
                               .init(x: 0.88, y: 0.88), .init(x: 0.12, y: 0.88)]
        var points = zip(play, stop).map { a, b in
            CGPoint(x: rect.minX + (a.x + (b.x - a.x) * t) * rect.width,
                    y: rect.minY + (a.y + (b.y - a.y) * t) * rect.height)
        }
        if t < 0.0001 { points.remove(at: 2) }
        var path = Path()
        for i in points.indices {
            let previous = points[(i + points.count - 1) % points.count]
            let corner = points[i]
            let next = points[(i + 1) % points.count]
            func inset(toward other: CGPoint) -> CGPoint {
                let dx = other.x - corner.x, dy = other.y - corner.y
                let distance = hypot(dx, dy)
                let fraction = distance > 0 ? min(1.4 / distance, 0.45) : 0
                return CGPoint(x: corner.x + dx * fraction, y: corner.y + dy * fraction)
            }
            let entry = inset(toward: previous), exit = inset(toward: next)
            if i == 0 { path.move(to: entry) } else { path.addLine(to: entry) }
            path.addQuadCurve(to: exit, control: corner)
        }
        path.closeSubpath()
        return path
    }
}
