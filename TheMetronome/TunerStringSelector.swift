import SwiftUI

enum TunerStringListLayout: String, CaseIterable {
    case grouped, all

    var title: String { self == .grouped ? "Grouped" : "All strings" }
}

struct TunerStringGroup: Identifiable {
    enum Kind: String {
        case high, middle, low, main, sympathetic

        var title: String {
            switch self {
            case .high: "High register"
            case .middle: "Middle register"
            case .low: "Low register"
            case .main: "Playing strings"
            case .sympathetic: "Sympathetic strings"
            }
        }
    }

    let kind: Kind
    let wires: Range<Int>
    var id: Kind { kind }
    var sharesNumbering: Bool { kind == .high || kind == .middle || kind == .low }

    var subtitle: String {
        if sharesNumbering {
            return "\(wires.lowerBound + 1)–\(wires.upperBound)"
        }
        return String(format: tunerText("%d strings"), wires.count)
    }

    func number(for wire: Int) -> Int {
        wire + 1 - (sharesNumbering ? 0 : wires.lowerBound)
    }

    func stringName(for wire: Int) -> String {
        let key = kind == .sympathetic ? "Sympathetic string %d" : "String %d"
        return String(format: tunerText(key), number(for: wire))
    }

    static func groups(for instrument: String, stringCount: Int) -> [Self] {
        switch (instrument, stringCount) {
        case ("Guzheng", TunerGuzhengArtwork.stringCount):
            [.init(kind: .low, wires: 14..<21), .init(kind: .middle, wires: 7..<14), .init(kind: .high, wires: 0..<7)]
        case ("Sitar", 18...20):
            [.init(kind: .main, wires: 0..<TunerSitar.baseCount),
             .init(kind: .sympathetic, wires: TunerSitar.baseCount..<stringCount)]
        default:
            []
        }
    }
}

struct TunerStringSelector: View {
    let p: InstrumentPalette
    let groups: [TunerStringGroup]
    let layout: TunerStringListLayout
    let groupIndex: Int
    let completed: Set<Int>
    let chooseLayout: (TunerStringListLayout) -> Void
    let chooseGroup: (Int) -> Void
    let key: (Int, TunerStringGroup) -> TunerStringTarget

    private static var rowHeight: CGFloat { 44 }
    private static var gap: CGFloat { 4 }
    private static var controlHeight: CGFloat { 44 }
    private static var labelHeight: CGFloat { 16 }

    private static func gridHeight(_ group: TunerStringGroup) -> CGFloat {
        let rows = (group.wires.count + 6) / 7
        return CGFloat(rows) * rowHeight + CGFloat(rows - 1) * gap
    }

    // Reserve the same footprint in both layouts so the meter and tuning button don't jump.
    var height: CGFloat {
        let grouped = 2 * Self.controlHeight + 2 * Self.gap + (groups.map(Self.gridHeight).max() ?? 0)
        let overview = Self.controlHeight + groups.reduce(CGFloat.zero) {
            $0 + Self.gridHeight($1) + Self.gap + ($1.sharesNumbering ? 0 : Self.labelHeight)
        }
        return max(grouped, overview)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            header
            if layout == .grouped {
                groupPicker
                grid(groups[groupIndex])
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        if !group.sharesNumbering {
                            Text(tunerText(group.kind.title))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(p.muted)
                                .frame(height: Self.labelHeight)
                        }
                        grid(group)
                    }
                }
            }
        }
        .frame(height: height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuner-targets")
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(TunerStringListLayout.allCases, id: \.self) { option in
                    let selected = option == layout
                    Button { chooseLayout(option) } label: {
                        Text(tunerText(option.title))
                            .font(InstrumentType.value(13)).lineLimit(1).minimumScaleFactor(0.75)
                            .foregroundStyle(selected ? p.ink : p.muted)
                            .frame(maxWidth: .infinity).frame(height: Self.controlHeight)
                            .overlay(alignment: .bottom) {
                                if selected {
                                    Capsule().fill(p.ink).frame(width: 19, height: 1.5).padding(.bottom, 7)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tuner-strings-layout-" + option.rawValue)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .frame(width: 156)
            Spacer(minLength: 0)
            Text(String(format: tunerText("%d / %d in tune"), completed.count, groups.last?.wires.upperBound ?? 0))
                .font(.system(size: 13, weight: .medium)).monospacedDigit()
                .foregroundStyle(p.muted).lineLimit(1).minimumScaleFactor(0.8)
                .accessibilityIdentifier("tuner-strings-progress")
        }
        .frame(height: Self.controlHeight)
    }

    private var groupPicker: some View {
        HStack(spacing: 2) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                Button { chooseGroup(index) } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(tunerText(group.kind.title))
                                .lineLimit(1).minimumScaleFactor(0.75)
                            if group.wires.allSatisfy(completed.contains) {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .semibold))
                            }
                        }
                        .font(InstrumentType.value(13))
                        Text(group.subtitle).font(.system(size: 11)).opacity(0.78)
                    }
                    .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: index == groupIndex))
                .accessibilityIdentifier("tuner-strings-group-" + group.kind.rawValue)
                .accessibilityAddTraits(index == groupIndex ? .isSelected : [])
            }
        }
        .padding(2).insetPanel(p, radius: 10)
    }

    private func grid(_ group: TunerStringGroup) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: Self.gap) {
            ForEach(group.wires, id: \.self) { index in key(index, group) }
        }
    }
}

struct TunerStringTarget: View {
    let drawing: TunerStringDrawing
    let index: Int
    let pitch: Int
    let number: Int?
    let numberSize: CGFloat
    let emphasizeSelection: Bool
    let accessibilityName: String?
    let select: () -> Void

    var body: some View {
        let p = drawing.palette
        let selected = drawing.active == index
        let tuned = drawing.completed.contains(index)
        Button(action: select) {
            VStack(spacing: 2) {
                if let number {
                    Text(String(number))
                        .font(.system(size: numberSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(p.ink.opacity(0.68))
                }
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(TunerPitch.name(pitch)).font(InstrumentType.value(17))
                    Text(String(TunerPitch.octave(pitch))).font(InstrumentType.value(11))
                }
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background {
                if emphasizeSelection && selected {
                    let shape = RoundedRectangle(cornerRadius: 8)
                    shape.fill((tuned ? p.tuningGreen : p.ink).opacity(0.09))
                        .overlay { shape.strokeBorder(p.edge.opacity(0.6), lineWidth: 0.6) }
                }
            }
            .overlay(alignment: .topTrailing) {
                if tuned {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(p.tuningGreen).padding(3)
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .foregroundStyle(drawing.color(for: index))
            .accessibilityLabel((accessibilityName ?? "\(index + 1)") + ", " + TunerPitch.label(pitch))
            .accessibilityValue(tuned ? tunerText("In tune") : "")
            .accessibilityIdentifier("tuner-string-\(index)")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
