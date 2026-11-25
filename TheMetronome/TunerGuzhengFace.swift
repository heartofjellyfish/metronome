import SwiftUI

struct TunerGuzhengFace: View {
    let p: InstrumentPalette
    let note: Int?
    let reading: TunerReading?
    let status: String
    let strings: [Int]
    let drawing: TunerStringDrawing
    let groups: [TunerStringGroup]
    let groupIndex: Int
    let showsAll: Bool
    let soundingString: Int?
    let canPlay: Bool
    let chooseGroup: (Int) -> Void
    let showOverview: () -> Void
    let select: (Int, TunerReferenceAction) -> Void

    private static let rowHeight: CGFloat = 44
    private static let detailRowHeight: CGFloat = 34
    private static let contentWidth: CGFloat = 340
    private static let detailWidth = contentWidth - 20
    private static let detailTop: CGFloat = 278
    private static let farRimY: CGFloat = 9
    private static let firstWireY = farRimY + detailRowHeight
    private static let nearRimY = firstWireY + 7 * detailRowHeight + 3
    private static let detailHeight = nearRimY + 5
    private static let bodyLeft: CGFloat = 66

    var body: some View {
        InstrumentNeedleFace(p: p, note: note, reading: reading, status: status, readoutScale: 0.88, readoutY: 210,
                             previewingNote: soundingString != nil) {
            if let index = drawing.active, strings.indices.contains(index) {
                Text(String(format: tunerText("String %d"), index + 1))
                    .font(InstrumentType.value(14)).monospacedDigit()
                    .foregroundStyle(soundingString == index ? p.tunerReferenceInk
                                     : drawing.completed.contains(index) ? p.tuningGreen : p.ink)
                    .accessibilityIdentifier("tuner-current-string")
                    .position(x: 180, y: 263)
            }
            if showsAll {
                overviewArtwork.position(x: 180, y: 356)
                overviewTargets.position(x: 180, y: 502)
            } else {
                let group = groups[groupIndex]
                detailArtwork(group).position(x: 180, y: Self.detailTop + Self.detailHeight / 2)
            }
            groupSelector.position(x: 180, y: 612)
        }
    }

    private var groupSelector: some View {
        HStack(spacing: 1) {
            ForEach(groups.indices, id: \.self) { index in
                let group = groups[index]
                selector(
                    group.kind.guzhengPositionTitle,
                    range: group.subtitle,
                    accessibilityRange: String(format: tunerText("Strings %@"), group.subtitle),
                    location: index,
                    wires: group.wires,
                    selected: !showsAll && index == groupIndex,
                    identifier: "tuner-strings-group-" + group.kind.rawValue
                ) { chooseGroup(index) }
            }
            selector(
                tunerText("All"),
                range: String(format: tunerText("%d strings"), strings.count),
                accessibilityRange: nil,
                location: nil,
                wires: strings.indices,
                selected: showsAll,
                identifier: "tuner-strings-layout-all",
                action: showOverview
            )
        }
        .padding(2)
        .background {
            let panel = RoundedRectangle(cornerRadius: 12)
            panel.fill(p.top.opacity(p.dark ? 0.75 : 0.56))
                .overlay { panel.strokeBorder(p.ink.opacity(0.16), lineWidth: 0.75) }
        }
        .frame(width: Self.contentWidth)
    }

