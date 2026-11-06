import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SetlistPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    let close: () -> Void
    let startInSongLibrary: Bool
    @State private var library: Bool
    @State private var browsingSetlistID: UUID?
    @State private var creatingList = false
    @State private var draggingSong: UUID?
    @State private var dragSession = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var browsedList: SongSetlist? { model.setlists.first { $0.id == browsingSetlistID } }
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
    @State private var managingSongs = false
    @State private var search = ""
    @State private var deletingForever: SavedPreset?
    @State private var libraryActions: UUID?
    @State private var songPicker: String?
    @State private var songDivisionEditing = false
    @FocusState private var namingList: Bool
    init(model: MetronomeModel, p: InstrumentPalette, initialSetlistID: UUID? = nil, startInSongLibrary: Bool = false, close: @escaping () -> Void) {
        self.model = model; self.p = p; self.close = close; self.startInSongLibrary = startInSongLibrary
        let initial = model.setlists.first { $0.id == initialSetlistID }?.id
        _browsingSetlistID = State(initialValue: initial)
        _library = State(initialValue: initial == nil)
        _managingSongs = State(initialValue: startInSongLibrary)
        _source = State(initialValue: startInSongLibrary ? "songs" : nil)
    }
    private var detail: Bool { !library && !creatingList && !adding && song == nil && source == nil && sharing == nil }
    private var pageID: String {
        if creatingList { return "create-list" }
        if let song { return "edit-" + song.id.uuidString }
        if let sharing { return "share-" + sharing.id.uuidString }
        if let source { return "source-" + source }
        if adding { return "add" }
        return library ? "lists" : "list-" + (browsingSetlistID?.uuidString ?? "")
    }
    private var title: String {
        if creatingList { return L10n.text("New setlist") }
        if song != nil, let songPicker { return SongEditor.title(for: songDivisionEditing ? "custom" : songPicker) }
        if let song { return L10n.text(model.songLibrary.contains { $0.id == song.id } ? "Edit song" : "New song") }
        if sharing != nil { return L10n.text("Add to setlist") }
        if source == "songs" { return L10n.text("Song library") }
        if source == "presets" { return L10n.text("PRESETS") }
        if adding { return L10n.text("Add song") }
        return library ? L10n.text("Setlists") : browsedList?.name ?? L10n.text("Setlists")
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
                                if creatingList { newList }
                                else if let song {
                                    if model.listsContainingSong(song.id) > 1 {
                                        Text("Changes apply in every setlist.").font(.subheadline).foregroundStyle(p.muted)
                                    }
                                    SongEditor(model: model, initial: song, p: p, picker: $songPicker, divisionEditing: $songDivisionEditing, cancel: { self.song = nil }) { value in
                                        if model.songLibrary.contains(where: { $0.id == value.id }) { model.editSong(value.id, name: value.name, rhythm: value.rhythm, notes: value.notes) }
                                        else if managingSongs { model.createLibrarySong(value.name, rhythm: value.rhythm, notes: value.notes) }
                                        else { model.addSong(value.name, bpm: value.rhythm.bpm, source: value.rhythm, into: browsingSetlistID, notes: value.notes) }
                                        self.song = nil; adding = false; search = ""
                                    }.id(song.id)
                                } else if let sharing { targets(sharing) }
                                else if let source { sourceLibrary(source) }
                                else if adding { addOptions }
                                else if library { listLibrary }
                                else if let list = browsedList { listDetail(list) }
                            }.padding(20)
                        }.scrollBounceBehavior(.basedOnSize).scrollDismissesKeyboard(.immediately).id(pageID)
                            .onChange(of: model.selectedSongID) { _, id in
                                if detail, !editing, let id { withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) } }
                            }
                    }
                }
                    .frame(maxWidth: 560).frame(height: geo.size.height - 12).accessibilityHidden(performing)
                    .background { InstrumentBody(p: p) }.clipShape(RoundedRectangle(cornerRadius: 23))
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(p.light, lineWidth: 0.8))
                    .padding(.horizontal, 10).padding(.bottom, 7).accessibilityElement(children: .contain)
            }.foregroundStyle(p.ink)
        }.onChange(of: song?.id) { _, _ in songPicker = nil; songDivisionEditing = false }
        .fullScreenCover(isPresented: $performing) { PerformanceView(model: model) }
    }
    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                if !library || creatingList || (source != nil && !startInSongLibrary) || song != nil || sharing != nil {
                    Button {
                        if song != nil && songPicker != nil { model.endSoundPreview(); if songDivisionEditing { songDivisionEditing = false } else { songPicker = nil }; return }
                        if creatingList { creatingList = false; listName = "" }
                        else if song != nil { song = nil }
                        else if sharing != nil { sharing = nil }
                        else if source != nil { source = nil; search = ""; managingSongs = false; deletingForever = nil }
                        else if adding { adding = false }
                        else { library = true; browsingSetlistID = nil; editing = false; adding = false; listName = "" }
                        model.endSoundPreview(); notice = nil
                    } label: { HStack(spacing: 5) { Image(systemName: "chevron.left"); if detail { Text("Setlists").font(.system(size: 13)) } }.padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Setlists").accessibilityIdentifier(songPicker == nil ? "choose-setlist" : "song-picker-back")
                }
                Text(title).font(.system(size: 22, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if detail || (library && !creatingList && source == nil && song == nil && sharing == nil) {
                    Button {
                        if editing && detail { model.renameSetlist(listName, in: browsingSetlistID); namingList = false }
                        else { listName = browsedList?.name ?? "" }
                        editing.toggle(); draggingSong = nil; adding = false; deleting = nil; deletingList = false
                    } label: { Text(L10n.text(editing ? "Done" : "Edit")).font(.system(size: 15, weight: .medium)).padding(.horizontal, 12).frame(minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("edit-setlist")
                }
                KeyboardDismissButton(p: p)
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel(L10n.text(startInSongLibrary ? "Close song library" : "Close setlists")).accessibilityIdentifier("close-panel")
            }
            Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5)
        }.padding(.horizontal, 20).padding(.top, 18)
    }
    private var listLibrary: some View {
        VStack(spacing: 16) {
            if model.setlists.isEmpty {
                Text("Your next show, song by song.").font(.subheadline).foregroundStyle(p.muted).padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(model.setlists) { list in
                        Button { browsingSetlistID = list.id; library = false; listName = list.name } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) { Text(list.name).font(.headline); Text(L10n.format(list.songs.count == 1 ? "%d song" : "%d songs", list.songs.count)).font(.subheadline).foregroundStyle(p.muted) }
                                Spacer(); Image(systemName: editing ? "pencil" : "chevron.right").font(.caption)
                            }.padding(16).frame(minHeight: 68).contentShape(Rectangle())
                        }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("setlist-\(list.name)")
                    }
                }.padding(12).insetPanel(p, radius: 18)
            }
            Button { listName = ""; creatingList = true } label: {
                Label("New setlist", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("new-setlist")
            Button { managingSongs = true; source = "songs"; search = "" } label: {
                Label("Saved songs", systemImage: "music.note.list").frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("manage-song-library")
        }
    }
    private var newList: some View {
        VStack(spacing: 18) {
            TextField("Setlist name", text: $listName).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
            Button {
                if let id = model.addSetlist(listName, activate: false) {
                    browsingSetlistID = id; library = false; creatingList = false; listName = ""
                }
            } label: { Text("Create setlist").frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("create-setlist")
        }
    }
    private func listDetail(_ list: SongSetlist) -> some View {
        VStack(spacing: 18) {
            if editing {
                HStack {
                    TextField("Setlist name", text: $listName).focused($namingList).padding(14).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
                    Button { model.renameSetlist(listName, in: browsingSetlistID); namingList = false } label: { Text("Rename").padding(.horizontal, 12).frame(minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p)).disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Drag the handle to reorder.").font(.system(size: 13)).foregroundStyle(p.muted).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L10n.format(list.songs.count == 1 ? "%d song" : "%d songs", list.songs.count)).font(.subheadline).foregroundStyle(p.muted).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !editing && !list.songs.isEmpty {
                Button { model.startSetlist(list.id); performing = true } label: {
                    Label("Start from first song", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 50)
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true)).accessibilityIdentifier("start-setlist")
            }
            VStack(spacing: 0) {
                if list.songs.isEmpty { Text("Add your first song.").font(.subheadline).foregroundStyle(p.muted).padding(20) }
                ForEach(list.songs) { value in
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            songRow(value)
                            if editing {
                                Image(systemName: "line.3.horizontal").font(.system(size: 18)).foregroundStyle(p.muted)
                                    .frame(width: 38, height: 70).contentShape(Rectangle())
                                    .accessibilityIdentifier("drag-song-\(value.name)")

                            }
                        }
                        if editing { editControls(value).padding(.horizontal, 12).padding(.bottom, 12) }
                        if value.id != list.songs.last?.id { Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5).padding(.horizontal, 12) }
                    }.id(value.id)
                        .modifier(WholeSongDrag(enabled: editing, id: value.id, dragging: $draggingSong, session: $dragSession))
                        .onDrop(of: [UTType.text], delegate: SongReorderDrop(target: value.id, dragging: $draggingSong) { id, target in
                            guard editing, let list = browsedList, let destination = list.songs.firstIndex(where: { $0.id == target }) else { return }
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { model.moveSong(id, to: destination, in: list.id) }
                        })
                }
            }.padding(12).insetPanel(p, radius: 18)
            Button { adding = true; notice = nil; managingSongs = false; search = "" } label: {
                Label("Add song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-song")
            if let notice { Text(notice).font(.subheadline).foregroundStyle(p.muted) }
            if editing {
                Button {
                    if let id = model.duplicateSetlist(list.id) { browsingSetlistID = id; listName = browsedList?.name ?? ""; editing = false }
                } label: { Label("Duplicate setlist", systemImage: "plus.square.on.square").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("duplicate-setlist")
                Button { deletingList = true } label: { Text("Delete setlist").padding(.horizontal, 16).frame(minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p)).foregroundStyle(p.muted)
                if deletingList {
                    Text("Delete this setlist? Songs stay in your library.").font(.subheadline)
                    HStack(spacing: 12) {
                        Button { deletingList = false } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }
                        Button { if let id = browsingSetlistID { model.deleteSetlist(id) }; browsingSetlistID = nil; deletingList = false; library = true; editing = false; listName = "" } label: { Text("DELETE").frame(maxWidth: .infinity, minHeight: 44) }
                    }.buttonStyle(HardwareButtonStyle(p: p))
                }
            }
        }
    }
    private var addOptions: some View {
        VStack(spacing: 16) {
            if let list = browsedList { Text(L10n.format("Add to %@", list.name)).font(.subheadline).foregroundStyle(p.muted).frame(maxWidth: .infinity, alignment: .leading) }
            addOption("New song", icon: "plus", id: "new-song") { song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy) }
            addOption("Choose saved songs", icon: "music.note.list", id: "import-songs") { source = "songs"; search = "" }
            addOption("Import from presets", icon: "square.and.arrow.down", id: "import-presets") { source = "presets"; search = "" }
        }
    }
    private func addOption(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 14) { Image(systemName: icon).frame(width: 24); Text(L10n.text(title)); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(18).frame(minHeight: 64) }
            .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier(id)
    }
    @ViewBuilder private func sourceLibrary(_ source: String) -> some View {
        if managingSongs { managedLibrary } else { sourcePicker(source) }
    }
    private func sourcePicker(_ source: String) -> some View {
        let entries = (source == "songs" ? model.songLibrary : model.presets).filter { search.isEmpty || $0.name.localizedStandardContains(search) }
        return VStack(spacing: 14) {
            TextField("Search", text: $search).submitLabel(.done).onSubmit { dismissTextInput() }.padding(14).insetPanel(p, radius: 10).accessibilityIdentifier("song-search")
            if source == "presets" { Text("Adds a copy. Your preset stays unchanged.").font(.subheadline).foregroundStyle(p.muted) }
            if entries.isEmpty { Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).font(.subheadline).foregroundStyle(p.muted).padding(.vertical, 20) }
            ForEach(entries) { value in
                let exists = source == "songs" && browsedList?.songs.contains(where: { $0.id == value.id }) == true
                Button {
                    if source == "songs" { model.addExistingSong(value.id, to: browsingSetlistID) }
                    else { model.importPreset(value, into: browsingSetlistID) }
                    self.source = nil; adding = false; search = ""
                    notice = source == "presets" && value.rhythm.hasPracticeEffects ? L10n.text("Song added. Practice effects stay in the preset.") : nil
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) { Text(value.name); Text("\(value.rhythm.beats)/\(value.rhythm.denominator)").font(.caption).foregroundStyle(p.muted) }
                        Spacer(); Text("\(value.rhythm.bpm) BPM").foregroundStyle(p.muted)
                        Image(systemName: exists ? "checkmark" : "plus")
                    }.padding(16).frame(minHeight: 68)
                }.buttonStyle(HardwareButtonStyle(p: p)).disabled(exists).accessibilityIdentifier("import-\(source == "songs" ? "song" : "preset")-\(value.name)")
            }
        }
    }
    private func memberships(_ value: SavedPreset) -> [SongSetlist] {
        model.setlists.filter { $0.songs.contains { $0.id == value.id } }
    }
    private var managedLibrary: some View {
        let entries = model.songLibrary.filter { search.isEmpty || $0.name.localizedStandardContains(search) || memberships($0).contains { $0.name.localizedStandardContains(search) } }
        return VStack(alignment: .leading, spacing: 20) {
            TextField("Search", text: $search).submitLabel(.done).onSubmit { dismissTextInput() }.padding(14).insetPanel(p, radius: 10).accessibilityIdentifier("song-search")
                .onChange(of: search) { _, _ in libraryActions = nil; deletingForever = nil }
            Button { dismissTextInput(); libraryActions = nil; song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy) } label: {
                Label("New song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("library-new-song")
            if entries.isEmpty {
                Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted).padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { value in
                        VStack(spacing: 0) {
                            libraryRow(value)
                            if value.id != entries.last?.id { Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5).padding(.horizontal, 16) }
                        }.id(value.id)
                            .modifier(WholeSongDrag(enabled: search.isEmpty, id: value.id, dragging: $draggingSong, session: $dragSession))
                            .onDrop(of: [UTType.text], delegate: SongReorderDrop(target: value.id, dragging: $draggingSong) { id, target in
                                guard search.isEmpty, let index = model.songLibrary.firstIndex(where: { $0.id == target }) else { return }
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { model.moveLibrarySong(id, to: index) }
                            })
                    }
                }.padding(.vertical, 4).insetPanel(p, radius: 16)
            }
        }
    }
    private func libraryRow(_ value: SavedPreset) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(value.name).font(.system(size: 18, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Text("\(value.rhythm.bpm) BPM")
                        Text("\(value.rhythm.beats)/\(value.rhythm.denominator)")
                        RhythmScore(rhythm: value.rhythm, color: p.muted).frame(width: 58, height: 23)
                    }.font(.system(size: 12)).foregroundStyle(p.muted)
                    if memberships(value).isEmpty {
                        Text("Not in a setlist").font(.system(size: 11)).foregroundStyle(p.muted)
                    } else {
                        SongLabelFlow(spacing: 5) {
                            ForEach(memberships(value)) { list in
                                Text(list.name).font(.system(size: 11)).lineLimit(2)
                                    .padding(.horizontal, 7).padding(.vertical, 4)
                                    .background(p.body.opacity(0.8), in: RoundedRectangle(cornerRadius: 5))
                                    .accessibilityIdentifier("membership-\(value.name)-\(list.name)")
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { libraryActions = libraryActions == value.id ? nil : value.id; deletingForever = nil; dismissTextInput() } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: libraryActions == value.id, radius: 9))
                    .accessibilityLabel(L10n.format("Options for %@", value.name)).accessibilityIdentifier("library-options-\(value.name)")
                if search.isEmpty {
                    Image(systemName: "line.3.horizontal").foregroundStyle(p.muted).frame(width: 28, height: 44)
                        .accessibilityLabel("Drag to reorder.").accessibilityIdentifier("library-drag-\(value.name)")
                }

            }
            if libraryActions == value.id {
                if deletingForever?.id == value.id {
                    Text("Delete this song from your library and all setlists?").font(.subheadline)
                    HStack(spacing: 10) {
                        Button { deletingForever = nil } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }
                        Button { model.deleteLibrarySong(value.id); deletingForever = nil; libraryActions = nil } label: { Text("Delete").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("confirm-delete-library-song")
                    }.buttonStyle(HardwareButtonStyle(p: p))
                } else {
                    HStack(spacing: 8) {
                        Button { song = value; libraryActions = nil } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }.accessibilityLabel("Edit song").accessibilityIdentifier("library-edit-\(value.name)")
                        Button { sharing = value; libraryActions = nil } label: { Image(systemName: "text.badge.plus").frame(width: 44, height: 44) }
                            .disabled(model.setlists.isEmpty).accessibilityLabel("Add to setlist").accessibilityIdentifier("library-share-\(value.name)")
                        Button { deletingForever = value } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                            .accessibilityLabel("Delete song").accessibilityIdentifier("library-delete-\(value.name)")
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 8))
                }
            }
        }.padding(16).accessibilityElement(children: .contain).accessibilityIdentifier("library-row-\(value.name)")
            .accessibilityActions {
                if search.isEmpty, let index = model.songLibrary.firstIndex(where: { $0.id == value.id }) {
                    Button("Move up") { model.moveLibrarySong(value.id, to: index - 1) }
                    Button("Move down") { model.moveLibrarySong(value.id, to: index + 1) }
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
        Button { if editing { song = value } else { model.loadSong(value, from: browsingSetlistID); performing = true } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(value.name).font(.system(size: 17, weight: .medium)).multilineTextAlignment(.leading)
                    HStack(spacing: 12) {
                        Text("\(value.rhythm.bpm) BPM  ·  \(value.rhythm.beats)/\(value.rhythm.denominator)").font(.system(size: 12)).foregroundStyle(p.muted)
                        RhythmScore(rhythm: value.rhythm, color: p.muted).frame(width: 57, height: 24)
                    }
                }
                Spacer(minLength: 0)
                if !editing { Image(systemName: "chevron.right").font(.caption).foregroundStyle(p.muted) }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 78).contentShape(Rectangle())
        }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("song-\(value.name)")
            .accessibilityActions {
                if editing {
                    Button("Move up") { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { model.moveSong(value.id, by: -1, in: browsingSetlistID) } }
                    Button("Move down") { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { model.moveSong(value.id, by: 1, in: browsingSetlistID) } }
                }
            }.accessibilityAddTraits(model.activeSetlistID == browsingSetlistID && model.selectedSongID == value.id ? .isSelected : [])
    }
    private func editControls(_ value: SavedPreset) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button { song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }.accessibilityLabel("Edit song").accessibilityIdentifier("edit-song-\(value.name)")
                Button { sharing = value } label: { Image(systemName: "text.badge.plus").frame(width: 44, height: 44) }.accessibilityLabel("Add to setlist").accessibilityIdentifier("share-song-\(value.name)")
                Button { deleting = value.id } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }.accessibilityLabel("Remove from setlist").accessibilityIdentifier("delete-song-\(value.name)")
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 8)).foregroundStyle(p.muted)
            if deleting == value.id {
                Text("The song stays in your library.").font(.subheadline).foregroundStyle(p.muted)
                HStack(spacing: 12) {
                    Button { deleting = nil } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }
                    Button { model.deleteSong(value.id, from: browsingSetlistID); deleting = nil } label: { Text("Remove").frame(maxWidth: .infinity, minHeight: 44) }
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("remove-song-confirmation")
            }
        }
    }
}

