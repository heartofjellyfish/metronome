import SwiftUI

enum ChromaticDialGeometry {
    static let diameter: CGFloat = 350
    static let center = CGPoint(x: diameter / 2, y: diameter / 2)
    static let inner: CGFloat = 119
    static let displayDiameter = 2 * (inner - 10.5)
    static let innerRingInner = displayDiameter / 2 + 0.55
    static let innerRingOuter = inner + 0.3
    static let outer: CGFloat = 166
    static let coverInner = inner + 2.5
    static let coverOuter = outer - 1.3
    static let coverSlopeWidth: CGFloat = 5.4
    static let coverSlopeStart = coverOuter - coverSlopeWidth
    static let coverSlopeMiddle = coverOuter - coverSlopeWidth / 2
    static let coverLift = CGPoint(x: 0.72, y: 2.75)
    static let letteringRadius: CGFloat = 142
    static let step = Double.pi / 6
    static let windowOuter = coverSlopeStart - 1.5
    private static let windowInner = inner + 8
    private static let windowHalfWidth = step * (0.5 - ChromaticTuningRange.standard.cents / 100)
    private static let windowCorner = 0.04
    private static let windowLipRise: CGFloat = 1.75

    static func angle(for pitch: Int) -> Double { Double((pitch + 3) % 12) * step }

    static func pointerAngle(note: Int, cents: Double) -> Double {
        let pitch = (note % 12 + 12) % 12
        return angle(for: pitch) + cents * step / 100
    }

    static func nearestAngle(_ angle: Double, to current: Double) -> Double {
        current + (angle - current).remainder(dividingBy: 2 * .pi)
    }

    static func point(at angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + sin(angle) * radius, y: center.y - cos(angle) * radius)
    }

    static func circle(radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    }

    static let innerRing = Path { path in
        path.addPath(circle(radius: innerRingOuter))
        path.addPath(circle(radius: innerRingInner))
    }

    static let gripGrooves = Path { path in
        let count = 96
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            path.move(to: point(at: angle, radius: diameter / 2 - 3.5))
            path.addLine(to: point(at: angle, radius: diameter / 2 - 1.1))
        }
    }

    // The glass is authored at twelve o’clock. Even-odd fill cuts both holes.
    static let glassCoverage = Path { path in
        path.addPath(circle(radius: outer))
        path.addPath(circle(radius: inner))
        path.addPath(glassOpening)
    }

    static let coverCoverage = Path { path in
        path.addPath(circle(radius: coverOuter))
        path.addPath(circle(radius: coverInner))
        path.addPath(glassOpening)
    }

    static let coverSeat = Path { path in
        path.addPath(circle(radius: outer + 2.3))
        path.addPath(circle(radius: inner))
    }

    static let coverShadowSeat = Path { path in
        path.addPath(circle(radius: diameter / 2 - 3.3))
        path.addPath(circle(radius: inner))
    }

    static let coverSidewall: Path = {
        let rim = circle(radius: coverOuter)
        return rim.offsetBy(dx: coverLift.x, dy: coverLift.y).subtracting(rim)
    }()

    static let coverSlope = Path { path in
        path.addPath(circle(radius: coverOuter))
        path.addPath(circle(radius: coverSlopeStart))
    }

    static func glassRotation(by angle: Double) -> CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: angle)
            .translatedBy(x: -center.x, y: -center.y)
    }

    static func windowFill(at angle: Double, progress: Double) -> Path {
        let bottom = windowInner * cos(windowHalfWidth - windowCorner)
        let start = bottom + 3
        let level = start + (windowOuter - start) * progress
        let shape = Path(CGRect(x: -windowOuter, y: -level, width: 2 * windowOuter, height: level))
        return shape.applying(CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle))
    }

    static func sector(at angle: Double, halfWidth: Double, inner: CGFloat, outer: CGFloat) -> Path {
        let start = angle - halfWidth - .pi / 2
        let end = angle + halfWidth - .pi / 2
        return Path { path in
            path.addArc(center: center, radius: outer, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
            path.addLine(to: point(at: angle + halfWidth, radius: inner))
            path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
            path.closeSubpath()
        }
    }

    static func cell(at angle: Double) -> Path {
        sector(at: angle, halfWidth: step / 2, inner: inner, outer: outer)
    }

    static let glassOpening: Path = {
        let left = -windowHalfWidth
        let right = windowHalfWidth
        let corner = windowCorner
        let crown = windowOuter
        let lip = windowInner
        let chordProjection = cos(windowHalfWidth - corner)
        let lipControl = point(at: 0, radius: lip * chordProjection + 2 * windowLipRise)
        return Path { path in
            path.addArc(center: center, radius: crown,
                        startAngle: .radians(left + corner - .pi / 2),
                        endAngle: .radians(right - corner - .pi / 2), clockwise: false)
            path.addQuadCurve(to: point(at: right, radius: crown - 5), control: point(at: right, radius: crown))
            path.addLine(to: point(at: right, radius: lip + 6))
            path.addQuadCurve(to: point(at: right - corner, radius: lip), control: point(at: right, radius: lip))
            path.addQuadCurve(to: point(at: left + corner, radius: lip), control: lipControl)
            path.addQuadCurve(to: point(at: left, radius: lip + 6), control: point(at: left, radius: lip))
            path.addLine(to: point(at: left, radius: crown - 5))
            path.addQuadCurve(to: point(at: left + corner, radius: crown), control: point(at: left, radius: crown))
            path.closeSubpath()
        }
    }()

    static func divider(at angle: Double) -> Path {
        Path { path in
            path.move(to: point(at: angle, radius: inner))
            path.addLine(to: point(at: angle, radius: outer))
        }
    }
}

