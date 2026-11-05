import SwiftUI

struct SetlistPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    let close: () -> Void
    @State private var library = true
    @State private var editing = false
    @State private var adding = false
    @State private var importing = false
    @State private var listName = ""
    @State private var song: SavedPreset?
    @State private var deleting: UUID?
    @State private var deletingList = false
    @State private var notice: String?
    init(model: MetronomeModel, p: InstrumentPalette, close: @escaping () -> Void) {
        self.model = model; self.p = p; self.close = close
        _library = State(initialValue: model.activeSetlist == nil)
        _listName = State(initialValue: model.activeSetlist?.name ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let song {
                SongEditor(model: model, initial: song, p: p, cancel: { self.song = nil }) { value in
                    if model.activeSetlist?.songs.contains(where: { $0.id == value.id }) == true {
                        model.editSong(value.id, name: value.name, rhythm: value.rhythm)
                    } else { model.addSong(value.name, bpm: value.rhythm.bpm, source: value.rhythm) }
                    self.song = nil; adding = false; editing = false
                }.id(song.id)
            } else if library { listLibrary }
            else if importing {
                Button { importing = false } label: { Label("Back to setlist", systemImage: "chevron.left").frame(minHeight: 44) }.accessibilityIdentifier("cancel-import")
                Text("Adds a copy. Your preset stays unchanged.").font(.subheadline).foregroundStyle(p.muted)
                ForEach(model.presets) { preset in
                    Button {
                        model.importPreset(preset); importing = false; adding = false
                        notice = preset.rhythm.hasPracticeEffects ? L10n.text("Song added. Practice effects stay in the preset.") : nil
                    } label: {
                        HStack { Text(preset.name); Spacer(); Text("\(preset.rhythm.bpm) BPM").foregroundStyle(p.muted); Image(systemName: "plus") }.padding(16).frame(minHeight: 60)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("import-preset-\(preset.name)")
                }
            } else if let list = model.activeSetlist { listDetail(list) }
        }.foregroundStyle(p.ink)
    }
    private var listLibrary: some View {
        VStack(spacing: 14) {
            ForEach(model.setlists) { list in
                Button { model.activeSetlistID = list.id; library = false; listName = list.name } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) { Text(list.name).font(.system(size: 18, weight: .medium)); Text(L10n.format("%d songs", list.songs.count)).font(.system(size: 13)).foregroundStyle(p.muted) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(20).frame(maxWidth: .infinity, minHeight: 88)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 12)).accessibilityIdentifier("setlist-\(list.name)")
            }
            if model.setlists.isEmpty { Text("Your next show, song by song.").font(.subheadline).foregroundStyle(p.muted).padding(.vertical, 20) }
            HStack(spacing: 12) {
                TextField("Setlist name", text: $listName).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
                Button { model.addSetlist(listName); library = false; listName = model.activeSetlist?.name ?? "" } label: { Image(systemName: "plus").frame(width: 48, height: 48) }
                    .buttonStyle(HardwareButtonStyle(p: p)).disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Create setlist")
            }
        }
    }
    private func listDetail(_ list: SongSetlist) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button { library = true; editing = false; adding = false; notice = nil; listName = "" } label: { Label("Setlists", systemImage: "chevron.left").frame(minHeight: 44) }.accessibilityIdentifier("choose-setlist")
                Spacer()
                Button(editing ? "Done" : "Edit") { editing.toggle(); listName = list.name; adding = false }.frame(minHeight: 44).accessibilityIdentifier("edit-setlist")
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 14) {
                if editing {
                    HStack {
                        TextField("Setlist name", text: $listName).accessibilityIdentifier("setlist-name").padding(10).insetPanel(p, radius: 8)
                        Button("Rename") { model.renameSetlist(listName) }.disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else { Text(list.name).font(.system(size: 24, weight: .semibold)).padding(.horizontal, 7).padding(.top, 6) }
                if list.songs.isEmpty { Text("Your next show, song by song.").font(.subheadline).foregroundStyle(p.muted).padding(16) }
                ForEach(Array(list.songs.enumerated()), id: \.element.id) { index, value in
                    songRow(value)
                    if editing { editControls(value, index: index, count: list.songs.count) }
                    else if index < list.songs.count-1 { Rectangle().fill(p.edge.opacity(0.3)).frame(height: 0.5).padding(.horizontal, 10) }
                }
                Button { adding.toggle(); notice = nil } label: { Label("Add song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-song")
                if adding {
                    Button("New song") { song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy) }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("new-song")
                    Button("Add from presets") { importing = true }.frame(maxWidth: .infinity, minHeight: 44).disabled(model.presets.isEmpty).accessibilityIdentifier("import-presets")
                }
            }.padding(12).insetPanel(p, radius: 18)
            if let notice { Text(notice).font(.subheadline).foregroundStyle(p.muted) }
            if editing {
                Button("Delete setlist") { deletingList = true }.frame(minHeight: 44).foregroundStyle(p.muted)
                if deletingList {
                    Text("Delete this setlist and its songs?").font(.subheadline)
                    HStack { Button("Cancel") { deletingList = false }; Spacer(); Button("DELETE") { model.deleteActiveSetlist(); deletingList = false; library = true; editing = false; listName = "" } }.frame(minHeight: 44)
                }
            } else if !list.songs.isEmpty {
                HStack(spacing: 12) {
                    transport("backward.end.fill", action: .previous, enabled: model.selectedSongID != list.songs.first?.id)
                    Button {
                        if model.currentSong == nil, let first = list.songs.first { model.loadSong(first) }
                        model.toggle()
                    } label: { Image(systemName: model.playing ? "stop.fill" : "play.fill").frame(maxWidth: .infinity, minHeight: 56) }
                        .buttonStyle(HardwareButtonStyle(p: p, charcoal: true)).accessibilityIdentifier("setlist-play")
                    transport("forward.end.fill", action: .next, enabled: model.selectedSongID != list.songs.last?.id)
                }
            }
        }
    }
    private func songRow(_ value: SavedPreset) -> some View {
        Button { if editing { song = value } else { model.loadSong(value) } } label: {
            HStack(spacing: 12) {
                LED(on: model.selectedSongID == value.id, color: InstrumentPalette.amber, size: 7)
                VStack(alignment: .leading, spacing: 4) {
                    Text(value.name).font(.system(size: 16, weight: .medium)).multilineTextAlignment(.leading)
                    HStack(spacing: 12) {
                        Text("\(value.rhythm.beats)/\(value.rhythm.denominator)").font(.system(size: 12)).foregroundStyle(p.muted)
                        RhythmScore(rhythm: value.rhythm, color: p.muted).frame(width: 57, height: 24)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 2) { Text("\(value.rhythm.bpm)").font(InstrumentType.value(30)); Text("BPM").technical(8, spacing: 1).foregroundStyle(p.muted) }
            }.padding(12).frame(maxWidth: .infinity, minHeight: 82).contentShape(Rectangle())
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
                Button { deleting = value.id } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityIdentifier("delete-song-\(value.name)")
            }.foregroundStyle(p.muted)
            if deleting == value.id { HStack { Button("Cancel") { deleting = nil }; Spacer(); Button("DELETE") { model.deleteSong(value.id); deleting = nil } }.frame(minHeight: 44) }
        }
    }
    private func transport(_ icon: String, action: PedalAction, enabled: Bool) -> some View {
        Button { model.performPedal(action) } label: { Image(systemName: icon).frame(width: 62, height: 56) }
            .buttonStyle(HardwareButtonStyle(p: p)).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(action.title)
    }
}

private struct SongEditor: View {
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
                    Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(HardwareButtonStyle(p: p))
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
