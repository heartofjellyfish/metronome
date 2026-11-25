import SwiftUI

enum TunerConsoleMetrics {
    static let width: CGFloat = 344
}

struct StringTuningFace<Layout: TunerHeadstockDrawing, TuningSelector: View>: View {
    let p: InstrumentPalette
    let layout: Layout
    let strings: [Int]
    let note: Int?
    let reading: TunerReading?
    let status: String
    let drawing: TunerStringDrawing
    var centerX: CGFloat = 180
    var prefersFlats = false
    let select: (Int, TunerReferenceAction) -> Void
    @ViewBuilder let tuningSelector: () -> TuningSelector

    var body: some View {
        InstrumentNeedleFace(p: p, note: note, reading: reading, status: status, prefersFlats: prefersFlats,
                             readoutScale: drawing.relief ? 0.83 : 1,
                             readoutY: drawing.relief ? 174 : 222,
                             showsTuningConsole: drawing.relief,
                             faceHeight: drawing.relief ? 702 : 637, previewingNote: drawing.auditioning != nil) {
            TunerHeadstockView(p: p, layout: layout, strings: strings, drawing: drawing, prefersFlats: prefersFlats, select: select)
                .frame(width: 360, height: 330)
                .scaleEffect(x: drawing.relief ? 1.04 : 1.02, y: drawing.relief ? 1.10 : 1.02)
                .position(x: centerX, y: drawing.relief ? 505 : 475)
            if drawing.relief {
                tuningSelector().position(x: 180, y: 266)
            }
        }
    }
}

struct TunerStringDrawing {
    let palette: InstrumentPalette
    let liveState: IntonationState?
    let active: Int?
    let completed: Set<Int>
    let stringCount: Int
    var relief = false
    var auditioning: Int? = nil

    var allTuned: Bool { stringCount > 0 && (0..<stringCount).allSatisfy(completed.contains) }
    var confirmationColor: Color { relief && !palette.dark ? Color(hex: 0x66762E) : palette.tuningGreen }
    var outline: Color { allTuned ? confirmationColor : palette.ink }
    private var activeColor: Color { liveState == .centered ? confirmationColor : palette.tuningTint(liveState) }

    func highlights(_ index: Int) -> Bool { active == index || auditioning == index || completed.contains(index) }

    func color(for index: Int) -> Color {
        if index == auditioning { return palette.tunerReferenceInk }
        if completed.contains(index) { return confirmationColor }
        return index == active ? activeColor : palette.ink
    }

    func stringColor(for index: Int) -> Color {
        if highlights(index) { return color(for: index) }
        let opacity = relief ? (palette.dark ? 0.58 : 0.80) : 0.78
        return palette.ink.opacity(opacity)
    }

    func isConfirmed(_ wires: Range<Int>) -> Bool { wires.allSatisfy(completed.contains) }

    func color(for wires: Range<Int>) -> Color {
        if let auditioning, wires.contains(auditioning) { return palette.tunerReferenceInk }
        if isConfirmed(wires) { return confirmationColor }
        if let active, wires.contains(active) { return activeColor }
        return palette.ink
    }

    func accessibilityValue(for index: Int) -> String {
        if index == auditioning { return tunerText("Reference tone") }
        return completed.contains(index) ? tunerText("In tune") : ""
    }

    func drawContacts(_ points: [CGPoint], for index: Int, in context: GraphicsContext, diameter: CGFloat = 2.6) {
        guard index == active || completed.contains(index) else { return }
        for point in points {
            let size = CGSize(width: diameter, height: diameter)
            let frame = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: size.width, height: size.height)
            context.fill(Path(ellipseIn: frame), with: .color(color(for: index)))
        }
    }

    func lineWidth(for index: Int, normal: CGFloat, focused: CGFloat) -> CGFloat {
        if index == active { return focused }
        return completed.contains(index) ? min(focused, normal + 0.25) : normal
    }

    func paintOrder(_ indices: Range<Int>) -> [Int] {
        let remaining = indices.filter { $0 != active }
        return remaining.filter { !completed.contains($0) }
            + remaining.filter(completed.contains)
            + indices.filter { $0 == active }
    }
}

