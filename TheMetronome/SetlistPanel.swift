import SwiftUI

struct SetlistPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    let close: () -> Void
    @State private var library: Bool
    @State private var editing = false
    @State private var adding = false
    @State private var source: String?
    @State private var listName = ""
    @State private var song: SavedPreset?
    @State private var sharing: SavedPreset?
    @State private var deleting: UUID?
    @State private var deletingList = false
    @State private var performing = false
    @State private var notice: String?
    init(model: MetronomeModel, p: InstrumentPalette, close: @escaping () -> Void) {
        self.model = model; self.p = p; self.close = close
        _library = State(initialValue: model.activeSetlist == nil)
    }
    private var detail: Bool { !library && song == nil && source == nil && sharing == nil }
    private var title: String {
        if song != nil { return L10n.text("Edit song") }
        if sharing != nil { return L10n.text("Add to setlist") }
        if source == "songs" { return L10n.text("Song library") }
        if source == "presets" { return L10n.text("PRESETS") }
        return library ? L10n.text("Setlists") : model.activeSetlist?.name ?? L10n.text("Setlists")
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(p.dark ? 0.55 : 0.3).ignoresSafeArea().onTapGesture { close() }.accessibilityHidden(true)
                VStack(spacing: 0) {
                    header
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                if let song {
                                    if model.listsContainingSong(song.id) > 1 {
                                        Text("Changes apply in every setlist.").font(.subheadline).foregroundStyle(p.muted)
                                    }
                                    SongEditor(model: model, initial: song, p: p, cancel: { self.song = nil }) { value in
                                        if model.songLibrary.contains(where: { $0.id == value.id }) { model.editSong(value.id, name: value.name, rhythm: value.rhythm) }
                                        else { model.addSong(value.name, bpm: value.rhythm.bpm, source: value.rhythm) }
                                        self.song = nil; adding = false
                                    }.id(song.id)
                                } else if let sharing { targets(sharing) }
                                else if library { listLibrary }
                                else if let source { sourceLibrary(source) }
                                else if let list = model.activeSetlist { listDetail(list) }
                            }.padding(20)
                        }.scrollBounceBehavior(.basedOnSize).scrollDismissesKeyboard(.interactively)
                            .onChange(of: model.selectedSongID) { _, id in
                                if detail, !editing, let id { withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) } }
                            }
                    }
                    if detail, !editing, model.activeSetlist?.songs.isEmpty == false {
                        SetlistTransport(model: model, p: p).padding(.horizontal, 20).padding(.vertical, 16)
                    }
                }.frame(maxWidth: 560).frame(height: geo.size.height - 12).accessibilityHidden(performing)
                    .background { InstrumentBody(p: p) }.clipShape(RoundedRectangle(cornerRadius: 23))
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(p.light, lineWidth: 0.8))
                    .padding(.horizontal, 10).padding(.bottom, 7).accessibilityElement(children: .contain)
            }.foregroundStyle(p.ink)
        }.fullScreenCover(isPresented: $performing) { PerformanceView(model: model) }
    }
    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                if !library {
                    Button {
                        if song != nil { song = nil }
                        else if sharing != nil { sharing = nil }
                        else if source != nil { source = nil }
                        else { library = true; editing = false; adding = false; listName = "" }
                        model.endSoundPreview(); notice = nil
                    } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Setlists").accessibilityIdentifier("choose-setlist")
                }
                Text(title).font(.system(size: 22, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if detail {
                    Button(editing ? "Done" : "Edit") {
                        if editing { model.renameSetlist(listName) }
                        else { listName = model.activeSetlist?.name ?? "" }
                        editing.toggle(); adding = false; deleting = nil; deletingList = false
                    }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("edit-setlist")
                }
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Close setlists").accessibilityIdentifier("close-panel")
            }
            Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5)
        }.padding(.horizontal, 20).padding(.top, 18)
    }
    private var listLibrary: some View {
        VStack(spacing: 14) {
            ForEach(model.setlists) { list in
                Button {
                    if model.activeSetlistID != list.id {
                        model.activeSetlistID = list.id
                        if let first = list.songs.first { model.loadSong(first) } else { model.stop() }
                    }
                    library = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) { Text(list.name).font(.headline); Text(L10n.format("%d songs", list.songs.count)).font(.subheadline).foregroundStyle(p.muted) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(18).frame(minHeight: 76)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("setlist-\(list.name)")
            }
            if model.setlists.isEmpty { Text("Your next show, song by song.").font(.subheadline).foregroundStyle(p.muted).padding(.vertical, 15) }
            HStack(spacing: 12) {
                TextField("Setlist name", text: $listName).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
                Button { model.addSetlist(listName); library = false; listName = "" } label: { Image(systemName: "plus").frame(width: 48, height: 48) }
                    .buttonStyle(HardwareButtonStyle(p: p)).disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Create setlist")
            }
        }
    }
    private func listDetail(_ list: SongSetlist) -> some View {
        VStack(spacing: 18) {
            if editing {
                HStack {
                    TextField("Setlist name", text: $listName).padding(14).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
                    Button("Rename") { model.renameSetlist(listName) }.frame(minHeight: 44)
                }
            } else {
                HStack {
                    Text(L10n.format("%d songs", list.songs.count)).font(.subheadline).foregroundStyle(p.muted)
                    Spacer()
                    Button {
                        if model.currentSong == nil, let first = list.songs.first { model.loadSong(first) }
                        performing = true
                    } label: { Label("Perform", systemImage: "arrow.up.left.and.arrow.down.right").padding(.horizontal, 14).frame(minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).disabled(list.songs.isEmpty).accessibilityIdentifier("open-performance")
                }
            }
            VStack(spacing: 10) {
                if list.songs.isEmpty { Text("Add your first song.").font(.subheadline).foregroundStyle(p.muted).padding(20) }
                ForEach(Array(list.songs.enumerated()), id: \.element.id) { index, value in
                    songRow(value).id(value.id)
                    if editing { editControls(value, index: index, count: list.songs.count) }
                    if index < list.songs.count-1 { Rectangle().fill(p.edge.opacity(0.3)).frame(height: 0.5).padding(.horizontal, 10) }
                }
                Button { adding.toggle(); notice = nil } label: { Label("Add song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-song")
                if adding {
                    Button("New song") { song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy) }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("new-song")
                    Button("Song library") { source = "songs" }.frame(maxWidth: .infinity, minHeight: 44).disabled(model.songLibrary.isEmpty).accessibilityIdentifier("import-songs")
                    Button("Add from presets") { source = "presets" }.frame(maxWidth: .infinity, minHeight: 44).disabled(model.presets.isEmpty).accessibilityIdentifier("import-presets")
                }
            }.padding(12).insetPanel(p, radius: 18)
            if let notice { Text(notice).font(.subheadline).foregroundStyle(p.muted) }
            if editing {
                Button("Delete setlist") { deletingList = true }.frame(minHeight: 44).foregroundStyle(p.muted)
                if deletingList {
                    Text("Delete this setlist? Songs stay in your library.").font(.subheadline)
                    HStack { Button("Cancel") { deletingList = false }; Spacer(); Button("DELETE") { model.deleteActiveSetlist(); deletingList = false; library = true; editing = false; listName = "" } }.frame(minHeight: 44)
                }
            }
        }
    }
    private func sourceLibrary(_ source: String) -> some View {
        VStack(spacing: 14) {
            if source == "presets" { Text("Adds a copy. Your preset stays unchanged.").font(.subheadline).foregroundStyle(p.muted) }
            ForEach(source == "songs" ? model.songLibrary : model.presets) { value in
                let exists = source == "songs" && model.activeSetlist?.songs.contains(where: { $0.id == value.id }) == true
                Button {
                    if source == "songs" { model.addExistingSong(value.id) }
                    else { model.importPreset(value) }
                    self.source = nil; adding = false
                    notice = source == "presets" && value.rhythm.hasPracticeEffects ? L10n.text("Song added. Practice effects stay in the preset.") : nil
                } label: {
                    HStack { Text(value.name); Spacer(); Text("\(value.rhythm.bpm) BPM").foregroundStyle(p.muted); Image(systemName: exists ? "checkmark" : "plus") }.padding(16).frame(minHeight: 60)
                }.buttonStyle(HardwareButtonStyle(p: p)).disabled(exists).accessibilityIdentifier("import-\(source == "songs" ? "song" : "preset")-\(value.name)")
            }
        }
    }
    private func targets(_ value: SavedPreset) -> some View {
        VStack(spacing: 14) {
            Text(value.name).font(.headline)
            ForEach(model.setlists) { list in
                let exists = list.songs.contains(where: { $0.id == value.id })
                Button { model.addExistingSong(value.id, to: list.id); sharing = nil } label: {
                    HStack { Text(list.name); Spacer(); Image(systemName: exists ? "checkmark" : "plus") }.padding(18).frame(minHeight: 60)
                }.buttonStyle(HardwareButtonStyle(p: p)).disabled(exists).accessibilityIdentifier("share-to-\(list.name)")
            }
        }
    }
    private func songRow(_ value: SavedPreset) -> some View {
        Button { if editing { song = value } else { model.loadSong(value) } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(value.name).font(.system(size: 17, weight: .medium)).multilineTextAlignment(.leading)
                    HStack(spacing: 12) {
                        Text("\(value.rhythm.beats)/\(value.rhythm.denominator)").font(.system(size: 12)).foregroundStyle(p.muted)
                        RhythmScore(rhythm: value.rhythm, color: p.muted).frame(width: 57, height: 24)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 3) { Text("\(value.rhythm.bpm)").font(InstrumentType.value(32)); Text("BPM").technical(8, spacing: 1).foregroundStyle(p.muted) }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 90).contentShape(Rectangle())
                .background { if model.selectedSongID == value.id { HardwareKeySurface(p: p, radius: 10) } }
        }.buttonStyle(.plain).accessibilityIdentifier("song-\(value.name)").accessibilityAddTraits(model.selectedSongID == value.id ? .isSelected : [])
    }
    private func editControls(_ value: SavedPreset, index: Int, count: Int) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button { model.moveSong(value.id, by: -1) } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityIdentifier("move-up-\(value.name)")
                Button { model.moveSong(value.id, by: 1) } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }.disabled(index == count-1).accessibilityIdentifier("move-down-\(value.name)")
                Button("Edit") { song = value }.frame(minHeight: 44).accessibilityIdentifier("edit-song-\(value.name)")
                Spacer()
                Button { sharing = value } label: { Image(systemName: "text.badge.plus").frame(width: 44, height: 44) }.accessibilityLabel("Add to setlist").accessibilityIdentifier("share-song-\(value.name)")
                Button { deleting = value.id } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }.accessibilityLabel("Remove from setlist").accessibilityIdentifier("delete-song-\(value.name)")
            }.foregroundStyle(p.muted)
            if deleting == value.id {
                Text("The song stays in your library.").font(.subheadline).foregroundStyle(p.muted)
                HStack { Button("Cancel") { deleting = nil }; Spacer(); Button("Remove") { model.deleteSong(value.id); deleting = nil } }.frame(minHeight: 44).accessibilityIdentifier("remove-song-confirmation")
            }
        }
    }
}

