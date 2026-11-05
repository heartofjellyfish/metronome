import SwiftUI

struct PolyrhythmPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    @State private var advanced = false
    @Binding var soundLane: Int?
    @State private var rememberedLower = 2
    private var upper: Int { model.rhythm.polyrhythmPrimary ?? 3 }
    private var lower: Int { model.rhythm.crossRhythm ?? rememberedLower }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let soundLane { soundPicker(soundLane) }
            else {
                HStack(spacing: 10) {
                    ForEach([false, true], id: \.self) { on in
                        Button {
                            model.endSoundPreview(); rememberedLower = lower
                            model.rhythm.polyrhythmPrimary = upper
                            model.rhythm.crossRhythm = on ? lower : nil
                        } label: { Text(L10n.text(on ? "ON" : "OFF")).frame(maxWidth: .infinity, minHeight: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, charcoal: (model.rhythm.crossCount > 0) == on))
                            .accessibilityIdentifier(on ? "polyrhythm-on" : "polyrhythm-off")
                            .accessibilityAddTraits((model.rhythm.crossCount > 0) == on ? .isSelected : [])
                    }
                }
                HStack(spacing: 10) { ratio(3, 2); ratio(4, 3); ratio(5, 4) }
                // One recessed cycle contains two voices, each with its own instrument key.
                VStack(spacing: 22) {
                    lane(upper, index: 0)
                    Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5)
                    lane(lower, index: 1)
                }.padding(18).insetPanel(p, radius: 14)
                Text("Both rows start and finish together.").font(.subheadline).foregroundStyle(p.muted)
                Button { advanced.toggle() } label: {
                    HStack { Text("Other ratios"); Spacer(); Image(systemName: advanced ? "chevron.up" : "chevron.down") }.padding(.horizontal, 16).frame(minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("polyrhythm-more")
                if advanced {
                    countRow(instrument(0).title, value: upper, range: 2...8) { model.rhythm.polyrhythmPrimary = $0; model.rhythm.crossRhythm = lower }
                    countRow(instrument(1).title, value: lower, range: 2...9) { model.rhythm.polyrhythmPrimary = upper; model.rhythm.crossRhythm = $0 }
                }
            }
        }.onDisappear { model.endSoundPreview() }
    }
    private func instrument(_ lane: Int) -> InstrumentSound {
        InstrumentSound(rawValue: lane == 0 ? model.rhythm.primaryPulseSound : model.rhythm.secondaryPulseSound) ?? .wood
    }
    private func soundPicker(_ lane: Int) -> some View {
        VStack(spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(InstrumentSound.allCases, id: \.rawValue) { sound in
                    let selected = instrument(lane) == sound
                    Button {
                        if lane == 0 { model.rhythm.polyrhythmPrimarySound = sound.rawValue }
                        else { model.rhythm.polyrhythmSecondarySound = sound.rawValue }
                    } label: {
                        VStack(spacing: 10) {
                            SoundIllustration(index: sound.illustration, p: p).frame(height: 54)
                            Text(sound.title).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        }.padding(.top, 27).padding(.bottom, 14).frame(maxWidth: .infinity)
                            .overlay(alignment: .topLeading) { LED(on: selected, size: 8).padding(13) }
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("poly-sound-\(sound.rawValue)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
    private func ratio(_ a: Int, _ b: Int) -> some View {
        Button {
            model.endSoundPreview(); model.rhythm.polyrhythmPrimary = a; model.rhythm.crossRhythm = b
        } label: { Text(L10n.format("%d over %d", a, b)).font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity, minHeight: 48) }
            .buttonStyle(HardwareButtonStyle(p: p, charcoal: model.rhythm.crossCount > 0 && upper == a && lower == b))
            .accessibilityIdentifier("polyrhythm-\(a)-\(b)")
            .accessibilityAddTraits(model.rhythm.crossCount > 0 && upper == a && lower == b ? .isSelected : [])
    }
    private func lane(_ count: Int, index: Int) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                Button { soundLane = index } label: {
                    HStack(spacing: 10) {
                        SoundIllustration(index: instrument(index).illustration, p: p).frame(width: 32, height: 32)
                        Text(instrument(index).title).font(.system(size: 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(.horizontal, 12).frame(minHeight: 48)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("poly-lane-\(index)")
                Text("\(count)").font(InstrumentType.value(30)).frame(width: 32)
            }
            HStack(spacing: 8) { ForEach(0..<count, id: \.self) { _ in Capsule().fill(index == 0 ? p.ink : p.muted).frame(maxWidth: .infinity).frame(height: 6) } }
        }
    }
    private func countRow(_ title: String, value: Int, range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).lineLimit(1); Spacer()
            Button { set(value-1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }.disabled(value == range.lowerBound)
            Text("\(value)").font(InstrumentType.value(25)).frame(width: 32)
            Button { set(value+1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.disabled(value == range.upperBound)
        }.buttonStyle(HardwareButtonStyle(p: p))
    }
}
