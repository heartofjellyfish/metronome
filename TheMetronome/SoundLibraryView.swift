import SwiftUI

struct SoundCardRow: View {
    @ObservedObject var model: MetronomeModel
    let sounds: [InstrumentSound]
    let namespace: String
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        HStack(spacing: 13) {
            ForEach(sounds, id: \.rawValue) { sound in
                Button { model.selectSound(sound.rawValue) } label: {
                    ZStack(alignment: .topLeading) {
                        LED(on: model.rhythm.sound == sound.rawValue, color: InstrumentPalette.amber, size: 10).padding(13)
                        VStack(spacing: 11) {
                            SoundIllustration(index: sound.illustration, p: p).frame(height: 60)
                            Text(sound.title).technical(11, spacing: 0.7).lineLimit(1).minimumScaleFactor(0.8)
                        }.frame(maxWidth: .infinity).padding(.top, 37)
                    }.frame(maxWidth: .infinity).frame(height: 134)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 11))
                    .accessibilityLabel("\(sound.title) sound, tap to preview")
                    .accessibilityIdentifier("\(namespace)-sound-\(sound.rawValue)")
                    .accessibilityAddTraits(model.rhythm.sound == sound.rawValue ? .isSelected : [])
            }
            ForEach(0..<max(0, 3 - sounds.count), id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
            }
        }
    }
}

/// Every family stays expanded. Recommendations are editorial choices, not popularity rankings.
struct SoundLibraryView: View {
    @ObservedObject var model: MetronomeModel
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        VStack(alignment: .leading, spacing: 27) {
            SoundDynamicsControl(model: model, namespace: "library-")
            family("01 ACOUSTIC", subtitle: "REAL DRUMS / HATS & PERCUSSION", rows: [
                [.naturalHiHat, .acousticPedal, .rim],
                [.acousticStick, .crossStick, .ride],
                [.acousticShaker, .snap, .clap]
            ], namespace: "acoustic")
            family("02 CLASSIC", subtitle: "WOOD / CLICK / BELL", rows: [[.wood, .click, .bell]], namespace: "classic")
            Text(model.playing ? "CHANGES PLAY LIVE" : "ONE BAR PREVIEW")
                .technical(8, spacing: 0.9).lineSpacing(6).foregroundStyle(p.muted)
        }
    }
    private func family(_ title: String, subtitle: String, rows: [[InstrumentSound]], namespace: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: title, p: p)
            Text(subtitle).technical(8, spacing: 1).foregroundStyle(p.muted)
            ForEach(rows.indices, id: \.self) { index in
                SoundCardRow(model: model, sounds: rows[index], namespace: namespace)
            }
        }
    }
}

struct SoundDynamicsControl: View {
    @ObservedObject var model: MetronomeModel
    var namespace = ""
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    var body: some View {
        HStack(spacing: 12) {
            Text("DYNAMICS").technical(10, spacing: 1)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                ForEach([true, false], id: \.self) { enabled in
                    Button { model.setDynamics(enabled) } label: {
                        HStack(spacing: 7) {
                            LED(on: model.rhythm.followsMeter == enabled, color: InstrumentPalette.amber, size: 6)
                            Text(enabled ? "ACCENT" : "EVEN").technical(10, spacing: 0.7)
                        }.frame(width: 96, height: 32)
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 7))
                        .accessibilityIdentifier(namespace + (enabled ? "dynamics-meter" : "dynamics-even"))
                        .accessibilityLabel(enabled ? "Follow meter accents" : "Even intensity")
                        .accessibilityAddTraits(model.rhythm.followsMeter == enabled ? .isSelected : [])
                }
            }
        }.foregroundStyle(p.ink)
    }
}
