import CoreMotion
import SwiftUI
import simd

/// The glass and its cutout turn over the engraved scale as a single part.
struct ChromaticDialGlass: View {
    private typealias Dial = ChromaticDialGeometry
    let style: ChromaticDialStyle
    let angle: Double

    var body: some View {
        ChromaticDialLighting { light in
            let position = lightPosition(tilt: light.tilt)
            ZStack {
                ChromaticGlassPlate(style: style)
                    .equatable()
                    .rotationEffect(.radians(angle))
                Canvas { ctx, _ in drawReflection(in: ctx, light: position) }
            }
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func lightPosition(tilt: SIMD2<Double>) -> CGPoint {
        let azimuth = -.pi / 3 + tilt.x * 1.28 + tilt.y * 0.38
        let radius = Dial.outer - 10 + tilt.y * 16
        return Dial.point(at: azimuth, radius: radius)
    }

    private func drawReflection(in ctx: GraphicsContext, light: CGPoint) {
        var reflection = ctx
        reflection.clip(to: Dial.glassCoverage.applying(Dial.glassRotation(by: angle)), style: FillStyle(eoFill: true))
        reflection.fill(Dial.circle(radius: Dial.outer), with: .radialGradient(
            Gradient(colors: [style.glassGlint.opacity(0.13), style.glassGlint.opacity(0.04), .clear]),
            center: light, startRadius: 0, endRadius: 92
        ))
        let edgeLight = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [style.glassGlint.opacity(0.68), style.glassGlint.opacity(0.13), .clear]),
            center: light, startRadius: 2, endRadius: 100
        )
        reflection.stroke(Dial.circle(radius: Dial.outer - 1.4), with: edgeLight, lineWidth: 1.15)
        reflection.stroke(Dial.circle(radius: Dial.inner + 0.65), with: edgeLight, lineWidth: 0.8)
    }
}

/// Positions in the dial plane, in units of its cover radius.
private struct ChromaticLightPose: Equatable {
    var tilt = SIMD2<Double>.zero
    var lamp = SIMD3<Double>(-0.83, -0.92, 2.10)
    var eye = SIMD3<Double>(0, 0, 4.7)

    func relativeTo(_ rotation: simd_quatd) -> Self {
        // Core Motion's Y points up; the dial canvas's Y points down.
        let lamp = rotation.inverse.act(self.lamp * SIMD3(1, -1, 1)) * SIMD3(1, -1, 1)
        let eye = rotation.inverse.act(self.eye * SIMD3(1, -1, 1)) * SIMD3(1, -1, 1)
        let normal = rotation.act(SIMD3(0, 0, 1))
        let tilt = simd_clamp(SIMD2(normal.x, normal.y) * 2, SIMD2(repeating: -1), SIMD2(repeating: 1))
        return Self(tilt: tilt, lamp: lamp, eye: eye)
    }

    mutating func follow(_ target: Self) {
        if simd_length_squared(target.lamp - lamp) > 0.000025
            || simd_length_squared(target.eye - eye) > 0.000025
            || simd_length_squared(target.tilt - tilt) > 0.000025 {
            lamp += (target.lamp - lamp) * 0.22
            eye += (target.eye - eye) * 0.22
            tilt += (target.tilt - tilt) * 0.22
        }
    }
}

private enum ChromaticMotion {
    static let manager = CMMotionManager()
    static var session: UUID?
}

/// Only the visible dial consumes motion samples. Reduce Motion uses the reference light.
private struct ChromaticDialLighting<Content: View>: View {
    @ViewBuilder let content: (ChromaticLightPose) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pose = ChromaticLightPose()

    private var respondsToMotion: Bool { scenePhase == .active && !reduceMotion }

    var body: some View {
        content(pose)
            .task(id: respondsToMotion) {
                pose = ChromaticLightPose()
                if respondsToMotion { await followDevice() }
            }
    }

