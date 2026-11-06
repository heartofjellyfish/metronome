import SwiftUI

private struct ExitLiveModeKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var exitLiveMode: () -> Void {
        get { self[ExitLiveModeKey.self] }
        set { self[ExitLiveModeKey.self] = newValue }
    }
}

/// The performance surface shares the transport and clock with the instrument.
/// Opening, closing and muting this view never starts, stops or resets that clock.
struct PerformanceView: View {
    @ObservedObject var model: MetronomeModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var showingNotes = false
    @State private var showingTitle = false
    @Environment(\.exitLiveMode) private var exitLiveMode
    private var notes: String { model.currentSong?.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
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
                    Text(model.activeSetlist?.name ?? L10n.text("Setlists"))
                        .font(.system(size: 18, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Button { editing = true } label: { Text("Edit").frame(minWidth: 54, minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p)).disabled(model.currentSong == nil).accessibilityIdentifier("performance-edit")
                    Button { exitLiveMode() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Return to metronome").accessibilityIdentifier("exit-live-mode")
                }
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let position, let list = model.activeSetlist {
                                Text(L10n.format("Song %d of %d", position + 1, list.songs.count))
                                    .font(.system(size: 13)).foregroundStyle(p.muted).accessibilityIdentifier("performance-position")
                            }
                            Text(model.currentSong?.name ?? L10n.text("Setlists"))
                                .font(.system(size: 25, weight: .semibold)).lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("performance-song")
                            if (model.currentSong?.name.count ?? 0) > 20 {
                                Button { showingTitle = true } label: { Text("Full title").font(.caption).padding(10) }
                                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("full-song-title")
                            }
                            HStack(spacing: 15) {
                                Text("\(model.bpm) BPM").monospacedDigit().accessibilityIdentifier("performance-tempo")
                                Text("·").accessibilityHidden(true)
                                Text("\(model.rhythm.beats)/\(model.rhythm.denominator)").accessibilityIdentifier("performance-meter")
                                Text("·").accessibilityHidden(true)
                                RhythmScore(rhythm: model.rhythm, color: p.muted).frame(width: 76, height: 32)
                                    .accessibilityHidden(false).accessibilityLabel("Subdivision").accessibilityValue(model.rhythm.divisionSummary).accessibilityIdentifier("performance-division")
                            }.font(.system(size: 17, weight: .medium)).foregroundStyle(p.muted).padding(.top, 6)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        PerformanceBeatCue(model: model, p: p)
                            .frame(height: max(260, min(460, geometry.size.height - (notes.isEmpty ? 420 : 485))))
                            .frame(maxWidth: .infinity).insetPanel(p, radius: 18)
                        if !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(notes).font(.system(size: 15)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("performance-notes")
                                Button { showingNotes = true } label: { Label("View notes", systemImage: "note.text").font(.system(size: 13)).padding(.horizontal, 12).frame(minHeight: 36) }
                                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("view-song-notes")
                            }
                        }
                        if model.interrupted { Text("AUDIO INTERRUPTED").font(.subheadline).foregroundStyle(InstrumentPalette.orange) }
                    }
                }.scrollBounceBehavior(.basedOnSize).scrollClipDisabled()
                songNavigation
                GeometryReader { controls in
                  HStack(spacing: 14) {
                    Button { model.tap(); model.adjustCurrentSongTempo(model.bpm) } label: {
                        Text("TAP").font(.system(size: 16, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }.buttonStyle(HardwareButtonStyle(p: p)).frame(width: (controls.size.width - 14) * 0.4).accessibilityIdentifier("performance-tap")
                    Button { model.toggle() } label: {
                        TransportGlyph(playing: model.transportActive).frame(maxWidth: .infinity).frame(height: 64).contentShape(Rectangle())
                    }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                        .accessibilityLabel(L10n.text(model.transportActive ? "Stop metronome" : "Start metronome"))
                        .accessibilityIdentifier("performance-play")
                        .layoutPriority(1)
                  }
                }.frame(height: 64)
            }.padding(22).frame(maxWidth: 600).frame(maxWidth: .infinity)
                .accessibilityHidden(editing || showingNotes || showingTitle)
                .background { InstrumentBody(p: p).ignoresSafeArea() }
                .overlay {
                    if showingNotes {
                        overlayPanel("Notes", close: { showingNotes = false }) { Text(notes).font(.title3).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    } else if showingTitle {
                        overlayPanel("Full title", close: { showingTitle = false }) { Text(model.currentSong?.name ?? "").font(.title2).frame(maxWidth: .infinity, alignment: .leading) }
                    } else if editing, let current = model.currentSong {
                        overlayPanel("Edit song", close: { editing = false }) {
                            if model.listsContainingSong(current.id) > 1 { Text("Changes apply in every setlist.").font(.subheadline).foregroundStyle(p.muted) }
                            SongEditor(model: model, initial: current, p: p, cancel: { editing = false }) { value in
                                model.editSong(value.id, name: value.name, rhythm: value.rhythm, notes: value.notes); editing = false
                            }.id(current.id)
                        }
                    }
                }
        }.foregroundStyle(p.ink).preferredColorScheme(model.dark ? .dark : .light)

    }
    private var songNavigation: some View {
        HStack(spacing: 12) {
            Button { model.performPedal(.previous) } label: {
                Image(systemName: "backward.end.fill").frame(width: 58, height: 64)
            }.buttonStyle(HardwareButtonStyle(p: p))
                .disabled(position == nil || position == 0).opacity(position == nil || position == 0 ? 0.4 : 1)
                .accessibilityLabel(PedalAction.previous.title).accessibilityIdentifier("performance-previous")
            Button { model.performPedal(.next) } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(nextSong == nil ? "End of setlist" : "Up next").font(.system(size: 12)).foregroundStyle(p.muted)
                        if let nextSong { Text(nextSong.name).font(.system(size: 18, weight: .semibold)).lineLimit(1) }
                    }
                    Spacer(minLength: 0)
                    if let nextSong {
                        Text("\(nextSong.rhythm.bpm) BPM").font(.system(size: 13)).foregroundStyle(p.muted).fixedSize()
                        Image(systemName: "forward.end.fill").font(.system(size: 18, weight: .semibold))
                    }
                }.padding(.horizontal, 14).frame(maxWidth: .infinity).frame(height: 64).contentShape(Rectangle())
            }.buttonStyle(HardwareButtonStyle(p: p)).disabled(nextSong == nil).opacity(nextSong == nil ? 0.45 : 1)
                .accessibilityIdentifier("performance-next")
        }
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
