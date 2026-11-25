import SwiftUI

struct TunerDial: View {
    private typealias Dial = ChromaticDialGeometry

    let style: ChromaticDialStyle
    let reading: TunerReading?
    let status: String
    var referenceNote: Int? = nil
    var referenceInk: Color = .accentColor
    var audition: ((Int, TunerReferenceAction) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focus = ChromaticDialFocus()
    @State private var plateAngle = 0.0
    @State private var auditionOctave = 4

    private var visibleReading: TunerReading? { focus.readingForDisplay(reading) }
    private var sustain: ChromaticSustain { ChromaticSustain(visibleReading) }
    private var centered: Bool { sustain.isCentered }
    private var sustainProgress: Double { sustain.progress }
    private var displayNote: Int? { referenceNote ?? visibleReading?.note }
    private var target: Int? { displayNote.map { ($0 % 12 + 12) % 12 } }
    private var pointerAngle: Double? { reading.map { Dial.pointerAngle(note: $0.note, cents: $0.cents) } }
    private var requestedAngle: Double? { pointerAngle ?? target.map(Dial.angle(for:)) }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            dial.scaleEffect(min(size.width, size.height, Dial.diameter) / Dial.diameter)
                .position(x: size.width / 2, y: size.height / 2)
        }
        .onChange(of: reading, initial: true) { _, sample in
            if let sample, sample.isFresh { auditionOctave = TunerPitch.octave(sample.note) }
            var next = focus
            next.update(reading: sample)
            if next != focus { focus = next }
        }
        .onChange(of: requestedAngle, initial: true) { _, angle in
            if let angle { plateAngle = Dial.nearestAngle(angle, to: plateAngle) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuner-dial")
    }

    private var dial: some View {
        let usesCover = style.relief != nil
        let angle = usesCover ? plateAngle : (requestedAngle ?? plateAngle)
        return ZStack {
            ChromaticDialFace(style: style, angle: angle, target: target, showsPointer: pointerAngle != nil,
                              state: visibleReading?.state, sustain: sustain) { aperture in
                ForEach(0..<12) { pitch in
                    ChromaticDialNote(pitch: pitch, selected: target == pitch,
                                      style: style, aperture: aperture)
                }
            }
            .animation(usesCover && !reduceMotion ? .easeOut(duration: 0.075) : nil, value: angle)
            if referenceNote != nil, let target {
                let position = Dial.angle(for: target)
                let opening = Dial.glassOpening.applying(Dial.glassRotation(by: position))
                opening.fill(referenceInk.opacity(0.22))
                    .overlay { opening.stroke(referenceInk.opacity(0.8), lineWidth: 0.9) }
                    .allowsHitTesting(false)
            }
            centerReadout.allowsHitTesting(false)
            if let audition {
                ForEach(0..<12) { pitch in referenceButton(for: pitch, audition: audition) }
            }
        }
        .frame(width: Dial.diameter, height: Dial.diameter)
        .foregroundStyle(style.ink)
        // The labels follow the positions engraved on the dial.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func referenceButton(for pitch: Int, audition: @escaping (Int, TunerReferenceAction) -> Void) -> some View {
        let note = (auditionOctave + 1) * 12 + pitch
        let playing = referenceNote == note
        let angle = Dial.angle(for: pitch)
        let area = Dial.cell(at: angle)
        let bounds = area.boundingRect
        return Button {
            audition(note, .tap)
        } label: {
            Color.clear.frame(width: bounds.width, height: bounds.height)
                .contentShape(area.offsetBy(dx: -bounds.minX, dy: -bounds.minY))
        }
        .buttonStyle(TunerReferenceButtonStyle(playsOnTouchDown: true, cancel: { audition(note, .cancel) }) {
            audition(note, $0 ? .hold : .release)
        })
        .accessibilityLabel(TunerPitch.label(note))
        .accessibilityHint(tunerText("Reference tone"))
        .accessibilityValue(playing ? tunerText("Reference tone") : "")
        .accessibilityIdentifier("tuner-reference-note-\(pitch)")
        .position(x: bounds.midX, y: bounds.midY)
    }

    private var noteFont: Font {
        if displayNote == nil { return InstrumentType.value(43) }
        return style.relief == nil ? InstrumentType.value(76) : InstrumentType.display(80)
    }

    private var statusFont: Font {
        .system(size: 15, weight: .semibold)
    }

    private var pitchLine: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            if displayNote != nil {
                Color.clear.frame(width: 27, height: 1)
            }
            Text(displayNote.map(TunerPitch.name) ?? "—")
                .font(noteFont)
            if let displayNote {
                Text(String(TunerPitch.octave(displayNote))).font(InstrumentType.value(32))
                    .frame(width: 27, alignment: .leading)
            }
        }
    }

    private var centerReadout: some View {
        VStack(spacing: 5) {
            Group {
                if style.relief != nil { pitchLine.mask { ChromaticLCDMatrix() } }
                else { pitchLine }
            }
            .frame(height: 74)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(displayNote.map(TunerPitch.label) ?? "—")
            .accessibilityIdentifier("tuner-chromatic-pitch")
            if referenceNote != nil {
                Label(tunerText("Reference tone"), systemImage: "speaker.wave.2")
                    .font(statusFont).foregroundStyle(referenceInk)
                    .accessibilityIdentifier("tuner-chromatic-intonation")
            } else if let reading = visibleReading {
                deviationReadout(reading)
            } else {
                Text(tunerText(status)).font(statusFont).foregroundStyle(style.engraving)
                    .lineLimit(2).frame(maxWidth: 168)
                    .accessibilityIdentifier("tuner-chromatic-intonation")
            }
        }
    }

    private func deviationReadout(_ reading: TunerReading) -> some View {
        let cents = TunerReading.formatCents(reading.cents)
        let showsDirection = reading.cents.rounded() != 0
        let key = centered ? "In tune" : !showsDirection ? "Settling"
            : reading.cents < 0 ? "Raise pitch" : "Lower pitch"
        let direction = centered && showsDirection
            ? " · " + tunerText(reading.cents < 0 ? "Flat" : "Sharp") : ""
        let icon = centered ? "checkmark" : !showsDirection ? nil
            : reading.cents < 0 ? "arrow.up" : "arrow.down"
        let signal = style.signal(for: reading.state)
        return VStack(spacing: 3) {
            Text(cents)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(style.ink)
                .accessibilityIdentifier("tuner-chromatic-cents")
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(tunerText(key) + direction).font(statusFont).lineLimit(1).minimumScaleFactor(0.72)
                    .accessibilityValue(centered ? sustainProgress.formatted(.percent.precision(.fractionLength(0))) : cents)
                    .accessibilityIdentifier("tuner-chromatic-intonation")
            }
            .foregroundStyle(signal)
            .frame(maxWidth: 145)
        }
    }
}

