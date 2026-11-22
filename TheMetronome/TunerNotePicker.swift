import SwiftUI

struct TunerNotePicker: View {
    let p: InstrumentPalette
    let groups: [TunerCheckGroup]
    let groupLabel: String
    @Binding var groupIndex: Int
    let notation: TunerPitchNotation
    let selected: Int?
    let automatic: Bool
    let choose: (Int?) -> Void
    let expandSheet: () -> Void

    @State private var draft = ""
    @State private var enteringNote = false
    @FocusState private var fieldFocused: Bool

    private var target: Int? {
        let offset = notation.primaryOffset
        return TunerProfile.parseNotes(draft, maximumCount: 1, range: (20 + offset)...(108 + offset))?
            .first.map { $0 - offset }
    }
    private var group: TunerCheckGroup { groups[min(groupIndex, groups.count - 1)] }

    var body: some View {
        option(tunerText("All notes"), isCurrent: automatic && selected == nil, id: "tuner-check-auto") {
            choose(nil)
        }
        VStack(alignment: .leading, spacing: 9) {
            if groups.count > 1 {
                Menu {
                    Picker(tunerText(groupLabel), selection: $groupIndex) {
                        ForEach(groups.indices, id: \.self) { index in
                            Text(tunerText(groups[index].title)).tag(index)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(tunerText(group.title)).font(InstrumentType.value(16))
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .accessibilityLabel(tunerText(groupLabel))
                .accessibilityValue(tunerText(group.title))
                .accessibilityIdentifier("tuner-note-set")
            } else {
                Text(tunerText(group.title)).font(InstrumentType.value(13))
            }

            if notation.hasTransposition {
                Text(tunerText(notation.primaryTitle) + " / " + tunerText(notation.secondaryTitle))
                    .font(.caption).foregroundStyle(p.ink.opacity(0.72))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                ForEach(group.notes, id: \.self) { pitch in
                    let isCurrent = selected == pitch
                    Button { choose(pitch) } label: {
                        VStack(spacing: 2) {
                            Text(TunerPitch.label(pitch + notation.primaryOffset, flats: true))
                                .font(InstrumentType.value(18))
                            if notation.hasTransposition {
                                Text(TunerPitch.label(pitch + notation.secondaryOffset, flats: true))
                                    .font(.caption.monospacedDigit())
                                    .opacity(0.72)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(minHeight: notation.hasTransposition ? 60 : 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: isCurrent))
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    .accessibilityIdentifier("tuner-check-\(pitch)")
                }
            }
            .padding(5).insetPanel(p, radius: 12)
        }
        .padding(.top, 5)

        let other = selected.flatMap { pitch in
            groups.contains { $0.notes.contains(pitch) }
                ? nil : TunerPitch.label(pitch + notation.primaryOffset, flats: true)
        }
        option(other ?? tunerText("Other note"), isCurrent: other != nil, id: "tuner-check-other") {
            enteringNote.toggle()
            if enteringNote {
                expandSheet()
                draft = other ?? ""
            }
        }
        if enteringNote {
            HStack(spacing: 8) {
                TextField("C4", text: $draft)
                    .font(InstrumentType.value(17))
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .submitLabel(.done).onSubmit(applyDraft)
                    .focused($fieldFocused).padding(12).insetPanel(p, radius: 9)
                    .accessibilityLabel(tunerText("Note with octave"))
                    .accessibilityIdentifier("tuner-check-input")
                Button(tunerText("Use note"), action: applyDraft)
                    .font(InstrumentType.value(15)).padding(.horizontal, 13).frame(height: 44)
                    .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                    .disabled(target == nil)
                    .accessibilityIdentifier("tuner-check-apply")
            }
        }
    }

    private func applyDraft() {
        guard let target else { return }
        fieldFocused = false
        enteringNote = false
        choose(target)
    }

    private func option(_ title: String, isCurrent: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(InstrumentType.value(16))
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                } else if id == "tuner-check-other" {
                    Image(systemName: enteringNote ? "chevron.up" : "chevron.down").font(.caption)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12).frame(minHeight: 46)
        }
        .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: isCurrent))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
