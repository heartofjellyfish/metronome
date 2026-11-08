import SwiftUI
import UIKit

struct SetlistPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    let close: () -> Void
    let startInSongLibrary: Bool
    @State private var browsingSetlistID: UUID?
    @State private var editing = false
    @State private var creatingList = false
    @State private var listName = ""
    @State private var draftSongIDs: [UUID] = []
    @State private var compactTitle = false
    @State private var bookmarks = ListBookmarks()
    @State private var shelfHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var listQuery = ""
    @FocusState private var searchingLists: Bool
    @State private var useCounts: [String: Int] = [:]
    private var atRoot: Bool { !startInSongLibrary && browsingSetlistID == nil && !editing && song == nil }
    private var needsSearch: Bool {
        !model.setlists.isEmpty && viewportHeight > 0 && (shelfHeight + 106 > viewportHeight || !listQuery.isEmpty || searchingLists)
    }
    @State private var adding = false
    @State private var search = ""
    @State private var song: SavedPreset?
    @State private var songPicker: String?
    @State private var songDivisionEditing = false
    @State private var sharing: SavedPreset?
    @State private var membershipChanges: [UUID: Bool] = [:]
    @State private var deletingSong = false
    @State private var deletingList = false
    @State private var performing = false
    @FocusState private var namingList: Bool

    init(model: MetronomeModel, p: InstrumentPalette, initialSetlistID: UUID? = nil, startInSongLibrary: Bool = false, close: @escaping () -> Void) {
        self.model = model; self.p = p; self.close = close; self.startInSongLibrary = startInSongLibrary
        _browsingSetlistID = State(initialValue: model.setlists.first { $0.id == initialSetlistID }?.id)
    }
    private var browsedList: SongSetlist? { model.setlists.first { $0.id == browsingSetlistID } }
    private var editingListRoot: Bool { editing && song == nil && !adding }
    private var choosingSong: Bool { adding && song == nil }
    private var libraryRoot: Bool { startInSongLibrary && song == nil }
    private var browsingDetail: Bool { browsedList != nil && !editing && song == nil && !adding }
    private var title: String {
        if song != nil, let songPicker { return SongEditor.title(for: songDivisionEditing ? "custom" : songPicker) }
        if let song { return L10n.text(model.songLibrary.contains { $0.id == song.id } ? "Edit song" : "New song") }
        if adding { return L10n.text("Add song") }
        if editing { return L10n.text(creatingList ? "New setlist" : "Edit setlist") }
        return L10n.text(startInSongLibrary ? "Song library" : "Setlists")
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(p.dark ? 0.55 : 0.3).ignoresSafeArea().accessibilityHidden(true)
                VStack(spacing: 0) {
                    header
                    if (atRoot && needsSearch) || libraryRoot || choosingSong {
                        catalogSearch(library: libraryRoot || choosingSong).padding(.horizontal, 20)
                    }
                    Group {
                        if let song {
                            ScrollView { songEditor(song).padding(20) }.id(song.id)
                        } else if adding {
                            savedSongPicker
                        } else if editing {
                            listEditor
                        } else if startInSongLibrary {
                            managedLibrary
                        } else if let list = browsedList {
                            listDetail(list)
                        } else {
                            listLibrary
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        if atRoot { viewportHeight = $0 + (needsSearch ? 44 : 0) }
                    }
                    if browsingDetail, let list = browsedList {
                        VStack(spacing: 8) {
                            Divider()
                            HStack {
                                Text(songCount(list.songs.count))
                                    .font(.subheadline).foregroundStyle(p.muted)
                                    .accessibilityIdentifier("setlist-count")
                                Spacer()
                                Button { beginEdit(new: false) } label: {
                                    Label("Edit setlist", systemImage: "pencil")
                                        .padding(.horizontal, 14).frame(minHeight: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("edit-setlist")
                            }
                        }.padding(.horizontal, 20).padding(.bottom, 16)
                    }
                }.frame(maxWidth: 560).frame(height: geo.size.height - 12)
                    .accessibilityHidden(performing || deletingSong || deletingList)
                    .allowsHitTesting(!performing && !deletingSong && !deletingList)
                    .background { InstrumentBody(p: p) }.clipShape(RoundedRectangle(cornerRadius: 23))
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(p.light, lineWidth: 0.8))
                    .padding(.horizontal, 10).padding(.bottom, 7)
            }.foregroundStyle(p.ink)
        }
        .onAppear { useCounts = UserDefaults.standard.dictionary(forKey: "performedSetlists") as? [String: Int] ?? [:] }
        .onChange(of: song?.id) { _, _ in songPicker = nil; songDivisionEditing = false; membershipChanges = [:] }
        .overlay { if performing { PerformanceView(model: model, fromSongLibrary: startInSongLibrary, back: { performing = false }) } }
        .sheet(item: $sharing) { value in
            NavigationStack {
                ScrollView { targets(value).padding(20) }.background(p.body)
                    .navigationTitle(L10n.text("Setlists")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sharing = nil }.accessibilityIdentifier("membership-done") } }
            }.presentationDetents([.medium, .large])
        }
        .overlay {
            if deletingSong, let song {
                deleteConfirmation(name: song.name,
                    detail: L10n.format("Remove from library and all linked setlists (%d).", model.listsContainingSong(song.id)),
                    action: "Delete song", identifier: "confirm-delete-library-song",
                    cancel: { deletingSong = false }) {
                        deletingSong = false
                        model.deleteLibrarySong(song.id)
                        draftSongIDs.removeAll { $0 == song.id }
                        self.song = nil
                    }
            } else if deletingList, let list = browsedList {
                deleteConfirmation(name: list.name, detail: L10n.text("Songs stay in your library."),
                    action: "Delete setlist", identifier: "confirm-delete-setlist",
                    cancel: { deletingList = false }) {
                        deletingList = false
                        model.deleteSetlist(list.id)
                        cancelList(); browsingSetlistID = nil
                    }
            }
        }
    }

    private func deleteConfirmation(name: String, detail: String, action: String, identifier: String,
                                    cancel: @escaping () -> Void, confirm: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(name).font(.title2.bold()).foregroundStyle(p.ink)
                Text(detail).font(.body).foregroundStyle(p.ink)
                HStack(spacing: 12) {
                    Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity, minHeight: 46) }
                        .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                    Button(action: confirm) {
                        Text(L10n.text(action)).foregroundStyle(p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier(identifier)
                }.padding(.top, 8)
            }.padding(20).frame(maxWidth: 370).background { InstrumentBody(p: p) }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 7).padding(24)
        }.accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, cancel)
    }
    private var header: some View {
        HStack(spacing: 10) {
            if editingListRoot {
                Button { cancelList() } label: { Text("Cancel").padding(.horizontal, 12).frame(minHeight: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("cancel-setlist")
                Text(title).font(.system(size: 19, weight: .semibold)).frame(maxWidth: .infinity)
                Button { saveList() } label: { Text("Save").padding(.horizontal, 12).frame(minHeight: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-setlist")
            } else {
                if browsingDetail {
                    Button { browsingSetlistID = nil } label: {
                        Label("All setlists", systemImage: "chevron.left").font(.system(size: 15)).padding(.horizontal, 12).frame(minHeight: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("choose-setlist")
                } else {
                    if song != nil || adding {
                        Button { back() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Back")
                            .accessibilityIdentifier(songPicker == nil ? "choose-setlist" : "song-picker-back")
                    }
                    Text(title).font(.system(size: 22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                }
                if browsingDetail && compactTitle, let list = browsedList {
                    Text(list.name).font(.headline).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("compact-setlist-title")
                } else { Spacer(minLength: 0) }
                if libraryRoot || choosingSong {
                    Button { dismissTextInput(); song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy) } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("New song").accessibilityIdentifier(choosingSong ? "new-song" : "library-new-song")
                }
                if atRoot && needsSearch {
                    Button { beginEdit(new: true) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("New setlist").accessibilityIdentifier("new-setlist")
                }
                // Nested drafts return via Back/Cancel, never bypass the setlist's Save/Cancel.
                if !editing && song == nil {
                    Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Close").accessibilityIdentifier("close-panel")
                }
            }
        }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
    }
    private func back() {
        dismissTextInput(); model.endSoundPreview()
        if song != nil, songPicker != nil {
            if songDivisionEditing { songDivisionEditing = false } else { songPicker = nil }
        } else if song != nil { song = nil }
        else if adding { adding = false }
    }
    private func showSongPicker() {
        dismissTextInput()
        bookmarks.clear("add-song")
        search = ""
        adding = true
    }
    private func beginEdit(new: Bool) {
        if !new, let list = browsedList, list.id == model.activeSetlistID, let id = model.selectedSongID {
            bookmarks.prefer(id, on: list.id.uuidString)
        }
        bookmarks.clear("edit-list")
        dismissTextInput(); creatingList = new; editing = true
        listName = new ? "" : browsedList?.name ?? ""
        draftSongIDs = new ? [] : browsedList?.songs.map(\.id) ?? []
    }
    private func cancelList() {
        dismissTextInput(); editing = false; creatingList = false; draftSongIDs = []; listName = ""
    }
    private func saveList() {
        guard let id = model.saveSetlist(id: creatingList ? nil : browsingSetlistID, name: listName, songIDs: draftSongIDs) else { return }
        browsingSetlistID = id; cancelList()
    }
    private func grip(_ id: String) -> some View {
        Image(systemName: "line.3.horizontal").font(.system(size: 17)).foregroundStyle(p.muted)
            .frame(width: 32, height: 48).contentShape(Rectangle()).accessibilityLabel("Drag to reorder.")
            .accessibilityIdentifier(id)
    }
    private func catalogSearch(library: Bool) -> some View {
        let query = library ? $search : $listQuery
        return HStack {
            TextField("Search", text: query).focused($searchingLists).submitLabel(.done)
                .onSubmit { searchingLists = false }
                .accessibilityIdentifier(library ? "song-search" : "setlist-search")
            if !query.wrappedValue.isEmpty {
                Button { query.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(p.muted)
                }.accessibilityLabel("Clear search")
            }
        }.padding(.horizontal, 12).frame(height: 44).insetPanel(p, radius: 9)
    }
    private func openList(_ list: SongSetlist) {
        dismissTextInput()
        bookmarks.prefer(list.id, on: "setlists")
        bookmarks.clear(list.id.uuidString)
        compactTitle = false
        browsingSetlistID = list.id
    }
    private var listLibrary: some View {
        let query = listQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lists = model.setlists.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
        let move: ((UUID, Int) -> Void)? = query.isEmpty ? { id, index in model.moveSetlist(id, to: index) } : nil
        return CatalogList(items: lists, p: p, bookmarks: bookmarks, page: "setlists",
                           move: move,
                           onRowsHeight: { if query.isEmpty { shelfHeight = $0 } }, row: { _, list in
            HStack(spacing: 6) {
                if query.isEmpty { grip("drag-setlist-\(list.name)") }
                Button { openList(list) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(list.name).font(.headline).multilineTextAlignment(.leading)
                            Text(songCount(list.songs.count)).font(.subheadline).foregroundStyle(p.muted)
                        }
                        Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
                    }.frame(maxWidth: .infinity, minHeight: 58).contentShape(Rectangle())
                }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("setlist-\(list.name)")
            }.padding(.horizontal, 12).padding(.vertical, 5)
        }, above: {
            if searchingLists && query.isEmpty && model.setlists.count >= 20 {
                let frequent = lists.filter { useCounts[$0.id.uuidString, default: 0] >= 3 }
                    .sorted { useCounts[$0.id.uuidString, default: 0] > useCounts[$1.id.uuidString, default: 0] }.prefix(3)
                if !frequent.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Frequently used").font(.footnote).foregroundStyle(p.muted)
                        ForEach(frequent) { list in
                            Button { openList(list) } label: {
                                HStack { Text(list.name); Spacer(); Image(systemName: "chevron.right") }.padding(10)
                            }.buttonStyle(HardwareButtonStyle(p: p))
                        }
                    }
                }
            }
            if lists.isEmpty && !query.isEmpty { Text("No matches.").foregroundStyle(p.muted) }
        }, below: {
            if !needsSearch { Button { beginEdit(new: true) } label: { Label("New setlist", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("new-setlist") }
        })
    }
    private func songCount(_ count: Int) -> String { L10n.format(count == 1 ? "%d song" : "%d songs", count) }
    private func listDetail(_ list: SongSetlist) -> some View {
        CatalogList(items: list.songs, p: p, bookmarks: bookmarks, page: list.id.uuidString,
                    onHeaderScrolled: { compactTitle = $0 }, row: { index, value in
            browseSong(index, value)
        }, above: {
            VStack(alignment: .leading, spacing: 16) {
                Text(list.name).font(.system(size: 28, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("setlist-title")
                if list.songs.isEmpty {
                    Button {
                        beginEdit(new: false)
                        showSongPicker()
                    } label: {
                        Label("Add first song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-first-song")
                }
            }
        }, below: { EmptyView() }).id(list.id)
    }
    private var draftSongs: [SavedPreset] {
        let catalog = Dictionary(model.songLibrary.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return draftSongIDs.compactMap { catalog[$0] }
    }
    private var listEditor: some View {
        CatalogList(items: draftSongs, p: p, bookmarks: bookmarks, page: "edit-list", move: { id, index in
            guard let source = draftSongIDs.firstIndex(of: id) else { return }
            draftSongIDs.remove(at: source)
            draftSongIDs.insert(id, at: index)
        }, row: { index, value in
            HStack(spacing: 6) {
                grip("drag-song-\(value.name)")
                Text(String(format: "%02d", index + 1)).monospacedDigit().font(.caption).foregroundStyle(p.muted)
                    .accessibilityIdentifier("song-position-\(value.name)")
                songInfo(value).frame(maxWidth: .infinity, alignment: .leading)
                Button { bookmarks.prefer(value.id, on: "edit-list"); song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Edit song").accessibilityIdentifier("edit-song-\(value.name)")
                Button { draftSongIDs.removeAll { $0 == value.id } } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Remove from setlist").accessibilityIdentifier("delete-song-\(value.name)")
            }.padding(.horizontal, 10).padding(.vertical, 10).frame(minHeight: 76)
        }, above: {
            VStack(alignment: .leading, spacing: 10) {
                Text("Setlist name").font(.subheadline).foregroundStyle(p.muted)
                TextField("Setlist name", text: $listName).focused($namingList).submitLabel(.done).onSubmit { namingList = false }
                    .padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
            }
        }, below: {
            VStack(spacing: 16) {
                Button(action: showSongPicker) { Label("Add song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-song")
                if !creatingList {
                    Button { deletingList = true } label: { Text("Delete setlist").foregroundStyle(.red.opacity(0.8)).frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).foregroundStyle(.red.opacity(0.8)).padding(.top, 18).accessibilityIdentifier("delete-setlist")
                    Text("Songs stay in your library.").font(.subheadline).foregroundStyle(p.muted).frame(maxWidth: .infinity)
                }
            }
        })
    }
    private func browseSong(_ index: Int, _ value: SavedPreset) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(format: "%02d", index + 1)).monospacedDigit().font(.system(size: 13)).foregroundStyle(p.muted).frame(minWidth: 20)
                .accessibilityIdentifier("song-position-\(value.name)")
            Button {
                if let id = browsingSetlistID {
                    useCounts[id.uuidString, default: 0] += 1
                    UserDefaults.standard.set(useCounts, forKey: "performedSetlists")
                }
                model.loadSong(value, from: browsingSetlistID)
                performing = true
            } label: {
                HStack { songInfo(value); Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption) }
                    .frame(maxWidth: .infinity, minHeight: 58).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("song-\(value.name)")
                .accessibilityAddTraits(model.activeSetlistID == browsingSetlistID && model.selectedSongID == value.id ? .isSelected : [])
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }
    private func songInfo(_ value: SavedPreset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value.name).font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) { Text("\(value.rhythm.bpm) BPM · \(value.rhythm.beats)/\(value.rhythm.denominator)"); score(value) }
                VStack(alignment: .leading, spacing: 3) { Text("\(value.rhythm.bpm) BPM · \(value.rhythm.beats)/\(value.rhythm.denominator)"); score(value) }
            }.font(.system(size: 12)).foregroundStyle(p.muted)
        }
    }
    private func score(_ value: SavedPreset) -> some View { RhythmScore(rhythm: value.rhythm, color: p.muted).frame(width: 48, height: 24) }
    private var savedSongPicker: some View {
        let entries = model.songLibrary.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
        return CatalogList(items: entries, p: p, bookmarks: bookmarks, page: "add-song", row: { _, value in
            let exists = draftSongIDs.contains(value.id)
            Button {
                dismissTextInput()
                draftSongIDs.append(value.id)
                adding = false
                search = ""
            } label: {
                HStack { songInfo(value); Spacer(); Image(systemName: exists ? "checkmark" : "plus") }
                    .padding(14).frame(minHeight: 60).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).disabled(exists).accessibilityIdentifier("import-song-\(value.name)")
        }, above: {
            if entries.isEmpty {
                Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted)
            }
        }, below: { EmptyView() })
    }
    private var managedLibrary: some View {
        // Build memberships once per render, not once per song and search predicate.
        var membership: [UUID: [String]] = [:]
        for list in model.setlists { for song in list.songs { membership[song.id, default: []].append(list.name) } }
        let entries = model.songLibrary.filter { search.isEmpty || $0.name.localizedStandardContains(search) || (membership[$0.id] ?? []).contains { $0.localizedStandardContains(search) } }
        let move: ((UUID, Int) -> Void)? = search.isEmpty ? { id, index in model.moveLibrarySong(id, to: index) } : nil
        return CatalogList(items: entries, p: p, bookmarks: bookmarks, page: "library",
                           move: move, row: { _, value in
            libraryRow(value, memberships: membership[value.id] ?? [])
        }, above: {
            if entries.isEmpty {
                Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted)
            }
        }, below: { EmptyView() })
    }
    private func libraryRow(_ value: SavedPreset, memberships: [String]) -> some View {
        HStack(spacing: 10) {
            if search.isEmpty { grip("library-drag-\(value.name)") }
            Button { dismissTextInput(); model.loadStandaloneSong(value.id); performing = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { songInfo(value); Spacer(minLength: 0) }
                    if !memberships.isEmpty {
                        SongLabelFlow(spacing: 5) {
                            ForEach(Array(memberships.enumerated()), id: \.offset) { _, name in
                                Text(name).font(.system(size: 11)).lineLimit(2).padding(.horizontal, 7).padding(.vertical, 4)
                                    .background(p.body.opacity(0.8), in: RoundedRectangle(cornerRadius: 5))
                                    .accessibilityIdentifier("membership-\(value.name)-\(name)")
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("library-open-\(value.name)")
            Button { bookmarks.prefer(value.id, on: "library"); dismissTextInput(); song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("Edit song").accessibilityIdentifier("library-edit-\(value.name)")
        }.padding(14).accessibilityElement(children: .contain).accessibilityIdentifier("library-row-\(value.name)")
    }
    private func songEditor(_ initial: SavedPreset) -> some View {
        let exists = model.songLibrary.contains { $0.id == initial.id }
        return VStack(spacing: 16) {
            SongEditor(model: model, initial: initial, p: p, picker: $songPicker, divisionEditing: $songDivisionEditing,
                       addToSetlist: exists && startInSongLibrary ? { sharing = initial } : nil,
                       delete: exists && startInSongLibrary ? { deletingSong = true } : nil,
                       cancel: { song = nil }) { value in
                if exists { model.editSong(value.id, name: value.name, rhythm: value.rhythm, notes: value.notes, membershipChanges: membershipChanges) }
                else if let id = model.createLibrarySong(value.name, rhythm: value.rhythm, notes: value.notes), editing { draftSongIDs.append(id) }
                song = nil; adding = false
            }.id(initial.id)
        }
    }
    private func targets(_ value: SavedPreset) -> some View {
        VStack(spacing: 14) {
            Text(value.name).font(.headline)
            if model.setlists.isEmpty { Text("No setlists yet.").foregroundStyle(p.muted) }
            ForEach(model.setlists) { list in
                let original = list.songs.contains { $0.id == value.id }
                let exists = membershipChanges[list.id] ?? original
                Button {
                    let selected = !exists
                    membershipChanges[list.id] = selected == original ? nil : selected
                } label: {
                    HStack { Text(list.name); Spacer(); Image(systemName: exists ? "checkmark" : "plus") }.padding(18).frame(minHeight: 60)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityAddTraits(exists ? .isSelected : []).accessibilityIdentifier("share-to-\(list.name)")
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