/// A fixed tile leaves faint gaps between the pitch readout's LCD pixels.
private struct ChromaticLCDMatrix: View {
    private static let tile: CGImage = {
        let side = 4
        let alpha: [UInt8] = [
            255, 255, 255, 204,
            255, 255, 255, 204,
            255, 255, 255, 204,
            204, 204, 204, 184
        ]
        let premultipliedWhite = alpha.flatMap { [$0, $0] }
        let provider = CGDataProvider(data: Data(premultipliedWhite) as CFData)!
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 16,
                       bytesPerRow: 2 * side, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }()

    var body: some View {
        Image(decorative: Self.tile, scale: 3).resizable(resizingMode: .tile)
    }
}

private struct ChromaticDialNote: View {
    private typealias Dial = ChromaticDialGeometry

    let pitch: Int
    let selected: Bool
    let style: ChromaticDialStyle
    let aperture: ChromaticDialAperture
    var body: some View {
        let dialAngle = Dial.angle(for: pitch)
        let position = Dial.point(at: dialAngle, radius: Dial.letteringRadius)
        let labelFrame = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)
        coveredLettering(in: labelFrame)
            .overlay {
                exposedLettering(in: aperture.opening, frame: labelFrame, ink: style.ink)
                exposedLettering(in: aperture.fill, frame: labelFrame, ink: style.filledInk)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .position(position)
    }

    private var coveredInk: Color {
        if style.relief != nil { return style.ink.opacity(selected ? 1 : 0.98) }
        return style.engraving.opacity(selected ? 0.92 : 0.82)
    }

    @ViewBuilder
    private func coveredLettering(in frame: CGRect) -> some View {
        let bed = lettering.foregroundStyle(coveredInk)
            .frame(width: frame.width, height: frame.height)
        let blur = ChromaticDialEtching.blur(at: Dial.angle(for: pitch), from: aperture.angle)
        if style.relief == nil {
            bed
        } else if aperture.opening.boundingRect.intersects(frame) {
            let bounds = CGRect(origin: .zero, size: frame.size)
            let opening = aperture.opening.offsetBy(dx: -frame.minX, dy: -frame.minY)
            bed.blur(radius: blur)
                .mask { ChromaticDialEtching.outsideOpening(opening, in: bounds).fill(style: FillStyle(eoFill: true)) }
        } else {
            bed.blur(radius: blur)
        }
    }

    @ViewBuilder
    private func exposedLettering(in path: Path?, frame: CGRect, ink: Color) -> some View {
        if let path, path.boundingRect.intersects(frame) {
            lettering.foregroundStyle(ink)
                .frame(width: frame.width, height: frame.height)
                .blur(radius: style.relief == nil ? 0 : ChromaticDialEtching.openingBlur)
                .mask { path.offsetBy(dx: -frame.minX, dy: -frame.minY) }
                .accessibilityHidden(true)
        }
    }

    private var lettering: some View { Text(TunerPitch.names[pitch]).font(InstrumentType.value(17)) }
}