    private func followDevice() async {
        #if DEBUG
        if let preview = ChromaticMotion.previewTilt {
            let roll = simd_quatd(angle: asin(preview.x / 2), axis: SIMD3(0, 1, 0))
            let pitch = simd_quatd(angle: -asin(preview.y / 2), axis: SIMD3(1, 0, 0))
            pose = ChromaticLightPose().relativeTo(roll * pitch)
            pose.tilt = preview
            return
        }
        #endif

        let motion = ChromaticMotion.manager
        guard motion.isDeviceMotionAvailable else { return }
        let session = UUID()
        ChromaticMotion.session = session
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates()
        defer {
            if ChromaticMotion.session == session {
                motion.stopDeviceMotionUpdates()
                ChromaticMotion.session = nil
            }
        }

        var rest: simd_quatd?
        let reference = ChromaticLightPose()
        while !Task.isCancelled && ChromaticMotion.session == session {
            if let rotation = motion.deviceMotion?.attitude.quaternion {
                let attitude = simd_quatd(ix: rotation.x, iy: rotation.y, iz: rotation.z, r: rotation.w)
                if rest == nil { rest = attitude }
                var next = pose
                next.follow(reference.relativeTo((rest ?? attitude).inverse * attitude))
                if next != pose { pose = next }
            }
            try? await Task.sleep(for: .milliseconds(33))
        }
    }

}

#if DEBUG
private extension ChromaticMotion {
    static let previewTilt: SIMD2<Double>? = {
        let prefix = "--tuner-test-glass-tilt="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let axes = argument.dropFirst(prefix.count).split(separator: ",").compactMap { Double($0) }
        guard axes.count == 2 else { return nil }
        return simd_clamp(SIMD2(axes[0], axes[1]), SIMD2(repeating: -1), SIMD2(repeating: 1))
    }()
}
#endif

/// A soft area light reflected by the plane of the cover and its rounded rim.
struct ChromaticCoverReflection: View {
    private typealias Dial = ChromaticDialGeometry

    private struct CutoutSample {
        let point: CGPoint
        let inward: SIMD2<Double>
        let azimuth: Double
    }

    private static let cutoutCenter = CGPoint(x: Dial.glassOpening.boundingRect.midX,
                                              y: Dial.glassOpening.boundingRect.midY)

    // Equal arc-length samples follow the cutout's actual rounded contour.
    private static let cutoutContour: [CutoutSample] = {
        let path = Dial.glassOpening
        let samples = 48
        let points = (1...samples).compactMap { path.trimmedPath(from: 0, to: CGFloat($0) / CGFloat(samples)).currentPoint }
        return points.indices.map { index in
            let point = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let inward = simd_normalize(SIMD2<Double>(previous.y - next.y, next.x - previous.x))
            let azimuth = atan2(point.y - cutoutCenter.y, point.x - cutoutCenter.x)
            return CutoutSample(point: point, inward: inward, azimuth: azimuth)
        }.sorted { $0.azimuth < $1.azimuth }
    }()

    let angle: Double
    let palette: ChromaticDialStyle.Relief

    private var tint: Color { palette.highlight }

