import SwiftUI

struct PolyrhythmPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    @Binding var soundLane: Int?
    private var upper: Int { model.rhythm.polyrhythmPrimary ?? 3 }
    private var lower: Int { model.rhythm.crossRhythm ?? model.rhythm.polyrhythmStoredSecondary ?? 2 }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let soundLane { soundPicker(soundLane) }
            else {
                lane(upper, index: 0)
                lane(lower, index: 1)
                HStack(spacing: 10) { ratio(3, 2); ratio(4, 3); ratio(5, 4) }
                HStack(spacing: 10) {
                    Text("Polyrhythm").font(.system(size: 13)).foregroundStyle(p.muted)
                    Spacer()
                    ForEach([false, true], id: \.self) { on in
                        Button {
                            if on { configure(upper, lower) }
                            else { model.rhythm.polyrhythmStoredSecondary = lower; model.rhythm.crossRhythm = nil }
                        } label: { Text(L10n.text(on ? "ON" : "OFF")).frame(width: 60, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, charcoal: (model.rhythm.crossCount > 0) == on))
                            .accessibilityIdentifier(on ? "polyrhythm-on" : "polyrhythm-off")
                    }
                }
            }
        }.onDisappear { model.endSoundPreview() }
    }
    private func configure(_ a: Int, _ b: Int) {
        model.endSoundPreview()
        var rhythm = model.rhythm
        rhythm.polyrhythmPrimary = a
        rhythm.polyrhythmStoredSecondary = b
        rhythm.crossRhythm = b
        rhythm.polyrhythmTempoIsSecondary = true
        model.rhythm = rhythm
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
        Button { configure(a, b) } label: {
            Text("\(a):\(b)").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: model.rhythm.crossCount > 0 && upper == a && lower == b))
            .accessibilityIdentifier("polyrhythm-\(a)-\(b)")
            .accessibilityAddTraits(model.rhythm.crossCount > 0 && upper == a && lower == b ? .isSelected : [])
    }
    private func lane(_ count: Int, index: Int) -> some View {
        let muted = index == 0 ? model.rhythm.polyrhythmPrimaryMuted == true : model.rhythm.polyrhythmSecondaryMuted == true
        let color = PolyrhythmRings.color(index)
        return HStack(spacing: 8) {
            Text(index == 0 ? "A" : "B").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white).frame(width: 26, height: 30).background(color, in: RoundedRectangle(cornerRadius: 6))
            Button { configure(index == 0 ? count - 1 : upper, index == 1 ? count - 1 : lower) } label: {
                Image(systemName: "minus").frame(width: 34, height: 44)
            }.disabled(count <= 2).accessibilityIdentifier("poly-minus-\(index)")
            Text("\(count)").font(InstrumentType.value(24)).monospacedDigit().frame(width: 22)
            Button { configure(index == 0 ? count + 1 : upper, index == 1 ? count + 1 : lower) } label: {
                Image(systemName: "plus").frame(width: 34, height: 44)
            }.disabled(count >= (index == 0 ? 8 : 9)).accessibilityIdentifier("poly-plus-\(index)")
            Button { soundLane = index } label: {
                Text(instrument(index).title).font(.system(size: 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(alignment: .bottom) { Capsule().fill(color).frame(width: 20, height: 2).padding(.bottom, 5) }
            }.accessibilityIdentifier("poly-lane-\(index)")
            Button {
                if index == 0 { model.rhythm.polyrhythmPrimaryMuted = !muted }
                else { model.rhythm.polyrhythmSecondaryMuted = !muted }
            } label: {
                Image(systemName: muted ? "speaker.slash" : "speaker.wave.2").frame(width: 40, height: 44)
            }.accessibilityIdentifier("poly-mute-\(index)")
                .accessibilityLabel(index == 0 ? "Mute A" : "Mute B")
                .accessibilityValue(muted ? "Muted" : "Audible")
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
    }
}
