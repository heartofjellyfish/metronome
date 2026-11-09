import SwiftUI
import UIKit

struct SetlistPanel: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    let close: () -> Void
    let startInSongLibrary: Bool
    @State private var browsingSetlistID: UUID?
    @State private var editing = false
    @State private var editingLibrary = false
    @State private var libraryOrder: [UUID] = []
    @State private var creatingList = false
    @State private var listName = ""
    @State private var draftSongIDs: [UUID] = []
    @State private var compactTitle = false
    @State private var bookmarks = ListBookmarks()
    @State private var shelfHeight: CGFloat = 0
    @State private var listQuery = ""
    @FocusState private var searchingLists: Bool
    @State private var useCounts: [String: Int] = [:]
    private var atRoot: Bool { !startInSongLibrary && browsingSetlistID == nil && !editing && song == nil }
    @State private var songCatalogHeight: CGFloat = 0
    @State private var adding = false
    @State private var pickerOpenedFromBrowse = false
    @State private var pendingSongIDs: [UUID] = []
    @State private var search = ""
    @State private var song: SavedPreset?
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
    private var needsListName: Bool { listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var choosingSong: Bool { adding && song == nil }
    private var libraryRoot: Bool { startInSongLibrary && song == nil }
    private var browsingDetail: Bool { browsedList != nil && !editing && song == nil && !adding }
    private var browsingEmptyList: Bool { browsingDetail && browsedList?.songs.isEmpty == true }
    private var footerAddsSongs: Bool { editing || browsingEmptyList }
    private var title: String {
        if adding { return L10n.text("Add songs") }
        if editing { return L10n.text(creatingList ? "New setlist" : "Edit setlist") }
        return L10n.text(startInSongLibrary ? "Song library" : "Setlists")
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(p.dark ? 0.55 : 0.3).ignoresSafeArea().accessibilityHidden(true)
                VStack(spacing: 0) {
                    if song == nil { header }
                    if libraryRoot {
                        catalogSearch(library: libraryRoot).padding(.horizontal, 20)
                    }
                    Group {
                        if let song {
                            songEditor(song).id(song.id)
                        } else if adding {
                            VStack(spacing: 0) {
                                GeometryReader { space in
                                    VStack(spacing: 0) {
                                        if !search.isEmpty || searchingLists || songCatalogHeight > space.size.height {
                                            catalogSearch(library: true).padding(.horizontal, 20)
                                        }
                                        savedSongPicker.padding(.horizontal, 20).padding(.top, 8)
                                    }
                                }
                                VStack(alignment: .trailing, spacing: 8) {
                                    Divider()
                                    newLibrarySongButton("new-song")
                                }.padding(.horizontal, 20).padding(.bottom, 16)
                            }
                        } else if startInSongLibrary {
                            VStack(alignment: .trailing, spacing: 12) {
                                managedLibrary
                                HStack {
                                    if !editingLibrary && !model.songLibrary.isEmpty {
                                        Button {
                                            dismissTextInput()
                                            libraryOrder = model.songLibrary.map(\.id)
                                            editingLibrary = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                                .padding(.horizontal, 12).frame(minWidth: 88, minHeight: 44)
                                        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("library-start-editing")
                                    } else {
                                        Text(songCount(model.songLibrary.count)).font(.subheadline).foregroundStyle(p.muted)
                                    }
                                    Spacer(minLength: 16)
                                    newLibrarySongButton("library-new-song")
                                }
                            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
                        } else if browsedList != nil || creatingList {
                            listDetail(browsedList)
                        } else {
                            setlistBrowser
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    if browsingDetail || editingListRoot {
                        VStack(spacing: 8) {
                            Divider()
                            HStack(spacing: 0) {
                                if editing && !creatingList {
                                    Button {
                                        dismissTextInput()
                                        deletingList = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "trash").accessibilityHidden(true)
                                            Text("Delete setlist")
                                        }.font(.subheadline)
                                            .foregroundStyle(p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C))
                                            .padding(.horizontal, 12).frame(minHeight: 44)
                                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("delete-setlist")
                                } else if browsingEmptyList {
                                    Button { beginEdit(new: false) } label: {
                                        Label("Edit setlist", systemImage: "pencil")
                                            .padding(.horizontal, 12).frame(minHeight: 44)
                                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("edit-setlist")
                                } else {
                                    Text(songCount(editing ? draftSongIDs.count : browsedList?.songs.count ?? 0))
                                        .font(.subheadline).foregroundStyle(p.muted)
                                        .accessibilityIdentifier("setlist-count")
                                }
                                Spacer(minLength: 16)
                                Button {
                                    if footerAddsSongs {
                                        pickerOpenedFromBrowse = !editing
                                        if !editing { beginEdit(new: false) }
                                        showSongPicker()
                                    } else { beginEdit(new: false) }
                                } label: {
                                    ZStack {
                                        Label("Edit setlist", systemImage: "pencil").opacity(footerAddsSongs ? 0 : 1)
                                        Label("Add songs", systemImage: "plus").opacity(footerAddsSongs ? 1 : 0)
                                    }
                                    .transaction { $0.animation = nil }
                                    .padding(.horizontal, 14).frame(minWidth: 146, minHeight: 44)
                                }.buttonStyle(HardwareButtonStyle(p: p))
                                    .accessibilityLabel(footerAddsSongs ? Text("Add songs") : Text("Edit setlist"))
                                    .accessibilityIdentifier(footerAddsSongs ? "add-song" : "edit-setlist")
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
        .onChange(of: song?.id) { _, _ in membershipChanges = [:] }
        .overlay { if performing { PerformanceView(model: model, fromSongLibrary: startInSongLibrary, back: { performing = false }) } }
        .sheet(item: $sharing) { value in
            targets(value)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if deletingSong, let song {
                let affected = model.listsContainingSong(song.id)
                deleteConfirmation(name: song.name,
                    detail: L10n.text(affected.isEmpty ? "Delete this song from your library?" : "This song will be removed from your library and these setlists."),
                    affectedSetlists: affected,
                    action: "Delete song", identifier: "confirm-delete-library-song",
                    cancel: { deletingSong = false }) {
                        deletingSong = false
                        model.deleteLibrarySong(song.id)
                        if model.songLibrary.isEmpty { editingLibrary = false }
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

    private func deleteConfirmation(name: String, detail: String, affectedSetlists: [SongSetlist] = [],
                                    action: String, identifier: String,
                                    cancel: @escaping () -> Void, confirm: @escaping () -> Void) -> some View {
        let affectedNames = VStack(alignment: .leading, spacing: 0) {
            ForEach(affectedSetlists) { list in
                if list.id != affectedSetlists.first?.id { Divider() }
                Text(verbatim: list.name)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .accessibilityIdentifier("affected-setlist-" + list.name)
            }
        }
        let message = VStack(alignment: .leading, spacing: 10) {
            Text(name).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(detail)
            if !affectedSetlists.isEmpty {
                ViewThatFits(in: .vertical) {
                    affectedNames.fixedSize(horizontal: false, vertical: true)
                    ScrollView { affectedNames }.accessibilityIdentifier("delete-impact-scroll")
                }.clipShape(RoundedRectangle(cornerRadius: 9)).insetPanel(p, radius: 9)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(p.ink)
        return ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                message
                HStack(spacing: 12) {
                    Button(action: cancel) { Label("Cancel", systemImage: "xmark").frame(maxWidth: .infinity, minHeight: 46) }
                        .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                    Button(action: confirm) {
                        Label(L10n.text(action), systemImage: "trash").foregroundStyle(p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C))
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
            if editingListRoot || choosingSong || editingLibrary {
                draftHeader
            } else {
                if browsingDetail {
                    Button { browsingSetlistID = nil } label: {
                        Label("All setlists", systemImage: "chevron.left").font(.system(size: 15)).padding(.horizontal, 12).frame(minHeight: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("choose-setlist")
                } else {
                    Text(title).font(.system(size: 22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                }
                if browsingDetail && compactTitle, let list = browsedList {
                    Text(list.name).font(.headline).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("compact-setlist-title")
                } else { Spacer(minLength: 0) }
                // Nested drafts return via Back/Cancel, never bypass the setlist's Save/Cancel.
                if !editing && song == nil {
                    Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Close").accessibilityIdentifier("close-panel")
                }
            }
        }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
    }
    private func newLibrarySongButton(_ identifier: String) -> some View {
        Button {
            dismissTextInput()
            song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy)
        } label: {
            Label("New song", systemImage: "plus")
                .padding(.horizontal, 14).frame(minWidth: 146, minHeight: 44)
        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier(identifier)
    }
    private var draftHeader: some View {
        let cancelButton = Button {
            if editingLibrary { finishLibraryEditing(save: false) }
            else if choosingSong {
                if pickerOpenedFromBrowse { cancelList() }
                finishPickingSongs()
            } else { cancelList() }
        } label: {
            if choosingSong {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            } else {
                Label("Cancel", systemImage: "xmark").padding(.horizontal, 10).frame(minHeight: 44)
            }
        }.accessibilityLabel("Cancel")
            .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier(editingLibrary ? "cancel-library" : choosingSong ? "cancel-picking-songs" : "cancel-setlist").fixedSize(horizontal: true, vertical: false)
        let saveButton = Button {
            if editingLibrary { finishLibraryEditing(save: true); return }
            if choosingSong {
                draftSongIDs.append(contentsOf: pendingSongIDs)
                finishPickingSongs()
                if needsListName {
                    namingList = true
                    return
                }
            }
            saveList()
        } label: {
            HStack(spacing: 5) {
                Label(choosingSong && needsListName ? "Next" : "Save", systemImage: choosingSong && needsListName ? "arrow.right" : "checkmark")
                if choosingSong && !pendingSongIDs.isEmpty { Text(verbatim: "(\(pendingSongIDs.count))").monospacedDigit() }
            }.padding(.horizontal, 12).frame(minHeight: 44)
        }
            .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
            .disabled(!editingLibrary && (choosingSong ? pendingSongIDs.isEmpty : needsListName))
            .accessibilityIdentifier(editingLibrary ? "save-library" : "save-setlist").fixedSize(horizontal: true, vertical: false)
        let heading = Text(editingListRoot && compactTitle && !creatingList ? listName : title)
            .font(.system(size: 19, weight: .semibold)).lineLimit(1)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: choosingSong ? 14 : 8) {
                cancelButton
                heading.fixedSize().frame(maxWidth: .infinity, alignment: choosingSong ? .leading : .center)
                saveButton
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack { cancelButton; Spacer(minLength: 4); saveButton }
                heading
            }
        }
    }
    private func finishLibraryEditing(save: Bool) {
        dismissTextInput()
        if save { model.saveLibraryOrder(libraryOrder) }
        editingLibrary = false
        libraryOrder = []
    }
    private func finishPickingSongs() {
        dismissTextInput()
        adding = false
        pickerOpenedFromBrowse = false
        pendingSongIDs = []
        search = ""
    }
    private func showSongPicker() {
        dismissTextInput()
        bookmarks.clear("add-song")
        songCatalogHeight = 0
        search = ""
        adding = true
    }
    private func beginEdit(new: Bool) {
        if new { bookmarks.clear("new-setlist"); compactTitle = false }
        dismissTextInput(); creatingList = new; editing = true
        listName = new ? "" : browsedList?.name ?? ""
        draftSongIDs = new ? [] : browsedList?.songs.map(\.id) ?? []
    }
    private func cancelList() {
        dismissTextInput(); editing = false; creatingList = false; draftSongIDs = []; listName = ""
    }
    private func saveList() {
        dismissTextInput()
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
            if choosingSong { Image(systemName: "magnifyingglass").foregroundStyle(p.muted).accessibilityHidden(true) }
            TextField(choosingSong ? LocalizedStringKey("Search songs") : LocalizedStringKey("Search"), text: query).focused($searchingLists).submitLabel(.done)
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
    private var setlistBrowser: some View {
        GeometryReader { space in
            let gap: CGFloat = 12
            let footerHeight: CGFloat = 44
            let available = max(0, space.size.height - 8 - 16 - footerHeight - gap)
            let contentHeight = shelfHeight > 0 ? shelfHeight : CGFloat(model.setlists.count) * 68 + 16
            let showsSearch = !model.setlists.isEmpty && (contentHeight > available || searchingLists || !listQuery.isEmpty)
            VStack(alignment: .trailing, spacing: 0) {
                if showsSearch {
                    catalogSearch(library: false).padding(.bottom, 8)
                }
                if !model.setlists.isEmpty {
                    listLibrary
                        .frame(maxHeight: showsSearch ? .infinity : contentHeight)
                        .padding(.bottom, gap)
                }
                Button { beginEdit(new: true) } label: {
                    Label("New setlist", systemImage: "plus")
                        .padding(.horizontal, 14).frame(minWidth: 146, minHeight: footerHeight)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("new-setlist")
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
        }
    }
    private var listLibrary: some View {
        let query = listQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lists = model.setlists.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
        let showFrequent = searchingLists && query.isEmpty && model.setlists.count >= 20
        let move: ((UUID, Int) -> Void)? = query.isEmpty ? { id, index in model.moveSetlist(id, to: index) } : nil
        return CatalogList(items: lists, p: p, bookmarks: bookmarks, page: "setlists", compactMargins: true, move: move,
                           onContentHeight: { if query.isEmpty && !searchingLists && abs(shelfHeight - $0) > 0.5 { shelfHeight = $0 } }, row: { _, list in
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
            if showFrequent {
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
        }, below: { EmptyView() }).screen()
    }
    private func songCount(_ count: Int) -> String { L10n.format(count == 1 ? "%d song" : "%d songs", count) }
    private var draftSongs: [SavedPreset] {
        let catalog = Dictionary(model.songLibrary.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return draftSongIDs.compactMap { catalog[$0] }
    }
    private func listDetail(_ list: SongSetlist?) -> some View {
        let page = list?.id.uuidString ?? "new-setlist"
        let move: ((UUID, Int) -> Void)? = editing ? { id, index in
            guard let source = draftSongIDs.firstIndex(of: id) else { return }
            draftSongIDs.remove(at: source)
            draftSongIDs.insert(id, at: index)
        } : nil
        return CatalogList(items: editing ? draftSongs : list?.songs ?? [], p: p, bookmarks: bookmarks, page: page,
                           move: move, onHeaderScrolled: { compactTitle = $0 }, row: { index, value in
            if editing {
                editableSong(index, value, page: page)
            } else {
                browseSong(index, value)
            }
        }, above: {
            VStack(alignment: .leading, spacing: 16) {
                if creatingList {
                    TextField("Setlist name", text: $listName)
                        .font(.system(size: 28, weight: .semibold))
                        .focused($namingList).submitLabel(.done)
                        .onSubmit { namingList = false }
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .insetPanel(p, radius: 8).accessibilityIdentifier("setlist-name")
                } else if let list {
                    if editing {
                        EditableSetlistTitle(name: $listName, p: p)
                    } else {
                        Text(list.name).font(.system(size: 28, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .accessibilityIdentifier("setlist-title")
                    }

                }
                if editing ? draftSongIDs.isEmpty : list?.songs.isEmpty == true {
                    Text("No songs yet.").font(.subheadline).foregroundStyle(p.muted)
                        .accessibilityIdentifier("setlist-empty-message")
                }
            }
        }, below: { EmptyView() }).screen().padding(.horizontal, 20).padding(.vertical, 8).id(page)
    }
    private func editableSong(_ index: Int, _ value: SavedPreset, page: String) -> some View {
        HStack(spacing: 6) {
            grip("drag-song-\(value.name)")
            Text(String(format: "%02d", index + 1)).monospacedDigit().font(.caption).foregroundStyle(p.muted)
                .accessibilityIdentifier("song-position-\(value.name)")
            songInfo(value).frame(maxWidth: .infinity, alignment: .leading)
            Button { bookmarks.prefer(value.id, on: page); song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Edit song").accessibilityIdentifier("edit-song-\(value.name)")
            Button { draftSongIDs.removeAll { $0 == value.id } } label: { Image(systemName: "minus").foregroundStyle(p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C)).frame(width: 44, height: 44) }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Remove from setlist").accessibilityIdentifier("delete-song-\(value.name)")
        }.padding(.horizontal, 10).padding(.vertical, 10).frame(minHeight: 78)
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
    private func songInfo(_ value: SavedPreset, maxTitleLines: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value.name).font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.leading)
                .lineLimit(maxTitleLines).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) { Text("\(value.rhythm.bpm) BPM · \(value.rhythm.beats)/\(value.rhythm.denominator)"); score(value) }
                VStack(alignment: .leading, spacing: 3) { Text("\(value.rhythm.bpm) BPM · \(value.rhythm.beats)/\(value.rhythm.denominator)"); score(value) }
            }.font(.system(size: 12)).foregroundStyle(p.muted)
        }
    }
    private func score(_ value: SavedPreset) -> some View { RhythmScore(rhythm: value.rhythm, color: p.muted).frame(width: 48, height: 24) }
    private var savedSongPicker: some View {
        let entries = model.songLibrary.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
        let existing = Set(draftSongIDs)
        let selected = Set(pendingSongIDs)
        return CatalogList(items: entries, p: p, bookmarks: bookmarks, page: "add-song", onContentHeight: { height in
            if search.isEmpty { songCatalogHeight = height }
        }, row: { _, value in
            let exists = existing.contains(value.id)
            let picked = selected.contains(value.id)
            Button {
                if pendingSongIDs.contains(value.id) { pendingSongIDs.removeAll { $0 == value.id } }
                else { pendingSongIDs.append(value.id) }
            } label: {
                HStack {
                    songInfo(value, maxTitleLines: 2)
                    Spacer(minLength: 8)
                    Image(systemName: exists || picked ? "checkmark" : "plus")
                        .font(.system(size: 19, weight: picked ? .semibold : .regular))
                        .foregroundStyle(picked ? p.ink : p.muted)
                        .frame(width: 24).accessibilityHidden(true)
                }.padding(14).frame(minHeight: 60).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).disabled(exists)
                .accessibilityAddTraits(exists || picked ? .isSelected : [])
                .accessibilityIdentifier("import-song-\(value.name)")
        }, above: {
            if entries.isEmpty {
                Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted)
            }
        }, below: { EmptyView() }).screen()
    }
    private var managedLibrary: some View {
        // Build memberships once per render, not once per song and search predicate.
        var membership: [UUID: [String]] = [:]
        for list in model.setlists { for song in list.songs { membership[song.id, default: []].append(list.name) } }
        let songs = editingLibrary ? model.librarySongs(inOrder: libraryOrder) : model.songLibrary
        let entries = songs.filter { search.isEmpty || $0.name.localizedStandardContains(search) || (membership[$0.id] ?? []).contains { $0.localizedStandardContains(search) } }
        let move: ((UUID, Int) -> Void)? = editingLibrary && search.isEmpty ? { id, index in
            var ids = songs.map(\.id)
            guard let source = ids.firstIndex(of: id), ids.indices.contains(index) else { return }
            ids.remove(at: source)
            ids.insert(id, at: index)
            libraryOrder = ids
        } : nil
        return CatalogList(items: entries, p: p, bookmarks: bookmarks, page: "library",
                           move: move, row: { _, value in
            libraryRow(value, memberships: membership[value.id] ?? [])
        }, above: {
            if entries.isEmpty {
                Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted)
            }
        }, below: { EmptyView() }).screen()
    }
    private func libraryRow(_ value: SavedPreset, memberships: [String]) -> some View {
        let layout = editingLibrary ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                                    : AnyLayout(HStackLayout(spacing: 8))
        return HStack(spacing: 10) {
            if editingLibrary && search.isEmpty { grip("library-drag-\(value.name)") }
            layout {
                Button {
                    dismissTextInput()
                    model.loadStandaloneSong(value.id)
                    performing = true
                } label: {
                    songInfo(value, maxTitleLines: 2).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("library-open-\(value.name)")
                if let first = memberships.first {
                    Button {
                        dismissTextInput()
                        membershipChanges = [:]
                        sharing = value
                    } label: {
                        HStack(spacing: 5) {
                            Text(verbatim: first).lineLimit(1).truncationMode(.middle)
                                .accessibilityIdentifier("membership-\(value.name)-\(first)")
                            if memberships.count > 1 {
                                Text(verbatim: "+\(memberships.count - 1)").fixedSize()
                                    .accessibilityLabel(memberships.dropFirst().joined(separator: ", "))
                                    .accessibilityIdentifier("membership-overflow-\(value.name)")
                            }
                            Image(systemName: "chevron.right").font(.caption2).accessibilityHidden(true)
                        }.font(.caption2).padding(.horizontal, 7).padding(.vertical, 4)
                            .background(p.body.opacity(0.8), in: RoundedRectangle(cornerRadius: 5))
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }.frame(maxWidth: editingLibrary ? nil : 116, alignment: .trailing)
                        .buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("library-setlists-\(value.name)")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if editingLibrary {
                Button { bookmarks.prefer(value.id, on: "library"); dismissTextInput(); song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("Edit song").accessibilityIdentifier("library-edit-\(value.name)")
            }
        }.padding(.horizontal, 14).padding(.vertical, 8).accessibilityElement(children: .contain).accessibilityIdentifier("library-row-\(value.name)")
    }
    private func songEditor(_ initial: SavedPreset) -> some View {
        let exists = model.songLibrary.contains { $0.id == initial.id }
        return VStack(spacing: 16) {
            SongEditor(model: model, initial: initial, p: p, isNew: !exists,
                       addToSetlist: exists && startInSongLibrary ? { sharing = initial } : nil,
                       delete: exists && startInSongLibrary ? { deletingSong = true } : nil,
                       cancel: { song = nil }) { value in
                if exists { model.editSong(value.id, name: value.name, rhythm: value.rhythm, notes: value.notes, membershipChanges: membershipChanges) }
                else if let id = model.createLibrarySong(value.name, rhythm: value.rhythm, notes: value.notes), adding {
                    pendingSongIDs.append(id)
                    search = ""
                }
                song = nil
            }.id(initial.id)
        }
    }
    private func targets(_ value: SavedPreset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Setlists").font(.title2.bold())
                Spacer()
                Button {
                    if song == nil, !membershipChanges.isEmpty,
                       let current = model.songLibrary.first(where: { $0.id == value.id }) {
                        model.editSong(current.id, name: current.name, rhythm: current.rhythm, membershipChanges: membershipChanges)
                        membershipChanges = [:]
                    }
                    sharing = nil
                } label: {
                    Label(song == nil ? "Save" : "Done", systemImage: "checkmark")
                        .padding(.horizontal, 12).frame(minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p, charcoal: true)).accessibilityIdentifier("membership-done")
            }
            Text(verbatim: value.name).font(.headline).lineLimit(2)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.setlists.isEmpty { Text("No setlists yet.").foregroundStyle(p.muted).padding() }
                    ForEach(model.setlists) { list in
                        let original = list.songs.contains { $0.id == value.id }
                        let selected = membershipChanges[list.id] ?? original
                        Button {
                            let next = !selected
                            membershipChanges[list.id] = next == original ? nil : next
                        } label: {
                            HStack(spacing: 12) {
                                Text(verbatim: list.name).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: selected ? "checkmark" : "plus")
                                    .foregroundStyle(selected ? p.ink : p.muted).accessibilityHidden(true)
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                                .frame(minHeight: 50).contentShape(Rectangle())
                        }.buttonStyle(InsetRowButtonStyle(p: p))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("share-to-\(list.name)")
                        if list.id != model.setlists.last?.id { Divider().padding(.horizontal, 14) }
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 14)).insetPanel(p, radius: 14)
        }.padding(20).padding(.top, 8).foregroundStyle(p.ink)
            .background { InstrumentBody(p: p).ignoresSafeArea() }
    }
}

private struct EditableSetlistTitle: View {
    @Binding var name: String
    let p: InstrumentPalette
    @State private var renaming = false

    var body: some View {
        Group {
            if renaming {
                HStack(spacing: 0) {
                    SetlistNameField(name: $name, p: p, finish: {
                        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { renaming = false }
                    })
                    Button { dismissTextInput(); renaming = false } label: {
                        Image(systemName: "checkmark").frame(width: 44, height: 48).contentShape(Rectangle())
                    }.buttonStyle(InsetRowButtonStyle(p: p))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Done").accessibilityIdentifier("finish-rename-setlist")
                }.padding(.leading, 12).insetPanel(p, radius: 9)
            } else {
                Button { renaming = true } label: {
                    HStack(spacing: 10) {
                        Text(verbatim: name.isEmpty ? L10n.text("Setlist name") : name)
                            .font(.system(size: 28, weight: .semibold))
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "pencil").foregroundStyle(p.muted).frame(width: 44, height: 48)
                    }.padding(.leading, 12).frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(InsetRowButtonStyle(p: p)).insetPanel(p, radius: 9)
                    .accessibilityLabel("Setlist name").accessibilityValue(name)
                    .accessibilityIdentifier("rename-setlist")
            }
        }
    }
}

/// Focus the actual input once it belongs to the window, including inside a reused catalog cell.
private struct SetlistNameField: UIViewRepresentable {
    @Binding var name: String
    let p: InstrumentPalette
    let finish: () -> Void

    final class Input: UITextField, UITextFieldDelegate {
        var onChange: ((String) -> Void)?
        var onFinish: (() -> Void)?
        private var requestedFocus = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, !requestedFocus else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, window != nil, !requestedFocus, becomeFirstResponder() else { return }
                requestedFocus = true
                selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)
            }
        }

        @objc func changed() { onChange?(text ?? "") }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            resignFirstResponder()
            return true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            changed()
            onFinish?()
        }
    }

    func makeUIView(context: Context) -> Input {
        let field = Input()
        field.text = name
        field.placeholder = L10n.text("Setlist name")
        field.accessibilityLabel = field.placeholder
        field.accessibilityIdentifier = "setlist-name"
        field.font = .systemFont(ofSize: 28, weight: .semibold)
        field.returnKeyType = .done
        field.enablesReturnKeyAutomatically = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = field
        field.addTarget(field, action: #selector(Input.changed), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: Input, context: Context) {
        field.textColor = UIColor(p.ink)
        field.tintColor = UIColor(p.ink)
        field.onChange = { name = $0 }
        field.onFinish = finish
    }
}