    var body: some View {
        ChromaticDialLighting { light in
            Canvas { context, _ in drawReflection(light, in: context) }
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawReflection(_ light: ChromaticLightPose, in context: GraphicsContext) {
        let rotation = Dial.glassRotation(by: angle)
        var cover = context
        cover.clip(to: Dial.coverCoverage.applying(rotation), style: FillStyle(eoFill: true))
        drawOuterSlope(in: cover)
        // A bright patch over an idle note reads as a second selection on smoked glass.
        if palette.dark {
            if light.lamp.z > 0, light.eye.z > 0 {
                drawCutoutWall(light: light, rotation: rotation, in: context)
            }
            return
        }
        drawAmbientReflection(in: cover)

        guard light.lamp.z > 0, light.eye.z > 0 else { return }
        // The ray from the eye to the mirrored lamp intersects the flat cover here.
        let fraction = light.eye.z / (light.eye.z + light.lamp.z)
        let reflected = light.eye + (light.lamp - light.eye) * fraction
        let center = CGPoint(x: Dial.center.x + reflected.x * Dial.coverOuter,
                             y: Dial.center.y + reflected.y * Dial.coverOuter)
        cover.fill(Dial.circle(radius: Dial.coverOuter), with: .radialGradient(
            Gradient(colors: [tint.opacity(0.14), tint.opacity(0.07), .clear]),
            center: center, startRadius: 0, endRadius: Dial.coverOuter * 0.73
        ))
        // The same area light catches the wider crown of the outer bevel.
        cover.stroke(Dial.circle(radius: Dial.coverSlopeMiddle), with: .radialGradient(
            Gradient(colors: [tint.opacity(0.58), tint.opacity(0.37), tint.opacity(0.12), .clear]),
            center: center, startRadius: 0, endRadius: Dial.coverOuter * 0.86
        ), lineWidth: Dial.coverSlopeWidth - 0.8)
        cover.stroke(Dial.glassOpening.applying(rotation), with: .radialGradient(
            Gradient(colors: [tint.opacity(0.68), tint.opacity(0.3), .clear]),
            center: center, startRadius: 0, endRadius: Dial.coverOuter * 0.52
        ), lineWidth: 1.7)
        drawBevel(radius: Dial.coverSlopeMiddle, width: Dial.coverSlopeWidth - 1.2, slope: 0.50, light: light, in: cover)
        drawBevel(radius: Dial.coverInner + 1.7, width: 2.6, slope: -0.48, light: light, in: cover)
        drawCutoutWall(light: light, rotation: rotation, in: context)
    }

    private func drawOuterSlope(in cover: GraphicsContext) {
        let ramp = Dial.coverSlope
        let profile = Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: tint.opacity(0.16), location: 0.27),
            .init(color: palette.wall.opacity(0.08), location: 0.64),
            .init(color: palette.wall.opacity(0.27), location: 1)
        ])
        let hollow = FillStyle(eoFill: true)
        cover.fill(ramp, with: .radialGradient(profile, center: Dial.center,
                                              startRadius: Dial.coverSlopeStart, endRadius: Dial.coverOuter),
                   style: hollow)

        guard !palette.dark else { return }

        // Across the full width of the slope, the top-left catches light and the far side turns away.
        var lighting = cover
        lighting.clipToLayer { mask in
            mask.fill(ramp, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.38),
                    .init(color: .white.opacity(0.78), location: 1)
                ]),
                center: Dial.center, startRadius: Dial.coverSlopeStart, endRadius: Dial.coverOuter
            ), style: hollow)
        }
        let direction = Gradient(colors: [tint.opacity(0.73), tint.opacity(0.20), .clear, palette.wall.opacity(0.27)])
        lighting.fill(ramp, with: .linearGradient(direction,
                        startPoint: Dial.point(at: -.pi / 4, radius: Dial.coverOuter),
                        endPoint: Dial.point(at: .pi * 3 / 4, radius: Dial.coverOuter)),
                      style: hollow)
    }

    private func drawAmbientReflection(in cover: GraphicsContext) {
        // The broad overhead return softens toward the center of the glass.
        let shoulder = Dial.point(at: -.pi / 6, radius: Dial.coverOuter - 2)
        cover.fill(Dial.circle(radius: Dial.coverOuter), with: .radialGradient(
            Gradient(colors: [tint.opacity(0.51), tint.opacity(0.21), tint.opacity(0.045), .clear]),
            center: shoulder, startRadius: 0, endRadius: Dial.coverOuter * 0.66
        ))
    }

    private func drawBevel(radius: CGFloat, width: CGFloat, slope: Double, light: ChromaticLightPose,
                           in context: GraphicsContext) {
        let samples = 36
        let stops = (0...samples).map { index -> Gradient.Stop in
            let fraction = Double(index) / Double(samples)
            let azimuth = fraction * 2 * .pi
            let radial = SIMD3<Double>(cos(azimuth), sin(azimuth), 0)
            let point = radial * (radius / Dial.coverOuter)
            let normal = simd_normalize(radial * slope + SIMD3(0, 0, 1))
            return .init(color: reflection(at: point, normal: normal, light: light), location: fraction)
        }
        context.stroke(Dial.circle(radius: radius),
                       with: .conicGradient(Gradient(stops: stops), center: Dial.center), lineWidth: width)
    }

    private func drawCutoutWall(light: ChromaticLightPose, rotation: CGAffineTransform, in context: GraphicsContext) {
        guard let first = Self.cutoutContour.first else { return }
        let opening = Dial.glassOpening.applying(rotation)
        let center = Self.cutoutCenter.applying(rotation)
        var stops = Self.cutoutContour.map { sample -> Gradient.Stop in
            let point = sample.point.applying(rotation)
            let local = SIMD3<Double>((point.x - Dial.center.x) / Dial.coverOuter,
                                      (point.y - Dial.center.y) / Dial.coverOuter, 0)
            let inward = SIMD2(rotation.a * sample.inward.x + rotation.c * sample.inward.y,
                               rotation.b * sample.inward.x + rotation.d * sample.inward.y)
            let normal = simd_normalize(SIMD3<Double>(inward.x * 0.58, inward.y * 0.58, 1))
            let location = (sample.azimuth - first.azimuth) / (2 * .pi)
            return .init(color: reflection(at: local, normal: normal, light: light), location: location)
        }
        stops.append(.init(color: stops[0].color, location: 1))
        var wall = context
        wall.clip(to: opening)
        wall.stroke(opening, with: .conicGradient(Gradient(stops: stops), center: center,
                                                  angle: .radians(angle + first.azimuth)), lineWidth: 4.9)
    }

    private func reflection(at point: SIMD3<Double>, normal: SIMD3<Double>, light: ChromaticLightPose) -> Color {
        let lightRay = simd_normalize(light.lamp - point)
        let viewRay = simd_normalize(light.eye - point)
        let halfAngle = simd_normalize(lightRay + viewRay)
        let fresnel = 0.04 + 0.96 * pow(max(0, 1 - simd_dot(viewRay, halfAngle)), 5)
        let intensity = min(0.94, 24 * fresnel * pow(max(0, simd_dot(normal, halfAngle)), 26))
        return tint.opacity(intensity)
    }
}