struct ChromaticDialAperture {
    private typealias Dial = ChromaticDialGeometry

    let angle: Double
    let opening: Path
    let fill: Path?

    init(angle: Double, target: Int?, sustain: ChromaticSustain, fillsGradually: Bool = true) {
        self.angle = angle
        opening = Dial.glassOpening.applying(Dial.glassRotation(by: angle))
        guard sustain.isCentered, fillsGradually || sustain.progress >= 1, let target else {
            fill = nil
            return
        }
        // Any part of the window beyond the target remains clear in the green range.
        let cell = Dial.cell(at: Dial.angle(for: target))
        fill = opening.intersection(cell).intersection(Dial.windowFill(at: angle, progress: sustain.progress))
    }
}

enum ChromaticDialEtching {
    static let openingBlur: CGFloat = 0.50
    static let nearBlur: CGFloat = 0.73
    static let farBlur: CGFloat = 1.42

    private static func falloff(_ delta: Double) -> CGFloat { (1 - cos(delta)) / 2 }

    static func blur(at angle: Double, from openingAngle: Double) -> CGFloat {
        nearBlur + (farBlur - nearBlur) * falloff(angle - openingAngle)
    }

    static func opacityRamp(_ color: Color, near: Double, far: Double, openingAngle: Double = 0) -> GraphicsContext.Shading {
        let colors = (0...8).map { step in
            color.opacity(near + (far - near) * falloff(Double(step) * .pi / 4))
        }
        return .conicGradient(Gradient(colors: colors), center: ChromaticDialGeometry.center,
                              angle: .radians(openingAngle - .pi / 2))
    }

    static func outsideOpening(_ opening: Path, in bounds: CGRect) -> Path {
        var path = Path(bounds)
        path.addPath(opening)
        return path
    }
}

struct ChromaticDialFace<Engravings: View>: View, Animatable {
    typealias Dial = ChromaticDialGeometry