private struct SongLabelFlow: Layout {
    var spacing: CGFloat = 5
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 300).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(subviews, width: bounds.width)
        for (view, point) in zip(subviews, layout.points) {
            view.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }
    private func arrange(_ views: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, points: [CGPoint] = []
        for view in views {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width { x = 0; y += line + spacing; line = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; line = max(line, size.height)
        }
        return (CGSize(width: width, height: y + line), points)
    }
}

private struct SongReorderDrop: DropDelegate {
    let target: UUID
    @Binding var dragging: UUID?
    let move: (UUID, UUID) -> Void
    func validateDrop(info: DropInfo) -> Bool { dragging != nil }
    func dropEntered(info: DropInfo) { if let dragging, dragging != target { move(dragging, target) } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragging = nil; return true }
}

struct SongEditor: View {
    let model: MetronomeModel
    let initial: SavedPreset
    let p: InstrumentPalette
    let cancel: () -> Void
    let save: (SavedPreset) -> Void
    @State private var name = ""
    @State private var notes = ""
    @State private var tempo = ""
    @State private var draft = Rhythm()
    @Binding var picker: String?
    @Binding var divisionEditing: Bool
    private enum Input: Hashable { case name, tempo, notes }
    @FocusState private var typing: Input?
    static func title(for route: String) -> String {
        L10n.text(["tempo": "BPM", "meter": "METER", "division": "DIVISION", "sound": "SOUND LIBRARY", "custom": "Customize rhythm"][route] ?? "Edit song")
    }
    init(model: MetronomeModel, initial: SavedPreset, p: InstrumentPalette, picker: Binding<String?>, divisionEditing: Binding<Bool>, cancel: @escaping () -> Void, save: @escaping (SavedPreset) -> Void) {
        self.model = model; self.initial = initial; self.p = p
        self._picker = picker; self._divisionEditing = divisionEditing
        self.cancel = cancel; self.save = save
    }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (20...300).contains(Int(tempo) ?? 0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let picker {
                if picker == "division" {
                    DivisionPanel(rhythm: $draft, editing: $divisionEditing, playing: false, p: p, stopPreview: model.endSoundPreview)
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
                } else if picker == "tempo" {
                    HStack { Text("BPM"); Spacer(); TextField("BPM", text: $tempo).keyboardType(.numberPad).multilineTextAlignment(.trailing).font(InstrumentType.value(32)).frame(width: 110).focused($typing, equals: .tempo) }.padding(16).insetPanel(p, radius: 10).accessibilityIdentifier("song-bpm-input")
                    Text("20–300 BPM").font(.caption).foregroundStyle(p.muted)
                } else { meterEditor }
            } else {
                TextField("Song name", text: $name).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("song-name").focused($typing, equals: .name).submitLabel(.done).onSubmit { typing = nil }
                field("BPM", value: tempo, route: "tempo")
                field("METER", value: "\(draft.beats)/\(draft.denominator)", route: "meter")
                Button { typing = nil; picker = "division" } label: { HStack { Text("DIVISION").font(.subheadline); Spacer(); RhythmScore(rhythm: draft, color: p.ink).frame(width: 90, height: 40); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(height: 58) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("song-division")
                field("SOUND", value: InstrumentSound(rawValue: draft.sound)?.title ?? "", route: "sound")
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("song-notes").focused($typing, equals: .notes)
                HStack(spacing: 12) {
                    Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("cancel-song")
                    Button { draft.bpm = Int(tempo)!; save(SavedPreset(id: initial.id, name: name, rhythm: draft.performanceCopy, notes: notes)) } label: { Text("Save").frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                        .disabled(!valid).opacity(valid ? 1 : 0.45).accessibilityIdentifier("save-song")
                }
            }
        }.onChange(of: picker) { _, _ in typing = nil; dismissTextInput() }
        .onAppear { name = initial.name; notes = initial.notes ?? ""; draft = initial.rhythm.performanceCopy; tempo = String(draft.bpm) }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                guard let field = note.object as? UITextField, field.keyboardType == .numberPad else { return }
                DispatchQueue.main.async { field.selectAll(nil) }
            }
            .onChange(of: tempo) { _, value in if let n = Int(value), (20...300).contains(n) { draft.bpm = n } }
            .onDisappear { model.endSoundPreview() }
    }
    private func field(_ title: String, value: String, route: String) -> some View {
        Button { typing = nil; picker = route } label: { HStack { Text(L10n.text(title)).font(.subheadline); Spacer(); Text(value).font(.system(size: 17, weight: .medium)); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(height: 58) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("song-\(route)")
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

private struct WholeSongDrag: ViewModifier {
    let enabled: Bool
    let id: UUID
    @Binding var dragging: UUID?
    @Binding var session: UUID
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            FullSizeSongDrag(content: content, id: id, dragging: $dragging, session: $session)
        } else { content }
    }
}

/// UIKit's full-size preview keeps a song attached to the finger at its original
/// dimensions, rather than turning it into a small data-transfer thumbnail.
private struct FullSizeSongDrag<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let id: UUID
    @Binding var dragging: UUID?
    @Binding var session: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        let interaction = UIDragInteraction(delegate: context.coordinator)
        interaction.isEnabled = true
        host.view.addInteraction(interaction)
        return host
    }
    func updateUIViewController(_ host: UIHostingController<Content>, context: Context) {
        context.coordinator.parent = self
        host.rootView = content
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<Content>, context: Context) -> CGSize? {
        uiViewController.sizeThatFits(in: CGSize(width: proposal.width ?? 320, height: .greatestFiniteMagnitude))
    }
    final class Coordinator: NSObject, UIDragInteractionDelegate {
        var parent: FullSizeSongDrag
        private var token: UUID?
        init(_ parent: FullSizeSongDrag) { self.parent = parent }
        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            dismissTextInput()
            let token = UUID(); self.token = token
            parent.session = token
            parent.dragging = parent.id
            return [UIDragItem(itemProvider: NSItemProvider(object: parent.id.uuidString as NSString))]
        }
        func dragInteraction(_ interaction: UIDragInteraction, prefersFullSizePreviewsFor session: UIDragSession) -> Bool { true }
        func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
            guard let view = interaction.view else { return nil }
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(roundedRect: view.bounds, cornerRadius: 12)
            return UITargetedDragPreview(view: view, parameters: parameters)
        }
        func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) {
            if parent.session == token { parent.dragging = nil }
        }
    }
}
