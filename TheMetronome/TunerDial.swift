import SwiftUI

struct TunerDial: View {
    let p: InstrumentPalette
    let reading: TunerReading?
    let targetNote: Int?
    let status: String
    let pickNote: (Int) -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var showDirection

    private let face: CGFloat = 350
    private let innerRadius: CGFloat = 118
    private let outerRadius: CGFloat = 161
    private let halfStep = Double.pi / 12
    private var centered: Bool { reading?.state == .centered }
    private var centeredDirection: String? {
        guard centered, let reading, abs(reading.cents) > 3 else { return nil }
        return reading.cents < 0 ? IntonationState.flat.label : IntonationState.sharp.label
    }
    private var sustainProgress: Double { min(1, (reading?.centeredDuration ?? 0) / 2.5) }
    private var displayNote: Int? { reading?.note }
    private var target: Int? { (targetNote ?? displayNote).map { ($0 % 12 + 12) % 12 } }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            dial.scaleEffect(min(size.width, size.height, face) / face)
                .position(x: size.width / 2, y: size.height / 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuner-dial")
    }

    private var dial: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [p.light, p.bottom, p.edge], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(p.dark ? 0.42 : 0.18), radius: 2.5, y: 2)
            Circle().inset(by: 3).fill(RadialGradient(colors: [p.top, p.body], center: .topLeading, startRadius: 14, endRadius: face))
                .overlay { Circle().inset(by: 3).strokeBorder(p.edge.opacity(0.55), lineWidth: 0.6) }
            scale
            ForEach(0..<12) { index in
                let pitch = (index + 9) % 12
                let selected = target == pitch
                Button { pickNote(pitch) } label: {
                    Text(TunerPitch.names[pitch]).font(InstrumentType.value(17))
                        .foregroundStyle(selected ? p.ink : p.muted)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("tuner-dial-note-\(pitch)")
                .position(point(at: angle(for: pitch), radius: 139, center: CGPoint(x: face / 2, y: face / 2)))
            }
            centerReadout.allowsHitTesting(false)
        }
        .frame(width: face, height: face).foregroundStyle(p.ink)
        // The labels follow the positions engraved on the dial.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func angle(for pitch: Int) -> Double {
        Double((pitch + 3) % 12) * 2 * halfStep
    }

    private func point(at angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + sin(angle) * radius, y: center.y - cos(angle) * radius)
    }

    private func sector(at angle: Double, center: CGPoint, radius: CGFloat) -> Path {
        let start = angle - halfStep - .pi / 2
        let end = angle + halfStep - .pi / 2
        return Path { path in
            path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
            path.addLine(to: point(at: angle + halfStep, radius: innerRadius, center: center))
            path.addArc(center: center, radius: innerRadius, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
            path.closeSubpath()
        }
    }

    private var scale: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for radius in [innerRadius, outerRadius] {
                let ring = CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)
                ctx.stroke(Path(ellipseIn: ring), with: .color(p.muted.opacity(0.62)), lineWidth: 0.65)
            }
            func boundary(at angle: Double, emphasized: Bool = false) {
                let line = Path { path in
                    path.move(to: point(at: angle, radius: innerRadius, center: center))
                    path.addLine(to: point(at: angle, radius: outerRadius, center: center))
                }
                ctx.stroke(line, with: .color(emphasized ? p.ink : p.muted.opacity(0.48)), lineWidth: emphasized ? 1.15 : 0.55)
            }
            for index in 0..<12 {
                boundary(at: Double(2 * index + 1) * halfStep)
            }
            if let target {
                let fixed = angle(for: target)
                if let reading {
                    // Every 100 cents advances by one pitch sector.
                    let offset = max(-50, min(50, reading.cents))
                    let measured = fixed + offset * (2 * halfStep / 100)
                    let tint = p.tuningTint(reading.state)
                    let shape = sector(at: measured, center: center, radius: outerRadius)
                    ctx.fill(shape, with: .color(tint.opacity(centered ? 0.24 : 0.47)))
                    if centered && sustainProgress > 0 {
                        let height = (outerRadius - innerRadius) * sustainProgress
                        let progress = sector(at: fixed, center: center, radius: innerRadius + height)
                        ctx.fill(progress, with: .color(tint.opacity(0.46)))
                    }
                    ctx.stroke(shape, with: .color(tint.opacity(0.88)), lineWidth: 0.85)
                }
                boundary(at: fixed - halfStep, emphasized: true)
                boundary(at: fixed + halfStep, emphasized: true)
            }
        }.accessibilityHidden(true)
    }

    private var centerReadout: some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                if displayNote != nil {
                    Color.clear.frame(width: 27, height: 1)
                }
                Text(displayNote.map(TunerPitch.name) ?? "—")
                    .font(.custom("HelveticaNeue-Medium", size: displayNote == nil ? 43 : 76))
                if let displayNote {
                    Text(String(displayNote / 12 - 1)).font(InstrumentType.value(32))
                        .frame(width: 27, alignment: .leading)
                }
            }
            .frame(height: 68)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(displayNote.map(TunerPitch.label) ?? "—")
            if let reading, !centered {
                let cents = TunerReading.formatCents(reading.cents)
                let value = showDirection ? tunerText(status) + " · " + cents : cents
                Text(value).font(InstrumentType.value(15)).monospacedDigit().foregroundStyle(p.ink)
                    .accessibilityLabel(tunerText(status))
                    .accessibilityValue(cents)
                    .accessibilityIdentifier("tuner-chromatic-intonation")
            } else {
                HStack(spacing: 5) {
                    if centered {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(tunerText(centeredDirection ?? status)).lineLimit(1)
                        .accessibilityLabel(centeredDirection.map { tunerText(status) + ", " + tunerText($0) } ?? tunerText(status))
                        .accessibilityValue(centered ? sustainProgress.formatted(.percent.precision(.fractionLength(0))) : "")
                        .accessibilityIdentifier("tuner-chromatic-intonation")
                    if centered, let reading {
                        Text("·").accessibilityHidden(true)
                        Text(TunerReading.formatCents(reading.cents)).monospacedDigit()
                            .accessibilityIdentifier("tuner-chromatic-cents")
                    }
                }
                .foregroundStyle(centered ? p.tuningGreen : p.muted)
                .font(InstrumentType.value(15))
            }
        }
    }
}