/// The tinted pane, its rim and the cutout bevel turn together.
private struct ChromaticGlassPlate: View, Equatable {
    private typealias Dial = ChromaticDialGeometry
    let style: ChromaticDialStyle

    var body: some View {
        Canvas { ctx, _ in drawPlate(in: ctx) }
            .frame(width: Dial.diameter, height: Dial.diameter)
    }

    private func drawPlate(in ctx: GraphicsContext) {
        let outer = Dial.circle(radius: Dial.outer)
        let inner = Dial.circle(radius: Dial.inner)
        var pane = ctx
        pane.clip(to: Dial.glassCoverage, style: FillStyle(eoFill: true))
        let tint = Color(hex: 0xC7C3B9)
        pane.fill(outer, with: .linearGradient(Gradient(colors: [tint.opacity(0.025), tint.opacity(0.06), tint.opacity(0.12)]),
            startPoint: CGPoint(x: 90, y: 0), endPoint: CGPoint(x: 263, y: Dial.diameter)
        ))
        let polish = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [style.glassGlint.opacity(0.48), style.glassGlint.opacity(0.13), .clear]),
            center: Dial.point(at: .pi * 0.74, radius: Dial.outer - 9), startRadius: 10, endRadius: 108
        )
        pane.stroke(Dial.circle(radius: Dial.inner + 1.6), with: polish, lineWidth: 1.3)
        pane.stroke(Dial.circle(radius: Dial.outer - 1.75), with: polish, lineWidth: 0.95)
        ctx.stroke(Dial.circle(radius: Dial.inner - 0.55), with: .color(style.recess[0].opacity(0.87)), lineWidth: 1.45)
        let glassEdge = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [style.glassGlint.opacity(0.18), style.recess[0].opacity(0.65)]),
            startPoint: .zero, endPoint: CGPoint(x: Dial.diameter, y: Dial.diameter)
        )
        ctx.stroke(inner, with: glassEdge, lineWidth: 0.9)
        ctx.stroke(outer, with: glassEdge, lineWidth: 0.9)

        let opening = Dial.glassOpening
        let bounds = opening.boundingRect
        let cutEdge = [style.recess[0], style.engraving.opacity(0.68)]
        ctx.stroke(opening, with: .linearGradient(
            Gradient(colors: cutEdge), startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
            endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)), lineWidth: 1)
    }
}
