import SwiftUI

struct TunerInstrumentIcon: View {
    let profile: TunerProfile
    let layout: TunerHeadstock?
    let p: InstrumentPalette
    var selected = false

    var body: some View {
        Group {
            if profile == .chromatic {
                Image(systemName: "circle.dotted").font(.system(size: 25))
            } else if profile.instrumentName == "Guzheng" {
                TunerGuzhengArtwork.pickerIcon(p, selected: selected)
            } else if TunerRuanHeadstock.forInstrument(profile.instrumentID) != nil {
                TunerRuanHeadstock.pickerIcon(p, selected: selected)
            } else if let headstock = TunerChineseHeadstock.forInstrument(profile.instrumentID, stringCount: profile.strings.count) {
                headstock.pickerIcon(p, selected: selected)
            } else if profile.family == TunerProfile.middleEasternFamily,
                      let headstock = TunerRegionalHeadstock.forInstrument(profile.instrumentID, stringCount: profile.strings.count) {
                headstock.middleEasternPickerIcon(p, selected: selected)
            } else if let layout {
                layout.pickerIcon(p, selected: selected)
            } else if profile.family == "Custom tuning" {
                Image(systemName: TunerProfile.icon(profile.family)).font(.system(size: 18))
            } else {
                let name = profile.diagramName
                let pickerAsset = UIImage(named: name + "-picker")
                let artwork = pickerAsset.map(Image.init(uiImage:)) ?? Image(name)
                artwork.renderingMode(.template).resizable().scaledToFit().frame(width: 35, height: 32)
            }
        }
        .frame(width: 36, height: 32)
        .accessibilityHidden(true)
    }
}

struct TunerLibrary: View {
    let p: InstrumentPalette
    let selected: String
    let selectedProfile: String?
    let custom: [TunerProfile]
    let preferredLayout: (TunerProfile) -> TunerHeadstock?
    let choose: (TunerProfile, TunerHeadstock?) -> Void
    let close: () -> Void

    @State private var expandedInstrument: String?
    @State private var creating = false
    @State private var customName = ""
    @State private var customNotes = ""

    private struct Family: Identifiable {
        let id: String
        let quick: [String]

        init(_ id: String, _ quick: [String]) {
            self.id = id
            self.quick = quick
        }
    }

    private static let families = [
        Family("Chromatic", ["Chromatic"]),
        Family("Guitar", ["Guitar", "7-string guitar", "12-string guitar"]),
        Family("Ukulele", ["Ukulele", "Baritone ukulele"]),
        Family("Bass", ["Bass", "5-string bass", "6-string bass"]),
        Family("Bowed strings", ["Violin", "Viola", "Cello", "Double bass"]),
        Family("Plucked strings", ["5-string banjo", "Mandolin"]),
        Family("Woodwinds", ["B♭ clarinet"] + TunerProfile.availableCatalog
            .filter { $0.family == "Woodwinds" && $0.id != "B♭ clarinet" }.map(\.id))
    ]

    private static let additionalFamilies = TunerProfile.families.compactMap { family -> Family? in
        guard !["Guitar & bass", "Bowed strings", "Plucked strings", "Woodwinds", "Custom tuning"].contains(family) else {
            return nil
        }
        let instruments = TunerProfile.availableCatalog.filter { $0.family == family && $0.title == $0.instrumentName }
        return Family(family, instruments.map(\.id))
    }

    private static let availableFamilies = (families + additionalFamilies).filter { family in
        family.id == "Chromatic" || family.quick.contains { id in
            TunerProfile.availableCatalog.contains { $0.id == id }
        }
    }