struct InstrumentNeedleFace<Artwork: View>: View {
    let p: InstrumentPalette
    let note: Int?
    let reading: TunerReading?
    let status: String
    var prefersFlats = false
    var notation = TunerPitchNotation(writtenOffset: 0, prefersWritten: true)
    var showsPitchCheck = false
    var stringName: String? = nil
    var showsStringStatus = true
    var readoutScale: CGFloat = 1
    var readoutY: CGFloat = 222
    var showsTuningConsole = false
    var faceHeight: CGFloat = 637
    var auditionNote: ((Int, TunerReferenceAction) -> Void)? = nil
    var previewingNote = false
    @Environment(\.accessibilityDifferentiateWithoutColor) private var showDirection
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let scale = min(size.width / 360, size.height / faceHeight)
            ZStack {
                if showsTuningConsole {
                    tuningConsole.accessibilityHidden(true)
                }
                Group {
                    if let note {
                        if let auditionNote {
                            Button { auditionNote(note, .tap) } label: { noteReadout(note) }
                                .buttonStyle(TunerReferenceButtonStyle { auditionNote(note, $0 ? .hold : .release) })
                                .accessibilityHint(tunerText("Reference tone"))
                        } else {
                            noteReadout(note).accessibilityAddTraits(.isStaticText)
                        }
                    } else {
                        Text(tunerText(status))
                            .font(InstrumentType.value(18))
                            .foregroundStyle(showsTuningConsole && !p.dark ? p.ink.opacity(0.72) : p.muted)
                    }
                }.foregroundStyle(p.ink).position(x: 180, y: readoutY)
                TunerNeedleMeter(p: p, reading: reading, compact: showsTuningConsole)
                    .frame(width: 360, height: 207)
                    .scaleEffect(0.92)
                    .position(x: 180, y: showsTuningConsole ? 104 : 103.5)
                    .accessibilityElement(children: .ignore).accessibilityLabel(tunerText(status))
                    .accessibilityValue(reading?.signedCents ?? "")
                    .accessibilityIdentifier("tuner-needle-meter")
                if let note, notation.hasTransposition {
                    Text(tunerText(notation.primaryTitle))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(p.ink.opacity(0.68))
                        .position(x: 180, y: 174)
                        .accessibilityHidden(true)
                    secondaryReadout(note + notation.secondaryOffset).position(x: 180, y: 274)
                }
                if let stringName {
                    HStack(spacing: 6) {
                        Text(stringName)
                        if previewingNote {
                            Image(systemName: "speaker.wave.2").foregroundStyle(p.tunerReferenceInk)
                                .accessibilityLabel(tunerText("Reference tone"))
                        } else if showsStringStatus, let reading {
                            Text("·").foregroundStyle(p.muted).accessibilityHidden(true)
                            let pitchStatus = tunerText(reading.state.label)
                            Text(reading.state == .centered ? pitchStatus : pitchStatus + " " + reading.signedCents)
                                .foregroundStyle(p.tuningTint(reading.state))
                        }
                    }
                    .font(InstrumentType.value(14)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.75).frame(width: 328)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("tuner-current-string")
                    .position(x: 180, y: 278)
                } else if previewingNote {
                    Label(tunerText("Reference tone"), systemImage: "speaker.wave.2")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(p.tunerReferenceInk)
                        .position(x: 180, y: notation.hasTransposition ? 299 : 281)
                } else if showDirection, let reading {
                    Text(tunerText(status) + " · " + reading.signedCents)
                        .font(InstrumentType.value(14)).monospacedDigit()
                        .foregroundStyle(p.ink)
                        .position(x: 180, y: showsTuningConsole ? 204 : notation.hasTransposition ? 299 : 281)
                        .accessibilityHidden(true)
                } else if showsPitchCheck, reading?.state == .centered {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.tuningGreen)
                        .position(x: 180, y: notation.hasTransposition ? 299 : 276)
                        .accessibilityHidden(true)
                }
                artwork()
            }.frame(width: 360, height: faceHeight)
                // The note and string labels share the same fixed canvas as the needle and artwork.
                .dynamicTypeSize(...DynamicTypeSize.large)
                .scaleEffect(scale).position(x: size.width / 2, y: faceHeight * scale / 2)
        }
    }

    private var tuningConsole: some View {
        let outline = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let display = LinearGradient(colors: p.dark
            ? [Color(hex: 0x30332F), Color(hex: 0x262826)]
            : [Color(hex: 0xD8D0C4), Color(hex: 0xC7BFAF)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        return Color.clear
            .frame(width: TunerConsoleMetrics.width, height: 222)
            .insetPanel(p, shape: outline, fill: display)
            .position(x: 180, y: 116)
            .allowsHitTesting(false)
    }

    private func noteReadout(_ note: Int) -> some View {
        let primary = note + notation.primaryOffset
        let label = TunerPitch.label(primary, flats: prefersFlats)
        return Text(TunerPitch.name(primary, flats: prefersFlats))
            .font(.custom("HelveticaNeue-Medium", size: 84 * readoutScale))
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .lastTextBaseline)) {
                Text(String(TunerPitch.octave(primary)))
                    .font(.system(size: 37 * readoutScale, weight: .medium))
                    .alignmentGuide(.trailing) { $0[.leading] - 1 }
            }
            .foregroundStyle(previewingNote ? p.tunerReferenceInk : p.ink)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(notation.hasTransposition ? tunerText(notation.primaryTitle) + ", " + label : label)
            .accessibilityValue(previewingNote ? tunerText("Reference tone") : "")
            .accessibilityIdentifier("tuner-note-readout")
    }

    private func secondaryReadout(_ note: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(tunerText(notation.secondaryTitle))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(p.ink.opacity(0.68))
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(TunerPitch.name(note, flats: prefersFlats)).font(InstrumentType.value(20))
                Text(String(TunerPitch.octave(note))).font(.system(size: 12))
            }.foregroundStyle(p.ink.opacity(0.85))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tunerText(notation.secondaryTitle) + ", " + TunerPitch.label(note, flats: prefersFlats))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("tuner-secondary-note-readout")
    }
}

