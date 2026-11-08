import SwiftUI

/// The performance surface shares the transport and clock with the instrument.
/// Opening, closing and muting this view never starts, stops or resets that clock.
struct PerformanceView: View {
    @ObservedObject var model: MetronomeModel
    var fromSongLibrary = false
    let back: () -> Void
    @State private var editing = false
    @State private var showingNotes = false
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
                ScrollView {
                    VStack(spacing: 18) {
                        songHeader
                        PerformanceBeatCue(model: model, p: p)
                            .frame(height: max(260, min(580, geometry.size.height - (model.activeSetlist == nil ? 300 : 410))))
                            .frame(maxWidth: .infinity).insetPanel(p, radius: 18).padding(.horizontal, 22)
                    }
                }.scrollBounceBehavior(.basedOnSize).scrollClipDisabled()
                if model.activeSetlist != nil { songNavigation.padding(.horizontal, 22) }
                GeometryReader { controls in
                  HStack(spacing: 14) {
                    Button { model.tap(live: true) } label: {
                        Text("TAP").font(.system(size: 16, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }.buttonStyle(HardwareButtonStyle(p: p)).frame(width: (controls.size.width - 14) * 0.4).accessibilityIdentifier("performance-tap")
                    Button { model.toggle() } label: {
                        Group {
                            if model.needsManualResume && !model.interrupted {
                                Label("Resume", systemImage: "play.fill")
                            } else { TransportGlyph(playing: model.transportActive) }
                        }.frame(maxWidth: .infinity).frame(height: 64).contentShape(Rectangle())
                    }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                        .disabled(model.interrupted && !model.transportActive)
                        .accessibilityLabel(model.transportLabel)
                        .accessibilityIdentifier("performance-play")
                        .layoutPriority(1)
                  }
                }.frame(height: 64).padding(.horizontal, 22)
            }.padding(.bottom, 22).frame(maxWidth: 600).frame(maxWidth: .infinity)
                .accessibilityHidden(editing || showingNotes)
                .allowsHitTesting(!editing && !showingNotes)
                .background { InstrumentBody(p: p).ignoresSafeArea() }
                .overlay {
                    if showingNotes {
                        overlayPanel {
                            VStack(spacing: 18) {
                                HStack {
                                    Text("Notes").font(.title3)
                                    Spacer()
                                    Button { showingNotes = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Close")
                                        .accessibilityIdentifier("close-performance-overlay")
                                }
                                ScrollView { Text(notes).font(.title3).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                            }.padding(22)
                        }
                    } else if editing, let current = model.currentSong {
                        overlayPanel {
                            SongEditor(model: model, initial: current, p: p, cancel: { editing = false }) { value in
                                model.editSong(value.id, name: value.name, rhythm: value.rhythm, notes: value.notes); editing = false
                            }.id(current.id)
                        }
                    }
                }
        }.foregroundStyle(p.ink).preferredColorScheme(model.dark ? .dark : .light)

    }
    private func editCurrentSong() {
        guard model.currentSong != nil else { return }
        editing = true
    }

    private var songHeader: some View {
        let panel = InstrumentPalette(dark: true)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 30)
                }
                .buttonStyle(LiveBackKeyStyle(palette: panel))
                .accessibilityLabel(L10n.text(fromSongLibrary ? "Song library" : "Song list"))
                .accessibilityIdentifier("close-performance")
                if let list = model.activeSetlist {
                    Text(list.name).font(.subheadline.weight(.medium)).foregroundStyle(Color(hex: 0xD4D0C7))
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("performance-setlist")
                }
                Spacer()
            }.padding(.leading, 11).padding(.trailing, 22)
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    if let position {
                        Text(String(format: "%02d", position + 1))
                            .font(InstrumentType.display(40)).foregroundStyle(Color(hex: 0xBDB9AF))
                            .accessibilityLabel(L10n.format("Song %d", position + 1))
                            .accessibilityIdentifier("performance-position")
                        Rectangle().fill(panel.muted.opacity(0.45)).frame(width: 1, height: 54)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.currentSong?.name ?? L10n.text("Song library"))
                            .font(.system(size: 44, weight: .bold)).tracking(-1).foregroundStyle(Color(hex: 0xF6F2E9)).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("performance-song")
                            .accessibilityAction(named: Text("Edit song"), editCurrentSong)
                            .accessibilityAction(.default, editCurrentSong)
                        HStack(spacing: 6) {
                            Text("\(model.bpm) BPM").monospacedDigit().accessibilityIdentifier("performance-tempo")
                            Text("·")
                            Text("\(model.rhythm.beats)/\(model.rhythm.denominator)").accessibilityIdentifier("performance-meter")
                            Text("·")
                            RhythmScore(rhythm: model.rhythm, color: panel.ink).frame(width: 58, height: 27)
                                .accessibilityHidden(false).accessibilityLabel("Subdivision").accessibilityValue(model.rhythm.divisionSummary)
                        }.font(.body).foregroundStyle(Color(hex: 0xDAD6CD))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: editCurrentSong)
                if !notes.isEmpty {
                    Button { showingNotes = true } label: { Text("Notes").font(.footnote).padding(.horizontal, 8).frame(minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: panel, radius: 8)).accessibilityIdentifier("view-song-notes")
                }
            }.padding(.horizontal, 22)
        }.padding(.top, 8).padding(.bottom, 14).foregroundStyle(panel.ink)
            .background {
                LinearGradient(colors: [Color(hex: 0x2A2928), Color(hex: 0x20201F)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay { MaterialGrain().opacity(0.055).blendMode(.overlay) }
            }
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
    private func overlayPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3).ignoresSafeArea()
            content().frame(maxWidth: 550).background { InstrumentBody(p: p) }
                .clipShape(RoundedRectangle(cornerRadius: 22)).padding(10)
        }.accessibilityElement(children: .contain)
    }
}

/// The key face is compact, while the whole 44-point target responds to a press.
private struct LiveBackKeyStyle: ButtonStyle {
    let palette: InstrumentPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.ink)
            .background { HardwareKeySurface(p: palette, radius: 6, pressed: configuration.isPressed) }
            .offset(y: configuration.isPressed ? 1 : 0)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

struct PerformanceBeatCue: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    var body: some View {
        let count = model.rhythm.pulseCount
        let current = model.playing ? model.event?.beat : nil
        let idleLabel = L10n.text(model.interrupted ? "Audio interrupted" : model.needsManualResume ? "Ready to resume" : "Ready?")
        let recovery = model.interrupted || model.needsManualResume
        let strength = current.map { model.rhythm.beatStrength($0, counting: model.event?.countIn == true) } ?? 0
        GeometryReader { geometry in
            VStack(spacing: 6) {
                Text(">")
                    .font(.system(size: 40, weight: .bold))
                    .opacity(strength == 2 ? 1 : strength == 4 ? 0.45 : 0)
                    .frame(height: 36)
                    .accessibilityHidden(true)
                Text(current.map { String($0 + 1) } ?? idleLabel)
                    .font(InstrumentType.display(recovery ? 40 : current == nil ? min(86, geometry.size.width * 0.25) : min(geometry.size.height * 0.72, geometry.size.width * 0.72)))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(current != nil && strength == 0 ? p.muted : p.ink)
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
            .accessibilityValue(current.map { String($0 + 1) } ?? (recovery ? idleLabel : L10n.text("Stopped")))
            .accessibilityIdentifier("performance-beat")
    }
}
