import SwiftUI

struct PolyrhythmPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    @Binding var soundLane: Int?
    @State private var expanded = false
    private var upper: Int { model.rhythm.polyrhythmPrimary ?? 3 }
    private var lower: Int { model.rhythm.crossRhythm ?? model.rhythm.polyrhythmStoredSecondary ?? 2 }
    var body: some View {
        Group {
            if let soundLane { soundPicker(soundLane) }
            else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.text("Rhythm")).font(.system(size: 20, weight: .semibold)).padding(.bottom, 12)
                    HStack(spacing: 0) {
                        ratio(3, 2, 4)
                        Divider()
                        ratio(4, 3, 5)
                        Divider()
                        Button { expanded.toggle() } label: {
                            Text(L10n.text("More")).font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }.buttonStyle(.plain).accessibilityIdentifier("poly-more")
                    }.frame(height: 40)
                        .background(p.bottom)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(p.edge.opacity(0.7), lineWidth: 0.7))
                    if expanded {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ratio(5, 4, 3); ratio(5, 3, 2); ratio(7, 4, 3); ratio(7, 5, 3)
                        }.padding(.top, 10)
                    }
                    seam.padding(.top, 20)
                    lane(upper, index: 0)
                    seam
                    lane(lower, index: 1)
                    if let count = model.rhythm.polyrhythmThird {
                        seam
                        lane(count, index: 2)
                    }
                    HStack {
                        Spacer()
                        Button {
                            if model.rhythm.polyReference == 2 { model.rhythm.polyrhythmReference = 0 }
                            model.rhythm.polyrhythmThird = model.rhythm.polyrhythmThird == nil ? 4 : nil
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: model.rhythm.polyrhythmThird == nil ? "plus" : "minus")
                                Text(L10n.text(model.rhythm.polyrhythmThird == nil ? "Add voice C" : "Remove voice C")).lineLimit(1)
                            }.font(.system(size: 14, weight: .medium)).padding(.horizontal, 12).frame(height: 40)
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 20)).accessibilityIdentifier("poly-third")
                    }.padding(.top, 12)
                }.padding(16)
                    .background { HardwareKeySurface(p: p, radius: 24).allowsHitTesting(false) }
            }
        }.onDisappear { model.endSoundPreview() }
    }
    private var seam: some View {
        Rectangle().fill(p.edge.opacity(0.55)).frame(height: 0.5)
            .overlay(alignment: .bottom) { Rectangle().fill(p.light).frame(height: 0.5).offset(y: 0.5) }
    }
    private func configure(_ a: Int, _ b: Int, third: Int? = nil) {
        model.endSoundPreview()
        var rhythm = model.rhythm
        let tempo = rhythm.polyDisplayTempo
        if let third { rhythm.polyrhythmThird = third }
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
    private func ratio(_ a: Int, _ b: Int, _ c: Int) -> some View {
        let third = model.rhythm.polyrhythmThird == nil ? nil : c
        let selected = model.rhythm.crossCount > 0 && upper == a && lower == b && model.rhythm.polyrhythmThird == third
        return Button { configure(a, b, third: third) } label: {
            Text(third.map { "\(a):\(b):\($0)" } ?? "\(a):\(b)").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(selected ? p.body : p.ink).background(selected ? p.ink : .clear)
        }.buttonStyle(.plain)
            .accessibilityIdentifier("polyrhythm-\(a)-\(b)")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func lane(_ count: Int, index: Int) -> some View {
        let muted = index == 0 ? model.rhythm.polyrhythmPrimaryMuted == true : index == 1 ? model.rhythm.polyrhythmSecondaryMuted == true : model.rhythm.polyrhythmThirdMuted == true
        let color = PolyrhythmRings.color(index)
        return HStack(spacing: 6) {
                Text(["A", "B", "C"][index]).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 28, height: 28)
                    .background(color, in: Circle())
                Button { soundLane = index } label: {
                    HStack {
                        Text(instrument(index).title).font(.system(size: 14, weight: .medium)).lineLimit(2)
                        Image(systemName: "chevron.down").font(.caption2)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 2).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("poly-lane-\(index)")
            HStack(spacing: 0) {
                Button { changeCount(index, count - 1) } label: {
                    Image(systemName: "minus").frame(width: 44, height: 44).contentShape(Rectangle())
                }.disabled(count <= 1).accessibilityIdentifier("poly-minus-\(index)")
                Rectangle().fill(p.edge.opacity(0.6)).frame(width: 0.5, height: 22)
                Text("\(count)").font(InstrumentType.value(22)).monospacedDigit().frame(width: 26)
                Rectangle().fill(p.edge.opacity(0.6)).frame(width: 0.5, height: 22)
                Button { changeCount(index, count + 1) } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44).contentShape(Rectangle())
                }.disabled(count >= 12).accessibilityIdentifier("poly-plus-\(index)")
            }.buttonStyle(.plain)
                .background { HardwareKeySurface(p: p, radius: 22) }
                Button {
                    if index == 0 { model.rhythm.polyrhythmPrimaryMuted = !muted }
                    else if index == 1 { model.rhythm.polyrhythmSecondaryMuted = !muted }
                    else { model.rhythm.polyrhythmThirdMuted = !muted }
                } label: {
                    Image(systemName: muted ? "speaker.slash" : "speaker.wave.2")
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: muted, radius: 22))
                    .accessibilityIdentifier("poly-mute-\(index)")
                    .accessibilityLabel("Mute " + ["A", "B", "C"][index])
                    .accessibilityValue(muted ? "Muted" : "Audible")
        }.padding(.vertical, 14)
    }
}
