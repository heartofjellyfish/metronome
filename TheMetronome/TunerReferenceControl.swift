import SwiftUI

struct TunerReferenceControl: View {
    static let noteRange = 20...108
    private static let octaves = TunerPitch.octave(noteRange.lowerBound)...TunerPitch.octave(noteRange.upperBound)

    let p: InstrumentPalette
    let note: Int
    let held: Int?
    let playing: Bool
    let canPlay: Bool
    @Binding var pickerOpen: Bool
    let choose: (Int?) -> Void
    let togglePlayback: () -> Void

    @State private var octave = 4
    @Environment(\.dynamicTypeSize) private var textSize
    private let titleFont = Font.custom("HelveticaNeue-Medium", size: 15, relativeTo: .subheadline)

    var body: some View {
        let stacked = textSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            Button {
                octave = TunerPitch.octave(note)
                pickerOpen = true
            } label: {
                HStack(spacing: 6) {
                    Text(tunerText("Target note"))
                    Text(TunerPitch.label(note)).fontWeight(.semibold)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(tunerText("Target note"))
            .accessibilityValue(TunerPitch.label(note))
            .accessibilityIdentifier("tuner-reference-target")
            .popover(isPresented: $pickerOpen, arrowEdge: .bottom) {
                picker
                    .presentationBackground(p.body)
                    .presentationCompactAdaptation(.popover)
            }

            if stacked {
                Rectangle().fill(p.ink.opacity(0.18)).frame(height: 1).padding(.horizontal, 14)
                    .accessibilityHidden(true)
            } else {
                Rectangle().fill(p.ink.opacity(0.18)).frame(width: 1, height: 24)
                    .accessibilityHidden(true)
            }

            Button(action: togglePlayback) {
                HStack(spacing: 8) {
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                        .font(.system(size: stacked ? 17 : 15, weight: .semibold))
                    Text(tunerText(playing ? "Stop" : "Reference tone"))
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(playing ? Color(hex: 0xF5F0E2) : p.ink)
                .background {
                    if playing {
                        UnevenRoundedRectangle(bottomLeadingRadius: stacked ? 11 : 0, bottomTrailingRadius: 11,
                                               topTrailingRadius: stacked ? 0 : 11)
                            .fill(LinearGradient(colors: [Color(hex: 0x3D3F3D), Color(hex: 0x292B29)],
                                                 startPoint: .top, endPoint: .bottom))
                            .padding(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(!canPlay)
            .accessibilityLabel(tunerText(playing ? "Stop tone" : "Reference tone"))
            .accessibilityIdentifier("tuner-reference-play")
        }
        .font(titleFont)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .buttonStyle(.plain)
        .background { HardwareKeySurface(p: p, radius: 13) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuner-reference-control")
    }

    private var picker: some View {
        VStack(spacing: 10) {
            HStack {
                Text(tunerText("Target note")).font(.headline)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { pickerOpen = false } label: {
                    Text(L10n.text("Done")).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).frame(minHeight: 44)
                }
                .buttonStyle(HardwareButtonStyle(p: p, shallow: true))
                .accessibilityIdentifier("tuner-reference-done")
            }
            HStack {
                octaveButton(-1, icon: "chevron.left", label: "Lower octave")
                Spacer()
                Text(tunerText("Octave") + " " + octave.formatted())
                    .font(titleFont).monospacedDigit()
                Spacer()
                octaveButton(1, icon: "chevron.right", label: "Higher octave")
            }
            let notes = Self.noteRange.filter { TunerPitch.octave($0) == octave }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(notes, id: \.self) { pitch in
                    Button { choose(pitch) } label: {
                        Text(TunerPitch.name(pitch)).font(titleFont)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: note == pitch))
                    .accessibilityLabel(TunerPitch.label(pitch))
                    .accessibilityAddTraits(note == pitch ? .isSelected : [])
                    .accessibilityIdentifier("tuner-reference-note-\(pitch)")
                }
            }
            Button { choose(nil) } label: {
                HStack {
                    Text(tunerText("Auto-detect notes"))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if held == nil { Image(systemName: "checkmark").accessibilityHidden(true) }
                }
                .font(titleFont).padding(.horizontal, 10).frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(held == nil ? .isSelected : [])
            .accessibilityIdentifier("tuner-reference-auto")
        }
        .foregroundStyle(p.ink)
        .padding(16)
        .frame(width: textSize.isAccessibilitySize ? 310 : 282)
    }

    private func octaveButton(_ step: Int, icon: String, label: String) -> some View {
        Button { octave += step } label: {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!Self.octaves.contains(octave + step))
        .accessibilityLabel(tunerText(label))
    }
}
