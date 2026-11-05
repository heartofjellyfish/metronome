import SwiftUI

/// The performance surface shares the transport and clock with the instrument.
/// Opening, closing and muting this view never starts, stops or resets that clock.
struct PerformanceView: View {
    @ObservedObject var model: MetronomeModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var choosingSong = false
    @State private var panel: InstrumentPanelKind?
    private var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    private var position: Int? { model.activeSetlist?.songs.firstIndex { $0.id == model.selectedSongID } }
    private var nextSong: SavedPreset? {
        guard let list = model.activeSetlist, let position, list.songs.indices.contains(position + 1) else { return nil }
        return list.songs[position + 1]
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Setlists").accessibilityIdentifier("close-performance")
                    Button { choosingSong = true } label: {
                        HStack(spacing: 6) { Text(model.activeSetlist?.name ?? L10n.text("Setlists")).lineLimit(1); Image(systemName: "chevron.down").font(.caption) }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("performance-choose-song")
                    Spacer(minLength: 0)
                    if let position { Text("\(position + 1)/\(model.activeSetlist?.songs.count ?? 0)").font(.subheadline).foregroundStyle(p.muted) }
                    Button("Edit") { editing = true }.frame(minWidth: 44, minHeight: 44).disabled(model.currentSong == nil).accessibilityIdentifier("performance-edit")
                }
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            Text(model.currentSong?.name ?? L10n.text("Setlists")).font(.system(size: 33, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.65).multilineTextAlignment(.center)
                                .accessibilityIdentifier("performance-song")
                            Button { panel = .tempo } label: {
                                HStack(alignment: .lastTextBaseline, spacing: 8) {
                                    Text("\(model.bpm)").font(InstrumentType.display(min(146, geometry.size.width * 0.34))).lineLimit(1).minimumScaleFactor(0.6)
                                    Text("BPM").technical(12, spacing: 1).foregroundStyle(p.muted)
                                }.frame(maxWidth: .infinity).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(L10n.format("Tempo, %d BPM. Tap to enter a value", model.bpm)).accessibilityIdentifier("performance-tempo")
                            HStack(spacing: 22) {
                                Button { panel = .meter } label: { Text("\(model.rhythm.beats)/\(model.rhythm.denominator)").font(InstrumentType.value(24)).frame(minWidth: 60, minHeight: 44) }.accessibilityIdentifier("performance-meter")
                                Button { panel = .division } label: { RhythmScore(rhythm: model.rhythm, color: p.ink).frame(width: 80, height: 44) }.accessibilityLabel("Subdivision").accessibilityIdentifier("performance-division")
                            }.buttonStyle(.plain).foregroundStyle(p.muted)
                            PerformanceBeatCue(model: model, p: p).frame(minHeight: 70)
                            if model.interrupted { Text("AUDIO INTERRUPTED").font(.subheadline).foregroundStyle(InstrumentPalette.orange) }
                        }.padding(22).frame(maxWidth: .infinity).insetPanel(p, radius: 18)
                        HStack(spacing: 12) {
                            tempoKey("minus", delta: -1)
                            Button { model.tap(); model.adjustCurrentSongTempo(model.bpm) } label: { Text("TAP").technical(14, spacing: 1).frame(maxWidth: .infinity, minHeight: 48) }
                                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("performance-tap")
                            tempoKey("plus", delta: 1)
                            Button { model.soundEnabled.toggle() } label: {
                                Image(systemName: model.soundEnabled ? "speaker.wave.2" : "speaker.slash").frame(width: 52, height: 48)
                            }.buttonStyle(HardwareButtonStyle(p: p, charcoal: !model.soundEnabled))
                                .accessibilityLabel(L10n.text(model.soundEnabled ? "Mute sound" : "Turn sound on"))
                                .accessibilityValue(L10n.text(model.soundEnabled ? "Sound on" : "Visual only"))
                                .accessibilityIdentifier("performance-sound")
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(nextSong == nil ? "End of setlist" : "Up next").font(.subheadline).foregroundStyle(p.muted)
                                if let nextSong { Text(nextSong.name).font(.headline).lineLimit(2) }
                            }
                            Spacer()
                            if let nextSong { Text("\(nextSong.rhythm.bpm) BPM").font(.subheadline).foregroundStyle(p.muted) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    }
                }.scrollBounceBehavior(.basedOnSize)
                SetlistTransport(model: model, p: p, prefix: "performance")
            }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
                .accessibilityHidden(panel != nil || editing || choosingSong)
                .background { InstrumentBody(p: p).ignoresSafeArea() }
                .overlay {
                    if editing, let current = model.currentSong {
                        overlayPanel("Edit song", close: { editing = false }) {
                            if model.listsContainingSong(current.id) > 1 { Text("Changes apply in every setlist.").font(.subheadline).foregroundStyle(p.muted) }
                            SongEditor(model: model, initial: current, p: p, cancel: { editing = false }) { value in
                                model.editSong(value.id, name: value.name, rhythm: value.rhythm); editing = false
                            }.id(current.id)
                        }
                    } else if choosingSong {
                        overlayPanel("Setlists", close: { choosingSong = false }) {
                            ForEach(model.activeSetlist?.songs ?? []) { song in
                                Button { model.loadSong(song); choosingSong = false } label: {
                                    HStack { Text(song.name); Spacer(); Text("\(song.rhythm.bpm) BPM") }.padding(18).frame(minHeight: 60)
                                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: model.selectedSongID == song.id)).accessibilityIdentifier("performance-select-\(song.name)")
                            }
                        }
                    } else if let panel {
                        InstrumentPanel(model: model, kind: panel) { self.panel = nil }
                    }
                }
        }.foregroundStyle(p.ink).preferredColorScheme(model.dark ? .dark : .light)
            .onChange(of: model.rhythm) { _, value in
                // Only direct performance pickers write back; pedal switches already load a song.
                if panel != nil, let song = model.currentSong, song.rhythm != value.performanceCopy {
                    model.editSong(song.id, name: song.name, rhythm: value)
                }
            }
    }
    private func tempoKey(_ icon: String, delta: Int) -> some View {
        Button { model.adjustCurrentSongTempo(model.bpm + delta) } label: { Image(systemName: icon).frame(width: 48, height: 48) }
            .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel(delta > 0 ? "Increase tempo" : "Decrease tempo")
            .accessibilityIdentifier(delta > 0 ? "performance-plus" : "performance-minus")
            .disabled(delta > 0 ? model.bpm >= 300 : model.bpm <= 20)
    }
    private func overlayPanel<Content: View>(_ title: String, close: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack { Text(L10n.text(title)).font(.title3); Spacer(); Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("close-performance-overlay") }
                ScrollView { VStack(spacing: 18, content: content).padding(.bottom, 10) }
            }.padding(22).frame(maxWidth: 550).background { InstrumentBody(p: p) }.clipShape(RoundedRectangle(cornerRadius: 22)).padding(10)
        }.accessibilityElement(children: .contain)
    }
}

struct PerformanceBeatCue: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    var body: some View {
        let count = model.rhythm.pulseCount
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(count, 6)), spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                let active = model.playing && model.event?.beat == index
                Text(String(index + 1)).font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity).frame(height: count > 6 ? 40 : 60)
                    .foregroundStyle(active ? p.well : p.muted)
                    .background(RoundedRectangle(cornerRadius: 8).fill(active ? p.ink : p.muted.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(index == 0 ? p.ink.opacity(0.35) : .clear, lineWidth: 1))
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Beat indicator")
            .accessibilityValue(model.playing ? String((model.event?.beat ?? 0) + 1) : L10n.text("Stopped"))
            .accessibilityIdentifier("performance-beat")
    }
}