    private var parsed: [Int]? { TunerProfile.parseNotes(customNotes) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(tunerText("Instruments")).font(InstrumentType.value(24))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(HardwareButtonStyle(p: p))
                .accessibilityLabel(L10n.text("Close"))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Self.availableFamilies) { family in
                            if family.id != Self.families.first?.id { divider }
                            familyRow(family).id("family-" + family.id)
                        }
                        divider
                        customInstruments.id("family-Custom tuning")
                    }
                }
                .scrollIndicators(.hidden, axes: .vertical)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("tuner-instrument-list")
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .mask {
                    GeometryReader { bounds in
                        edgeFade(along: bounds.size.width, from: .leading, to: .trailing)
                            .mask { edgeFade(along: bounds.size.height, from: .top, to: .bottom) }
                    }
                }
                .padding(5)
                .insetPanel(p, radius: 15)
                .onAppear {
                    if TunerProfile.showsExtendedCatalog,
                       let family = Self.additionalFamilies.first(where: { $0.quick.contains(selected) }) {
                        proxy.scrollTo("family-" + family.id, anchor: .center)
                    } else if custom.contains(where: { $0.id == selected }) {
                        proxy.scrollTo("family-Custom tuning", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .foregroundStyle(p.ink)
    }

    private func edgeFade(along length: CGFloat, from start: UnitPoint, to end: UnitPoint) -> LinearGradient {
        let inset = min(0.5, 3 / max(1, length))
        return LinearGradient(stops: [.init(color: .clear, location: 0),
                                      .init(color: .black, location: inset),
                                      .init(color: .black, location: 1 - inset),
                                      .init(color: .clear, location: 1)],
                              startPoint: start, endPoint: end)
    }

    private func familyRow(_ family: Family) -> some View {
        let quick = profiles(family.quick)
        let title = tunerText(family.id == "Bass" ? "Electric bass" : family.id)
        let layoutRows = quick.first { $0.id == expandedInstrument }
            .flatMap(preferredLayout)?.options.count ?? 0
        let extraHeight = CGFloat(layoutRows) * Self.instrumentRowHeight

        return HStack(alignment: .top, spacing: 5) {
            Text(title).font(InstrumentType.value(12))
                .foregroundStyle(p.ink.opacity(p.dark ? 0.86 : 0.82))
                .lineLimit(2)
                .frame(width: Self.familyLabelWidth, height: Self.instrumentRowHeight, alignment: .leading)

            GeometryReader { grid in
                let gapWidth = CGFloat(Self.visibleColumns - 1) * Self.columnGap
                let contentWidth = max(0, grid.size.width - gapWidth - Self.continuationWidth)
                let column = contentWidth / CGFloat(Self.visibleColumns)
                profileLane(quick, family: family.id, column: column)
            }
            .frame(height: Self.instrumentRowHeight + extraHeight)
        }
        .padding(.leading, 8)
        .background(alignment: .leading) {
            Rectangle().fill(p.ink.opacity(p.dark ? 0.03 : 0.045))
                .frame(width: Self.familyLabelWidth + 10)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(p.edge.opacity(0.38)).frame(width: 0.5)
                }
        }
    }

    private static let visibleColumns = 4
    private static let familyLabelWidth: CGFloat = 85
    private static let columnGap: CGFloat = 4
    private static let instrumentRowHeight: CGFloat = 80
    private static let instrumentTileHeight: CGFloat = 70
    private static let continuationWidth: CGFloat = 8

    private func profileLane(_ profiles: [TunerProfile], family: String, column: CGFloat) -> some View {
        let hiddenColumns = profiles.count - Self.visibleColumns

        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Self.columnGap) {
                    ForEach(profiles) { profile in
                        instrumentColumn(profile, family: family)
                            .frame(width: column)
                            .id(profile.id)
                    }
                }
                .background {
                    if hiddenColumns > 0 { Rectangle().fill(p.ink.opacity(p.dark ? 0.045 : 0.023)) }
                }
                .scrollTargetLayout()
                // The trailing space lets the last four cells settle on the same grid.
                .padding(.trailing, hiddenColumns > 0 ? Self.continuationWidth : 0)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden, axes: .horizontal)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .accessibilityIdentifier("tuner-lane-" + family)
            .onAppear {
                if hiddenColumns > 0, let index = profiles.firstIndex(where: { $0.id == selected }) {
                    let start = min(max(index - 1, 0), hiddenColumns)
                    proxy.scrollTo(profiles[start].id, anchor: .leading)
                }
            }
        }
    }

    private func profiles(_ ids: [String]) -> [TunerProfile] {
        ids.compactMap { id in
            if id == TunerProfile.chromatic.id { return .chromatic }
            return TunerProfile.availableCatalog.first { $0.id == id }
        }
    }

    private func instrumentColumn(_ profile: TunerProfile, family: String) -> some View {
        let layout = preferredLayout(profile)
        let isSelected = selected == profile.id
        let isExpanded = expandedInstrument == profile.id

        return VStack(spacing: 0) {
            gridCell(highlighted: isExpanded) {
                quickTile(profile, family: family, layout: layout, isSelected: isSelected, isExpanded: isExpanded)
            }

            if isExpanded, let layout {
                ForEach(layout.options, id: \.self) { option in
                    gridCell(highlighted: true) {
                        layoutTile(option, profile: profile, preferred: layout == option)
                    }
                    .overlay(alignment: .top) { gridDivider }
                }
            }
        }
    }

    private func gridCell<Content: View>(highlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 2)
            .frame(height: Self.instrumentRowHeight)
            .background {
                if highlighted { Rectangle().fill(p.ink.opacity(p.dark ? 0.07 : 0.055)) }
            }
            .overlay(alignment: .trailing) {
                Rectangle().fill(p.edge.opacity(0.35))
                    .frame(width: 0.5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private var gridDivider: some View {
        Rectangle().fill(p.edge.opacity(0.5))
            .frame(height: 0.5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func quickTile(_ profile: TunerProfile, family: String, layout: TunerHeadstock?,
                           isSelected: Bool, isExpanded: Bool) -> some View {
        let hasChoices = layout?.options.isEmpty == false
        let showsStringCount = family == "Guitar" || family == "Bass"
        return Button {
            if hasChoices {
                expandedInstrument = isExpanded ? nil : profile.id
            } else {
                choose(profile, nil)
            }
        } label: {
            tileContent(tileLabel(profile, family: family), lineLimit: showsStringCount ? 1 : 2) {
                TunerInstrumentIcon(profile: profile, layout: layout, p: p, selected: isSelected)
            }
            .overlay(alignment: .bottom) {
                if hasChoices {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 6, weight: .semibold))
                        .opacity(isExpanded ? 0.85 : 0.65)
                        .padding(.bottom, 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: isSelected))
        .accessibilityLabel(tunerText(profile.title))
        .accessibilityValue(hasChoices ? tunerText(isExpanded ? "Expanded" : "Collapsed") : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tuner-profile-" + profile.id)
    }

    private func tileContent<Icon: View>(_ title: String, lineLimit: Int = 2,
                                         @ViewBuilder icon: () -> Icon) -> some View {
        let unbrokenLatinWord = title.unicodeScalars.allSatisfy {
            $0.isASCII && CharacterSet.letters.contains($0)
        }
        return VStack(spacing: 3) {
            icon().frame(width: 36, height: 32)
            Text(title).font(InstrumentType.value(11))
                .multilineTextAlignment(.center)
                .lineLimit(unbrokenLatinWord ? 1 : lineLimit)
                .allowsTightening(true)
                .minimumScaleFactor(unbrokenLatinWord ? 0.7 : 0.8)
                .padding(.horizontal, unbrokenLatinWord ? 1.5 : 3)
                .frame(maxWidth: .infinity)
                .frame(height: 26, alignment: .top)
        }
        .padding(.top, 9)
        .frame(maxWidth: .infinity)
        .frame(height: Self.instrumentTileHeight, alignment: .top)
    }

    private func layoutTile(_ option: TunerHeadstock, profile: TunerProfile, preferred: Bool) -> some View {
        let inUse = preferred && selected == profile.id
        return Button { choose(profile, option) } label: {
            tileContent(tunerText(option.title)) {
                option.pickerIcon(p, selected: inUse)
            }
            .overlay(alignment: .topTrailing) {
                if preferred && !inUse {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .semibold))
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: inUse))
        .accessibilityLabel(tunerText(profile.title) + ", " + tunerText(option.title))
        .accessibilityAddTraits(preferred ? .isSelected : [])
        .accessibilityIdentifier("tuner-layout-" + option.rawValue)
    }

    private func tileLabel(_ profile: TunerProfile, family: String) -> String {
        switch family {
        case "Chromatic": tunerText("All notes")
        case "Guitar", "Bass": String(format: tunerText("%d strings"), profile.strings.count)
        default: tunerText(profile.id == "Baritone ukulele" ? "Baritone" : profile.title)
        }
    }

    private var customInstruments: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tunerText("Custom tuning")).font(InstrumentType.value(15))
                .padding(.horizontal, 8).padding(.top, 11)
            ForEach(custom) { profile in profileRow(profile) }
            customTuning
        }
    }

    private var customTuning: some View {
        VStack(spacing: 10) {
            Button { creating.toggle() } label: {
                Label(tunerText("Create tuning"), systemImage: creating ? "minus" : "plus")
                    .frame(maxWidth: .infinity).frame(height: 44)
            }.buttonStyle(HardwareButtonStyle(p: p, shallow: true))
            if creating {
                field("Name", text: $customName)
                field("E2 A2 D3 G3 B3 E4", text: $customNotes)
                Text(tunerText("Enter string notes in playing order, with octaves.")).font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    guard let parsed else { return }
                    let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    choose(TunerProfile(name, "Custom tuning", parsed, id: UUID().uuidString), nil)
                } label: {
                    Text(L10n.text("Save")).frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                .disabled(parsed == nil || customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(8)
    }

    private var divider: some View {
        Rectangle().fill(p.edge.opacity(0.45)).frame(height: 0.5).padding(.horizontal, 7)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        TextField(tunerText(label), text: text).autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(.horizontal, 14).frame(height: 45).insetPanel(p, radius: 10)
    }

    private func profileRow(_ profile: TunerProfile) -> some View {
        let isSelected = profile.id == selectedProfile
        return VStack(spacing: 0) {
            Button { choose(profile, nil) } label: {
                HStack(spacing: 12) {
                    Image(systemName: TunerProfile.icon(profile.family)).frame(width: 26)
                    Text(profile.title)
                        .font(InstrumentType.value(15))
                    Spacer()
                    if isSelected { Image(systemName: "checkmark").font(.caption) }
                }.padding(.horizontal, 10).frame(minHeight: 44)
            }
            .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: isSelected))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("tuner-profile-" + profile.id)
            divider
        }
    }
}