    let style: ChromaticDialStyle
    var angle: Double
    let target: Int?
    let showsPointer: Bool
    let state: IntonationState?
    let sustain: ChromaticSustain
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let engravings: (ChromaticDialAperture) -> Engravings

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let aperture = ChromaticDialAperture(angle: angle, target: target, sustain: sustain,
                                            fillsGradually: style.relief?.dark == true)
        ZStack {
            if style.relief?.dark == true { backlight }
            Circle()
                .fill(LinearGradient(colors: style.bezel, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Circle().strokeBorder(LinearGradient(colors: [style.bezelHighlight, style.bezelHighlight.opacity(0.16)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.95)
                }
                .shadow(color: .black.opacity(style.shadow * 0.52), radius: style.relief == nil ? 9 : 5,
                        y: style.relief == nil ? 6 : 3)
                .shadow(color: .black.opacity(style.shadow), radius: 2.5, y: style.relief == nil ? 3 : 2)
            if let relief = style.relief {
                Canvas { context, _ in
                    context.stroke(Dial.gripGrooves.offsetBy(dx: 0.38, dy: 0.48),
                                   with: .color(relief.highlight.opacity(0.68)), lineWidth: 0.88)
                    context.stroke(Dial.gripGrooves, with: .color(relief.wall.opacity(0.31)), lineWidth: 0.75)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            Circle().inset(by: 4.5)
                .fill(LinearGradient(colors: style.face, startPoint: .topLeading, endPoint: .bottomTrailing))
            if let relief = style.relief {
                ChromaticReliefFace(palette: relief)
                    .equatable()
            } else {
                MaterialGrain()
                    .opacity(0.10)
                    .blendMode(.softLight)
                    .clipShape(Circle().inset(by: 4.5))
            }
            Circle().inset(by: 4.5).strokeBorder(
                LinearGradient(colors: [style.recess[0], style.engraving.opacity(style.relief == nil ? 0.48 : 0.26)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.45)
            Canvas { ctx, _ in
                if style.relief == nil { drawGlassRecess(aperture.opening, in: ctx) }
                drawEngravedDividers(aperture, in: ctx)
                if let fill = aperture.fill, !fill.isEmpty { drawFill(fill, in: ctx) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            engravings(aperture)
            if let relief = style.relief {
                Canvas { context, _ in
                    drawCoverShadow(relief, in: context)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                ChromaticDialCover(palette: relief).equatable()
                    .rotationEffect(.radians(angle))
                ChromaticLinenRelief(palette: relief, angle: angle).equatable()
                ChromaticSustainLamp(progress: sustain.progress, lit: sustain.isCentered, tint: relief.lamp)
                    .animation(sustain.isCentered && !reduceMotion ? .linear(duration: 0.075) : nil,
                               value: sustain.progress)
                    .rotationEffect(.radians(angle))
                ChromaticCoverReflection(angle: angle, palette: relief)
            } else {
                ChromaticDialGlass(style: style, angle: angle)
            }
            Canvas { ctx, _ in
                if showsPointer { drawPointer(at: angle, in: ctx) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var backlight: some View {
        let progress = sustain.progress
        return ZStack {
            RadialGradient(stops: [
                .init(color: .clear, location: 0.76),
                .init(color: style.warmLight.opacity(0.53), location: 0.82),
                .init(color: style.warmLight.opacity(0.18), location: 0.91),
                .init(color: .clear, location: 1)
            ], center: .center, startRadius: 0, endRadius: 219)
            RadialGradient(stops: [
                .init(color: .clear, location: 0.71),
                .init(color: style.sustainLight.opacity(progress * 0.64), location: 0.78),
                .init(color: style.sustainLight.opacity(progress * 0.17), location: 0.91),
                .init(color: .clear, location: 1)
            ], center: .center, startRadius: 0, endRadius: 238)
            .offset(y: 15)
            RadialGradient(colors: [style.sustainLight.opacity(progress * 0.14), .clear],
                           center: .center, startRadius: 16, endRadius: 182)
                .frame(width: 362, height: 200)
                .offset(y: 168)
        }
        .frame(width: 476, height: 476)
        .frame(width: Dial.diameter, height: Dial.diameter)
    }

    private func drawEngravedDividers(_ aperture: ChromaticDialAperture, in ctx: GraphicsContext) {
        let seams = Path { path in
            for index in 0..<12 {
                path.addPath(Dial.divider(at: (Double(index) + 0.5) * Dial.step))
            }
        }
        if let relief = style.relief {
            let bounds = CGRect(origin: .zero, size: CGSize(width: Dial.diameter, height: Dial.diameter))
            var throughGlass = ctx
            throughGlass.clip(to: ChromaticDialEtching.outsideOpening(aperture.opening, in: bounds), style: FillStyle(eoFill: true))
            // Blend two blur radii with complementary ramps to keep the transitions continuous.
            for (radius, near, far) in [(ChromaticDialEtching.nearBlur, 1.0, 0.0),
                                        (ChromaticDialEtching.farBlur, 0.0, 1.0)] {
                var pass = throughGlass
                pass.clipToLayer { mask in
                    mask.fill(Path(bounds), with: ChromaticDialEtching.opacityRamp(.white, near: near, far: far,
                                                                                  openingAngle: aperture.angle))
                }
                drawSoftDividers(seams, highlight: relief.highlight, radius: radius, in: pass)
            }

            var throughOpening = ctx
            throughOpening.clip(to: aperture.opening)
            drawSoftDividers(seams, highlight: relief.highlight, radius: ChromaticDialEtching.openingBlur, in: throughOpening)
        } else {
            ctx.stroke(seams, with: .color(style.engraving.opacity(0.27)), lineWidth: 0.65)
        }
    }

    private func drawSoftDividers(_ seams: Path, highlight: Color, radius: CGFloat, in context: GraphicsContext) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius))
            layer.stroke(seams.offsetBy(dx: 0.45, dy: 0.7), with: .color(highlight.opacity(0.53)), lineWidth: 0.8)
            layer.stroke(seams, with: .color(style.engraving.opacity(0.68)), lineWidth: 0.8)
        }
    }

    private func drawGlassRecess(_ opening: Path, in ctx: GraphicsContext) {
        let bounds = opening.boundingRect
        ctx.fill(opening, with: .linearGradient(Gradient(colors: style.recess),
                                                startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                                                endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
    }

    private func drawCoverShadow(_ relief: ChromaticDialStyle.Relief, in context: GraphicsContext) {
        let silhouette = Dial.coverCoverage.applying(Dial.glassRotation(by: angle))
        let exposedBed = Path { path in
            path.addPath(Dial.coverShadowSeat)
            path.addPath(silhouette)
        }
        let hollow = FillStyle(eoFill: true)
        var bed = context
        bed.clip(to: exposedBed, style: hollow)
        // The ring's sidewall is visible in front of the low, soft shadow on the seat.
        bed.drawLayer { shadow in
            shadow.addFilter(.shadow(color: relief.wall.opacity(0.57), radius: 1.45,
                                     x: Dial.coverLift.x + 0.45, y: Dial.coverLift.y + 0.90, options: .shadowOnly))
            shadow.fill(silhouette, with: .color(.black), style: hollow)
        }
        let wallLight = Gradient(stops: [
            .init(color: relief.cover.opacity(0.88), location: 0),
            .init(color: relief.wall.opacity(0.43), location: 0.48),
            .init(color: relief.wall.opacity(0.58), location: 1)
        ])
        bed.fill(Dial.coverSidewall, with: .linearGradient(wallLight,
                     startPoint: Dial.point(at: -.pi / 3, radius: Dial.coverOuter),
                     endPoint: Dial.point(at: .pi * 2 / 3, radius: Dial.coverOuter)))
    }

    private func drawFill(_ fill: Path, in ctx: GraphicsContext) {
        let bounds = fill.boundingRect
        let colors = style.fill.reversed().map { $0.opacity(style.relief == nil ? 1 : 0.66) }
        ctx.fill(fill, with: .linearGradient(Gradient(colors: colors),
                                             startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                                             endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
    }

    private func drawPointer(at angle: Double, in ctx: GraphicsContext) {
        let radius = style.relief == nil ? Dial.outer : Dial.inner
        let halfWidth = 4 / radius
        let tip = Dial.point(at: angle, radius: radius - 5)
        let tail = Dial.point(at: angle, radius: radius + 4)
        let needle = Path { path in
            path.move(to: tip)
            path.addLine(to: Dial.point(at: angle - halfWidth, radius: radius + 2.6))
            path.addQuadCurve(to: Dial.point(at: angle + halfWidth, radius: radius + 2.6), control: tail)
            path.closeSubpath()
        }
        let tint = style.signal(for: state)
        ctx.stroke(needle, with: .color(style.recess[0].opacity(0.88)),
                   style: StrokeStyle(lineWidth: 1.35, lineJoin: .round))
        ctx.fill(needle, with: .linearGradient(Gradient(colors: [tint, tint.opacity(0.70)]),
                                               startPoint: tail, endPoint: tip))
    }
}

/// The cover and the inner ring turn together around the fixed display.
private struct ChromaticDialCover: View, Equatable {
    private typealias Dial = ChromaticDialGeometry
    let palette: ChromaticDialStyle.Relief

    private static let indexGrooves = Path { path in
        for angle in [Double.pi - 0.029, .pi, .pi + 0.029] {
            path.move(to: Dial.point(at: angle, radius: Dial.outer - 7))
            path.addLine(to: Dial.point(at: angle, radius: Dial.outer - 3))
        }
    }

    var body: some View {
        Canvas { context, _ in
            drawInnerRing(in: context)
            var surface = context
            surface.clip(to: Dial.coverCoverage, style: FillStyle(eoFill: true))
            surface.fill(Dial.circle(radius: Dial.coverOuter),
                         with: ChromaticDialEtching.opacityRamp(palette.cover, near: palette.dark ? 0.25 : 0.48, far: palette.dark ? 0.48 : 0.74))
            surface.stroke(Dial.circle(radius: Dial.coverOuter - 0.35),
                           with: .color(palette.wall.opacity(0.46)), lineWidth: 0.85)
            surface.stroke(Dial.circle(radius: Dial.coverOuter - 0.55),
                           with: .color(palette.highlight.opacity(0.20)), lineWidth: 0.7)
            surface.stroke(Dial.circle(radius: Dial.coverInner + 0.45),
                           with: .color(palette.highlight.opacity(0.31)), lineWidth: 0.85)
            surface.stroke(Dial.glassOpening, with: .color(palette.highlight.opacity(0.42)), lineWidth: 1.5)
            surface.stroke(Self.indexGrooves.offsetBy(dx: 0.34, dy: 0.48),
                           with: .color(palette.highlight.opacity(0.72)), lineWidth: 0.95)
            surface.stroke(Self.indexGrooves, with: .color(palette.wall.opacity(0.56)), lineWidth: 0.8)

            var wall = context
            wall.clip(to: Dial.glassOpening)
            wall.stroke(Dial.glassOpening, with: .color(palette.wall.opacity(0.46)), lineWidth: 5.1)
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .overlay {
            MaterialGrain()
                .opacity(0.065)
                .blendMode(.softLight)
                .mask { Dial.coverCoverage.fill(style: FillStyle(eoFill: true)) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawInnerRing(in context: GraphicsContext) {
        let hollow = FillStyle(eoFill: true)
        context.fill(Dial.innerRing, with: .color(palette.linen), style: hollow)
        var linen = context
        linen.clip(to: Dial.innerRing, style: hollow)
        linen.concatenate(Dial.glassRotation(by: .pi / 10))
        linen.opacity = 0.47
        linen.blendMode = .luminosity
        linen.draw(linen.resolve(Image(decorative: "ChromaticFlax")),
                   in: CGRect(x: 0, y: 0, width: Dial.diameter, height: Dial.diameter))

        // The fabric catches light at the outer shoulder and falls into the screen recess.
        let slope = Gradient(stops: [
            .init(color: palette.wall.opacity(0.40), location: 0),
            .init(color: palette.wall.opacity(0.20), location: 0.20),
            .init(color: palette.wall.opacity(0.06), location: 0.49),
            .init(color: palette.highlight.opacity(0.09), location: 0.72),
            .init(color: palette.highlight.opacity(0.39), location: 1)
        ])
        context.fill(Dial.innerRing, with: .radialGradient(slope, center: Dial.center,
                                                          startRadius: Dial.innerRingInner, endRadius: Dial.innerRingOuter),
                     style: hollow)
    }
}

/// The cut marks turn with the linen while the light stays fixed above the dial.
private struct ChromaticLinenRelief: View, Equatable {
    private typealias Dial = ChromaticDialGeometry
    let palette: ChromaticDialStyle.Relief
    let angle: Double

    private static let ticks = Path { path in
        for index in 1..<60 {
            let angle = Double(index) * Dial.step / 5
            let length: CGFloat = index.isMultiple(of: 5) ? 3.8 : 2.0
            path.move(to: Dial.point(at: angle, radius: Dial.inner - 3.4))
            path.addLine(to: Dial.point(at: angle, radius: Dial.inner - 3.4 - length))
        }
    }
    private static let openingTick = Path { path in
        path.move(to: Dial.point(at: 0, radius: Dial.inner - 3.2))
        path.addLine(to: Dial.point(at: 0, radius: Dial.inner - 7.35))
    }
    private static let tickCuts = ticks.strokedPath(StrokeStyle(lineWidth: 1.22, lineCap: .round))
    private static let openingCut = openingTick.strokedPath(StrokeStyle(lineWidth: 1.52, lineCap: .round))

    var body: some View {
        Canvas { context, _ in
            let light = Gradient(stops: [
                .init(color: palette.wall.opacity(0.24), location: 0),
                .init(color: .clear, location: 0.55),
                .init(color: palette.highlight.opacity(0.32), location: 1)
            ])
            context.fill(Dial.innerRing, with: .linearGradient(light,
                         startPoint: Dial.point(at: -.pi / 5, radius: Dial.innerRingOuter),
                         endPoint: Dial.point(at: .pi * 4 / 5, radius: Dial.innerRingOuter)),
                         style: FillStyle(eoFill: true))
            let rotation = Dial.glassRotation(by: angle)
            engrave(Self.ticks, inside: Self.tickCuts, rotation: rotation, in: context)
            engrave(Self.openingTick, inside: Self.openingCut, rotation: rotation, in: context)
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func engrave(_ marks: Path, inside cuts: Path, rotation: CGAffineTransform, in context: GraphicsContext) {
        let pockets = cuts.applying(rotation)
        let guides = marks.applying(rotation)
        context.fill(pockets, with: .color(palette.wall.opacity(0.27)))
        var recess = context
        recess.clip(to: pockets)
        recess.stroke(guides.offsetBy(dx: -0.28, dy: -0.39), with: .color(palette.graduation.opacity(0.57)),
                      style: StrokeStyle(lineWidth: 1.05, lineCap: .round))
        recess.stroke(guides.offsetBy(dx: 0.31, dy: 0.43), with: .color(palette.highlight.opacity(0.64)),
                      style: StrokeStyle(lineWidth: 0.82, lineCap: .round))
    }
}

/// Sustain light grows in both directions from the slot until the ring closes.
private struct ChromaticSustainLamp: View, Animatable {
    private typealias Dial = ChromaticDialGeometry
    private static let track = arc(progress: 1)

    var progress: Double
    let lit: Bool
    let tint: Color

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            context.stroke(Self.track, with: .color(.black.opacity(0.08)), lineWidth: 0.75)
            if lit && progress > 0 {
                let litArc = Self.arc(progress: progress)
                var glow = context
                glow.addFilter(.blur(radius: 1.05))
                glow.stroke(litArc, with: .color(tint.opacity(0.37)),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                context.stroke(litArc, with: .color(tint),
                               style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            }
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func arc(progress: Double) -> Path {
        let radius = Dial.innerRingInner + 1
        if progress >= 1 { return Dial.circle(radius: radius) }
        let spread = 180 * progress
        return Path { path in
            path.addArc(center: Dial.center, radius: radius, startAngle: .degrees(-90 - spread),
                        endAngle: .degrees(-90 + spread), clockwise: false)
        }
    }
}

/// The screen and its recessed ceramic seat stay fixed under the rotating rings.
private struct ChromaticReliefFace: View, Equatable {
    private typealias Dial = ChromaticDialGeometry

    let palette: ChromaticDialStyle.Relief

    var body: some View {
        ZStack {
            Canvas { context, _ in
                context.fill(Dial.coverSeat, with: .color(palette.ceramic), style: FillStyle(eoFill: true))
                drawMedallion(in: context)
            }
            MaterialGrain()
                .opacity(0.19)
                .blendMode(.softLight)
                .clipShape(Circle().inset(by: 4.5))
            Color.clear
                .frame(width: Dial.displayDiameter, height: Dial.displayDiameter)
                .insetPanel(InstrumentPalette(dark: palette.dark), shape: Circle(), fill: palette.display)
                .overlay {
                    Circle().strokeBorder(palette.wall.opacity(0.66), lineWidth: 0.95)
                }
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawMedallion(in context: GraphicsContext) {
        let face = Dial.circle(radius: Dial.inner)
        var raised = context
        raised.addFilter(.shadow(color: palette.wall.opacity(0.47), radius: 1.15, x: 0.65, y: 1.35))
        raised.fill(face, with: .color(palette.ceramic))
    }
}