extension InstrumentPalette {
    var tunerDrawingSurface: Color { dark ? body : Color(hex: 0xF4EEE5) }

    var tuningGreen: Color { Color(hex: dark ? 0x9DCE89 : 0x2F7727) }
    var tunerReferenceInk: Color { Color(hex: dark ? 0x9DC9E1 : 0x4E809E) }

    func tuningTint(_ state: IntonationState?) -> Color {
        switch state {
        case .centered: return tuningGreen
        case .sharp, .flat: return Color(hex: dark ? 0xEE9680 : 0xB85138)
        case nil: return muted
        default: return Color(hex: dark ? 0xEEC270 : 0xBC791D)
        }
    }
}

struct TunerNeedleMeter: View {
    let p: InstrumentPalette
    let reading: TunerReading?
    var compact = false

    var body: some View {
        Canvas { ctx, size in
            // Approved face geometry, scaled uniformly with the rest of the instrument.
            let unit = size.width / 592
            let center = CGPoint(x: size.width / 2, y: 32 + 308 * unit)
            func point(_ cents: Double, _ radius: CGFloat) -> CGPoint {
                let angle = cents * 56 / 50 * .pi / 180
                return CGPoint(x: center.x + radius * unit * sin(angle),
                               y: center.y - radius * unit * cos(angle))
            }
            func ray(_ cents: Double, from: CGFloat, to: CGFloat) -> Path {
                Path { path in
                    path.move(to: point(cents, from))
                    path.addLine(to: point(cents, to))
                }
            }
            for step in -20...20 {
                let cents = Double(step) * 2.5
                let major = step.isMultiple(of: 10)
                let length: CGFloat = major ? 19 : step.isMultiple(of: 2) ? 12 : 9
                ctx.stroke(ray(cents, from: 308, to: 308 - length), with: .color(p.ink),
                           lineWidth: (major ? 2.7 : 1) * unit)
                if major {
                    let label = cents < 0 ? "−" + String(Int(-cents)) : cents > 0 ? "+" + String(Int(cents)) : "0"
                    var anchor = point(cents, 339)
                    if abs(cents) == 50 {
                        anchor.x = min(max(anchor.x, 17), size.width - 17)
                        anchor.y -= 5
                    }
                    ctx.draw(Text(label).font(.system(size: 16)).foregroundStyle(p.ink), at: anchor)
                }
            }
            let innerRadius: CGFloat = compact ? 151 : 107
            if let reading {
                let cents = reading.displayedCents
                let tipColor = reading.state == .centered && !p.dark ? Color(hex: compact ? 0x99A54D : 0x79A557) : p.tuningTint(reading.state)
                ctx.drawLayer { layer in
                    // Hide the axle, the tail and its shadow behind the circular lip at every angle.
                    let radius = innerRadius * unit
                    let occluder = CGRect(x: center.x - radius, y: center.y - radius,
                                          width: 2 * radius, height: 2 * radius)
                    layer.clip(to: Path(ellipseIn: occluder), options: .inverse)
                    layer.drawLayer { hand in
                        hand.addFilter(.shadow(color: .black.opacity(0.14), radius: 1, x: 0.5, y: 0.8))
                        let style = StrokeStyle(lineWidth: 6.8 * unit, lineCap: .round)
                        hand.stroke(ray(cents, from: 100, to: 284.6), with: .color(p.ink), style: style)
                        hand.stroke(ray(cents, from: 252, to: 284.6), with: .color(tipColor), style: style)
                    }
                }
            }
            let shade = Gradient(colors: [.clear, p.ink.opacity(0.17), .clear])
            for (inset, width, opacity) in [(1.25, 2.5, 0.4), (0.35, 0.7, 1.0)] {
                var edge = Path()
                edge.addArc(center: center, radius: (innerRadius - inset) * unit,
                            startAngle: .degrees(compact ? -119 : -150),
                            endAngle: .degrees(compact ? -61 : -30), clockwise: false)
                var lip = ctx
                lip.opacity = opacity
                lip.stroke(edge, with: .linearGradient(shade, startPoint: point(-50, innerRadius),
                                                       endPoint: point(50, innerRadius)), lineWidth: width * unit)
            }
        }
    }

}