struct SetlistTransport: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    var prefix = "setlist"
    var body: some View {
        HStack(spacing: 12) {
            step("backward.end.fill", action: .previous, enabled: model.selectedSongID != model.activeSetlist?.songs.first?.id)
            Button {
                if model.currentSong == nil, let first = model.activeSetlist?.songs.first { model.loadSong(first) }
                model.toggle()
            } label: { TransportGlyph(playing: model.transportActive).frame(maxWidth: .infinity).frame(height: 56).contentShape(Rectangle()) }
                .buttonStyle(HardwareButtonStyle(p: p, charcoal: true)).accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton).accessibilityIdentifier("\(prefix)-play")
                .accessibilityLabel(L10n.text(model.transportActive ? "Stop metronome" : "Start metronome"))
            step("forward.end.fill", action: .next, enabled: model.selectedSongID != model.activeSetlist?.songs.last?.id)
        }
    }
    private func step(_ icon: String, action: PedalAction, enabled: Bool) -> some View {
        Button { model.performPedal(action) } label: { Image(systemName: icon).frame(width: 58, height: 56) }
            .buttonStyle(HardwareButtonStyle(p: p)).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(action.title)
            .accessibilityIdentifier("\(prefix)-\(action == .next ? "next" : "previous")")
    }
}
struct SongEditor: View {
    @ObservedObject var model: MetronomeModel
    let initial: SavedPreset
    let p: InstrumentPalette
    let cancel: () -> Void
    let save: (SavedPreset) -> Void
    @State private var name = ""
    @State private var tempo = ""
    @State private var draft = Rhythm()
    @State private var picker: String?
    @FocusState private var typing: Bool
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (20...300).contains(Int(tempo) ?? 0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let picker {
                Button { model.endSoundPreview(); self.picker = nil } label: { Label("Edit song", systemImage: "chevron.left").frame(minHeight: 44) }
                if picker == "division" {
                    DivisionPanel(rhythm: $draft, playing: false, p: p, preview: model.previewRhythm, stopPreview: model.endSoundPreview) { self.picker = nil }
                } else if picker == "sound" {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(InstrumentSound.allCases, id: \.rawValue) { sound in
                            Button {
                                draft.sound = sound.rawValue; model.previewRhythm(draft)
                            } label: {
                                VStack(spacing: 10) { SoundIllustration(index: sound.illustration, p: p).frame(height: 55); Text(sound.title).font(.system(size: 12)) }.padding(17).frame(maxWidth: .infinity)
                                    .overlay(alignment: .topLeading) { LED(on: draft.sound == sound.rawValue, size: 7).padding(10) }
                            }.buttonStyle(HardwareButtonStyle(p: p))
                        }
                    }
                } else { meterEditor }
            } else {
                TextField("Song name", text: $name).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("song-name").focused($typing)
                HStack { Text("BPM"); Spacer(); TextField("BPM", text: $tempo).keyboardType(.numberPad).multilineTextAlignment(.trailing).font(InstrumentType.value(32)).frame(width: 100).focused($typing) }.padding(16).insetPanel(p, radius: 10).accessibilityIdentifier("song-bpm")
                if !(20...300).contains(Int(tempo) ?? 0) { Text("20–300 BPM").font(.caption).foregroundStyle(p.muted) }
                field("METER", value: "\(draft.beats)/\(draft.denominator)", route: "meter")
                Button { typing = false; picker = "division" } label: { HStack { Text("DIVISION").font(.subheadline); Spacer(); RhythmScore(rhythm: draft, color: p.ink).frame(width: 90, height: 40); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(height: 58) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("song-division")
                field("SOUND", value: InstrumentSound(rawValue: draft.sound)?.title ?? "", route: "sound")
                HStack(spacing: 12) {
                    Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("cancel-song")
                    Button { draft.bpm = Int(tempo)!; save(SavedPreset(id: initial.id, name: name, rhythm: draft.performanceCopy)) } label: { Text("Save").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                        .disabled(!valid).opacity(valid ? 1 : 0.45).accessibilityIdentifier("save-song")
                }
            }
        }.onAppear { name = initial.name; draft = initial.rhythm.performanceCopy; tempo = String(draft.bpm) }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                guard let field = note.object as? UITextField, field.keyboardType == .numberPad else { return }
                DispatchQueue.main.async { field.selectAll(nil) }
            }
            .onChange(of: tempo) { _, value in if let n = Int(value), (20...300).contains(n) { draft.bpm = n } }
            .onDisappear { model.endSoundPreview() }
    }
    private func field(_ title: String, value: String, route: String) -> some View {
        Button { typing = false; picker = route } label: { HStack { Text(L10n.text(title)).font(.subheadline); Spacer(); Text(value).font(.system(size: 17, weight: .medium)); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(height: 58) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("song-\(route)")
    }
    private var meterEditor: some View {
        VStack(spacing: 18) {
            Text("\(draft.beats)/\(draft.denominator)").font(InstrumentType.value(52)).frame(maxWidth: .infinity).padding(18).insetPanel(p, radius: 12)
            HStack { ForEach([2,4,8,16], id: \.self) { d in
                Button { draft.setMeter(beats: draft.beats, denominator: d, compound: true) } label: { Text("/\(d)").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: draft.denominator == d))
            } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) { ForEach(1...12, id: \.self) { n in
                Button { draft.setMeter(beats: n, denominator: draft.denominator, compound: true); picker = nil } label: { Text("\(n)/\(draft.denominator)").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: draft.beats == n))
            } }
        }
    }
}
