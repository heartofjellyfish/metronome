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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.currentSong?.name ?? L10n.text("Setlists"))
                                .font(.system(size: 25, weight: .semibold)).lineLimit(2)
                                .accessibilityIdentifier("performance-song")
                            HStack(spacing: 20) {
                                Button { panel = .tempo } label: {
                                    Text("\(model.bpm) BPM").font(.system(size: 16, weight: .medium)).frame(minHeight: 44)
                                }.accessibilityLabel(L10n.format("Tempo, %d BPM. Tap to enter a value", model.bpm)).accessibilityIdentifier("performance-tempo")
                                Button { panel = .meter } label: {
                                    Text("\(model.rhythm.beats)/\(model.rhythm.denominator)").font(.system(size: 16, weight: .medium)).frame(minWidth: 44, minHeight: 44)
                                }.accessibilityIdentifier("performance-meter")
                                Button { panel = .division } label: {
                                    RhythmScore(rhythm: model.rhythm, color: p.ink).frame(width: 88, height: 44)
                                }.accessibilityLabel("Subdivision").accessibilityValue(model.rhythm.divisionSummary).accessibilityIdentifier("performance-division")
                            }.buttonStyle(.plain).foregroundStyle(p.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        PerformanceBeatCue(model: model, p: p)
                            .frame(height: max(260, min(460, geometry.size.height - 420)))
                            .frame(maxWidth: .infinity).insetPanel(p, radius: 18)
                        if model.interrupted { Text("AUDIO INTERRUPTED").font(.subheadline).foregroundStyle(InstrumentPalette.orange) }
                        HStack(spacing: 12) {
                            tempoKey("minus", delta: -1)
                            Button { model.tap(); model.adjustCurrentSongTempo(model.bpm) } label: { Text("TAP").technical(14, spacing: 1).frame(maxWidth: .infinity, minHeight: 48) }
                                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("performance-tap")
                            tempoKey("plus", delta: 1)

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
        let current = model.playing ? model.event?.beat : nil
        let strength = current.map { model.rhythm.beatStrength($0, counting: model.event?.countIn == true) } ?? 0
        GeometryReader { geometry in
            VStack(spacing: 6) {
                Text(">")
                    .font(.system(size: 40, weight: .bold))
                    .opacity(strength == 2 ? 1 : strength == 4 ? 0.45 : 0)
                    .frame(height: 36)
                    .accessibilityHidden(true)
                Text(current.map { String($0 + 1) } ?? "—")
                    .font(InstrumentType.display(min(geometry.size.height * 0.72, geometry.size.width * 0.72)))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(current == nil || strength == 0 ? p.muted : p.ink)
                    .contentTransition(.identity)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: min(count, 6)), spacing: 10) {
                    ForEach(0..<count, id: \.self) { index in
                        let accent = model.rhythm.beatStrength(index)
                        Circle().fill(current == index ? p.ink : .clear)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(p.ink.opacity(accent == 0 ? 0.25 : 0.7), lineWidth: 1.2))
                            .overlay { if accent == 2 { Circle().stroke(p.ink.opacity(0.7), lineWidth: 1.2).padding(-4) } }
                            .frame(height: 22)
                    }
                }.frame(maxWidth: 260).padding(.bottom, 2)
            }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.foregroundStyle(p.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Beat indicator")
            .accessibilityValue(current.map { String($0 + 1) } ?? L10n.text("Stopped"))
            .accessibilityIdentifier("performance-beat")
    }
}
