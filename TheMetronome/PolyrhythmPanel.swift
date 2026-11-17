import SwiftUI

struct PolyrhythmPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    @Binding var soundLane: Int?
    @State private var expanded = false
    private var upper: Int { model.rhythm.polyrhythmPrimary ?? 3 }
    private var lower: Int { model.rhythm.crossRhythm ?? model.rhythm.polyrhythmStoredSecondary ?? 2 }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let soundLane { soundPicker(soundLane) }
            else {
                lane(upper, index: 0)
                lane(lower, index: 1)
                if let count = model.rhythm.polyrhythmThird { lane(count, index: 2) }
                HStack(spacing: 10) {
                    ratio(3, 2); ratio(4, 3)
                    Button { expanded.toggle() } label: {
                        HStack(spacing: 5) {
                            Text(L10n.text("More"))
                            Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption2)
                        }.font(.system(size: 15)).frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("poly-more")
                }
                if expanded {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ratio(5, 4); ratio(5, 3); ratio(7, 4); ratio(7, 5)
                    }
                    Button {
                        if model.rhythm.polyReference == 2 { model.rhythm.polyrhythmReference = 0 }
                        model.rhythm.polyrhythmThird = model.rhythm.polyrhythmThird == nil ? 4 : nil
                    } label: {
                        Label(L10n.text(model.rhythm.polyrhythmThird == nil ? "Add voice C" : "Remove voice C"), systemImage: model.rhythm.polyrhythmThird == nil ? "plus" : "minus")
                            .font(.system(size: 14)).frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("poly-third")
                }
            }
        }.onDisappear { model.endSoundPreview() }
    }
    private func configure(_ a: Int, _ b: Int) {
        model.endSoundPreview()
        var rhythm = model.rhythm
        let tempo = rhythm.polyDisplayTempo
        rhythm.polyrhythmPrimary = a
        rhythm.polyrhythmStoredSecondary = b
        rhythm.crossRhythm = b
        rhythm.polyrhythmTempoIsSecondary = true
        rhythm.polyrhythmCycleSeconds = 60 * Double(rhythm.polyCounts[rhythm.polyReference]) / tempo
        model.rhythm = rhythm
    }
    private func changeCount(_ lane: Int, _ count: Int) {
        let tempo = model.rhythm.polyDisplayTempo
        if lane == 2 { model.rhythm.polyrhythmThird = count }
        else { configure(lane == 0 ? count : upper, lane == 1 ? count : lower) }
        model.rhythm.polyrhythmCycleSeconds = 60 * Double(model.rhythm.polyCounts[model.rhythm.polyReference]) / tempo
    }
    private func instrument(_ lane: Int) -> InstrumentSound {
        InstrumentSound(rawValue: lane == 0 ? model.rhythm.primaryPulseSound : lane == 1 ? model.rhythm.secondaryPulseSound : model.rhythm.thirdPulseSound) ?? .wood
    }
    private func soundPicker(_ lane: Int) -> some View {
        VStack(spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(InstrumentSound.allCases, id: \.rawValue) { sound in
                    let selected = instrument(lane) == sound
                    Button {
                        if lane == 0 { model.rhythm.polyrhythmPrimarySound = sound.rawValue }
                        else if lane == 1 { model.rhythm.polyrhythmSecondarySound = sound.rawValue }
                        else { model.rhythm.polyrhythmThirdSound = sound.rawValue }
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
        Button { configure(a, b) } label: {
            Text("\(a):\(b)").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: model.rhythm.crossCount > 0 && upper == a && lower == b))
            .accessibilityIdentifier("polyrhythm-\(a)-\(b)")
            .accessibilityAddTraits(model.rhythm.crossCount > 0 && upper == a && lower == b ? .isSelected : [])
    }
    private func lane(_ count: Int, index: Int) -> some View {
        let muted = index == 0 ? model.rhythm.polyrhythmPrimaryMuted == true : index == 1 ? model.rhythm.polyrhythmSecondaryMuted == true : model.rhythm.polyrhythmThirdMuted == true
        let color = PolyrhythmRings.color(index)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(["A", "B", "C"][index]).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 28, height: 28)
                    .background(color, in: RoundedRectangle(cornerRadius: 6))
                Button { soundLane = index } label: {
                    HStack {
                        Text(instrument(index).title).font(.system(size: 17, weight: .medium)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("poly-lane-\(index)")
                Button {
                    if index == 0 { model.rhythm.polyrhythmPrimaryMuted = !muted }
                    else if index == 1 { model.rhythm.polyrhythmSecondaryMuted = !muted }
                    else { model.rhythm.polyrhythmThirdMuted = !muted }
                } label: {
                    Image(systemName: muted ? "speaker.slash" : "speaker.wave.2")
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                    .accessibilityIdentifier("poly-mute-\(index)")
                    .accessibilityLabel("Mute " + ["A", "B", "C"][index])
                    .accessibilityValue(muted ? "Muted" : "Audible")
            }
            HStack(spacing: 0) {
                Button { changeCount(index, count - 1) } label: {
                    Image(systemName: "minus").frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.disabled(count <= 1).accessibilityIdentifier("poly-minus-\(index)")
                Rectangle().fill(p.edge.opacity(0.6)).frame(width: 0.5, height: 22)
                Text("\(count)").font(InstrumentType.value(25)).monospacedDigit().frame(maxWidth: .infinity)
                Rectangle().fill(p.edge.opacity(0.6)).frame(width: 0.5, height: 22)
                Button { changeCount(index, count + 1) } label: {
                    Image(systemName: "plus").frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.disabled(count >= 12).accessibilityIdentifier("poly-plus-\(index)")
            }.buttonStyle(.plain)
                .background(p.top, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(p.edge.opacity(0.5), lineWidth: 0.5))
        }.padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(p.top)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 3))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.light, lineWidth: 1))
    }
}