    private func selector(_ title: String, range: String, accessibilityRange: String?, location: Int?,
                          wires: Range<Int>, selected: Bool, identifier: String,
                          action: @escaping () -> Void) -> some View {
        let count = wires.filter(drawing.completed.contains).count
        return Button(action: action) {
            HStack(spacing: 5) {
                VStack(spacing: 2.5) {
                    ForEach(0..<3) { line in
                        let emphasized = location == nil || location == line
                        Capsule()
                            .frame(width: 13, height: emphasized ? 1.55 : 0.85)
                            .opacity(emphasized ? 1 : 0.31)
                            .frame(height: 1.6)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text(title).font(InstrumentType.value(13)).lineLimit(1).minimumScaleFactor(0.75)
                        if count == wires.count {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .semibold))
                        }
                    }
                    Text(range).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
        }
        .buttonStyle(GuzhengSegmentStyle(p: p, selected: selected))
        .accessibilityLabel(accessibilityRange.map { title + ", " + $0 } ?? tunerText("All strings"))
        .accessibilityValue(String(format: tunerText("%d / %d in tune"), count, wires.count))
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var overviewArtwork: some View {
        let proportion = TunerGuzhengArtwork.size
        let width = Self.contentWidth + 8
        let height = width * proportion.height / proportion.width * 1.13
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        return Canvas { context, _ in
            TunerGuzhengArtwork.drawOverview(in: context, frame: frame, surface: p.tunerDrawingSurface, drawing: drawing)
        }
        .frame(width: frame.width, height: frame.height)
        .contentShape(Rectangle())
        .modifier(TunerReferenceGesture { action, point in
            if let index = TunerGuzhengArtwork.string(at: point, in: frame) { select(index, action) }
        })
        .accessibilityHidden(true)
    }

    private var overviewTargets: some View {
        VStack(spacing: 2) {
            ForEach(groups) { group in
                if group.id != groups.first?.id {
                    Rectangle().fill(p.edge.opacity(0.48)).frame(height: 0.5)
                }
                HStack(spacing: 0) {
                    Text(group.kind.guzhengPositionTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(p.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .frame(width: 32, alignment: .leading)
                    ForEach(Array(group.wires.reversed()), id: \.self) { index in
                        stringButton(index, overview: true)
                    }
                }
            }
        }
        .frame(width: Self.contentWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuner-targets")
    }

    private func detailArtwork(_ group: TunerStringGroup) -> some View {
        let top = group.kind == .low ? Self.farRimY : 0
        let bottom = group.kind == .high ? Self.nearRimY : Self.detailHeight
        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let frame = CGRect(x: Self.bodyLeft, y: top, width: Self.detailWidth - Self.bodyLeft - 6, height: bottom - top)
                TunerGuzhengArtwork.drawDetail(in: context, frame: frame, wires: group.wires,
                                               firstWireY: Self.firstWireY, rowHeight: Self.detailRowHeight,
                                               surface: p.tunerDrawingSurface, drawing: drawing)
            }
            .accessibilityHidden(true)
            VStack(spacing: 0) {
                ForEach(Array(group.wires.reversed()), id: \.self) { index in
                    stringButton(index, overview: false)
                }
            }
            .padding(.top, Self.firstWireY - Self.detailRowHeight / 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tuner-targets")
        }
        .frame(width: Self.detailWidth, height: Self.detailHeight)
    }

    private func stringButton(_ index: Int, overview: Bool) -> some View {
        let tuned = drawing.completed.contains(index)
        let playing = soundingString == index
        let active = drawing.active == index
        let pitch = strings[index]
        let color = playing ? p.tunerReferenceInk : tuned ? p.tuningGreen : p.ink
        let number = Text(String(index + 1))
            .font(.system(size: overview ? 10 : 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(playing || tuned ? color : overview ? p.muted : p.ink)
        let note = HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(TunerPitch.name(pitch)).font(InstrumentType.value(overview ? 14 : 17))
            Text(String(TunerPitch.octave(pitch))).font(InstrumentType.value(overview ? 9.5 : 11))
        }
        .foregroundStyle(color)
        return Button { select(index, .tap) } label: {
            if overview {
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        number
                        if tuned { stringIndicator("checkmark", ink: p.tuningGreen) }
                    }
                    note
                }
                .frame(maxWidth: .infinity)
                .frame(height: Self.rowHeight)
                .background {
                    if active || playing {
                        RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)).padding(2)
                    }
                }
                .contentShape(Rectangle())
            } else {
                HStack(spacing: 4) {
                    number.frame(width: 18, alignment: .trailing)
                    note
                    if tuned { stringIndicator("checkmark", ink: p.tuningGreen) }
                }
                .frame(width: 63, height: 27, alignment: .leading)
                .background {
                    if active || playing { RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.10)) }
                }
                .frame(width: Self.detailWidth, height: Self.detailRowHeight, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(TunerReferenceButtonStyle { select(index, $0 ? .hold : .release) })
        .disabled(!canPlay)
        .accessibilityLabel("\(index + 1), " + TunerPitch.label(pitch))
        .accessibilityHint(tunerText(playing ? "Stop tone" : "Reference tone"))
        .accessibilityValue(drawing.accessibilityValue(for: index))
        .accessibilityIdentifier("tuner-string-\(index)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func stringIndicator(_ name: String, ink: Color) -> some View {
        Image(systemName: name).font(.system(size: 9, weight: .semibold))
            .foregroundStyle(ink).accessibilityHidden(true)
    }
}

private struct GuzhengSegmentStyle: ButtonStyle {
    let p: InstrumentPalette
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? p.tunerDrawingSurface : p.ink)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(p.ink.opacity(selected ? 1 : configuration.isPressed ? 0.10 : 0))
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed && selected ? 0.82 : 1)
    }
}

private extension TunerStringGroup.Kind {
    var guzhengPositionTitle: String {
        switch self {
        case .high: tunerText("Near")
        case .middle: tunerText("Middle section")
        case .low: tunerText("Far")
        default: tunerText(title)
        }
    }
}
