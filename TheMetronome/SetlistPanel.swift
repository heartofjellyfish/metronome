import SwiftUI
import UniformTypeIdentifiers
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
    @State private var deletingSong = false
    @State private var deletingList = false
    @State private var performing = false
    @State private var dragging: UUID?
    @State private var dragSession = UUID()
    @FocusState private var namingList: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: MetronomeModel, p: InstrumentPalette, initialSetlistID: UUID? = nil, startInSongLibrary: Bool = false, close: @escaping () -> Void) {
        self.model = model; self.p = p; self.close = close; self.startInSongLibrary = startInSongLibrary
        _browsingSetlistID = State(initialValue: model.setlists.first { $0.id == initialSetlistID }?.id)
    }
    private var browsedList: SongSetlist? { model.setlists.first { $0.id == browsingSetlistID } }
    private var editingListRoot: Bool { editing && song == nil && !adding }
    private var browsingDetail: Bool { browsedList != nil && !editing && song == nil && !adding }
    private var title: String {
        if song != nil, let songPicker { return SongEditor.title(for: songDivisionEditing ? "custom" : songPicker) }
        if let song { return L10n.text(model.songLibrary.contains { $0.id == song.id } ? "Edit song" : "New song") }
        if adding { return L10n.text("Add song") }
        if editing { return L10n.text(creatingList ? "New setlist" : "Edit setlist") }
        return L10n.text(startInSongLibrary ? "Song library" : "Setlists")
    }
    private var routeID: String {
        if let song { return "song-\(song.id)" }
        if adding { return "add" }
        if editing { return "edit-list" }
        return browsingSetlistID?.uuidString ?? "root"
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(p.dark ? 0.55 : 0.3).ignoresSafeArea().accessibilityHidden(true)
                VStack(spacing: 0) {
                    header
                    if atRoot && needsSearch {
                        HStack {
                            TextField("Search", text: $listQuery).focused($searchingLists).submitLabel(.done)
                                .accessibilityIdentifier("setlist-search")
                            if !listQuery.isEmpty {
                                Button { listQuery = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(p.muted) }
                                    .accessibilityLabel("Clear search")
                            }
                        }.padding(.horizontal, 12).frame(height: 44).insetPanel(p, radius: 9).padding(.horizontal, 20)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if let song { songEditor(song) }
                            else if adding { savedSongPicker }
                            else if editing { listEditor }
                            else if startInSongLibrary { managedLibrary }
                            else if let list = browsedList { listDetail(list) }
                            else { listLibrary }
                        }.padding(20)
                    }.scrollBounceBehavior(.always).scrollDismissesKeyboard(.interactively).id(routeID)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if atRoot { viewportHeight = $0 + (needsSearch ? 44 : 0) } }
                    if browsingDetail {
                        Button { beginEdit(new: false) } label: {
                            Label("Edit setlist", systemImage: "pencil").frame(maxWidth: .infinity, minHeight: 50)
                        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("edit-setlist")
                            .padding(.horizontal, 20).padding(.bottom, 18).padding(.top, 8)
                    }
                }.frame(maxWidth: 560).frame(height: geo.size.height - 12)
                    .accessibilityHidden(performing)
                    .allowsHitTesting(!performing)
                    .background { InstrumentBody(p: p) }.clipShape(RoundedRectangle(cornerRadius: 23))
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(p.light, lineWidth: 0.8))
                    .padding(.horizontal, 10).padding(.bottom, 7)
            }.foregroundStyle(p.ink)
        }
        .onAppear { useCounts = UserDefaults.standard.dictionary(forKey: "performedSetlists") as? [String: Int] ?? [:] }
        .onChange(of: song?.id) { _, _ in songPicker = nil; songDivisionEditing = false }
        .overlay { if performing { PerformanceView(model: model, fromSongLibrary: startInSongLibrary, back: { performing = false }) } }
        .sheet(item: $sharing) { value in
            NavigationStack {
                ScrollView { targets(value).padding(20) }.background(p.body)
                    .navigationTitle(L10n.text("Add to setlist")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { sharing = nil } } }
            }.presentationDetents([.medium, .large])
        }
        .confirmationDialog("Delete this song from your library and all setlists?", isPresented: $deletingSong, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let song { model.deleteLibrarySong(song.id); draftSongIDs.removeAll { $0 == song.id } }
                song = nil
            }.accessibilityIdentifier("confirm-delete-library-song")
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Delete this setlist? Songs stay in your library.", isPresented: $deletingList, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = browsingSetlistID { model.deleteSetlist(id) }
                cancelList(); browsingSetlistID = nil
            }.accessibilityIdentifier("confirm-delete-setlist")
            Button("Cancel", role: .cancel) { }
        }
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
                    Button { browsingSetlistID = nil; dragging = nil } label: {
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
                Spacer(minLength: 0)
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
        dismissTextInput(); model.endSoundPreview(); dragging = nil
        if song != nil, songPicker != nil {
            if songDivisionEditing { songDivisionEditing = false } else { songPicker = nil }
        } else if song != nil { song = nil }
        else if adding { adding = false }
    }
    private func beginEdit(new: Bool) {
        dismissTextInput(); dragging = nil; creatingList = new; editing = true
        listName = new ? "" : browsedList?.name ?? ""
        draftSongIDs = new ? [] : browsedList?.songs.map(\.id) ?? []
    }
    private func cancelList() {
        dismissTextInput(); editing = false; creatingList = false; draftSongIDs = []; listName = ""; dragging = nil
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
    private var listLibrary: some View {
        let query = listQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lists = model.setlists.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
        return VStack(spacing: 18) {
            if searchingLists && query.isEmpty && model.setlists.count >= 20 {
                let frequent = lists.filter { useCounts[$0.id.uuidString, default: 0] >= 3 }
                    .sorted { useCounts[$0.id.uuidString, default: 0] > useCounts[$1.id.uuidString, default: 0] }.prefix(3)
                if !frequent.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Frequently used").font(.footnote).foregroundStyle(p.muted)
                        ForEach(frequent) { list in
                            Button { dismissTextInput(); browsingSetlistID = list.id } label: {
                                HStack { Text(list.name); Spacer(); Image(systemName: "chevron.right") }.padding(10)
                            }.buttonStyle(HardwareButtonStyle(p: p))
                        }
                    }
                }
            }
            if lists.isEmpty && !query.isEmpty { Text("No matches.").foregroundStyle(p.muted) }
            if !lists.isEmpty {
                VStack(spacing: 0) {
                    ForEach(lists) { list in
                        HStack(spacing: 6) {
                            if query.isEmpty { grip("drag-setlist-\(list.name)") }
                            Button { dismissTextInput(); browsingSetlistID = list.id; dragging = nil } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(list.name).font(.headline).multilineTextAlignment(.leading)
                                        Text(songCount(list.songs.count)).font(.subheadline).foregroundStyle(p.muted)
                                    }
                                    Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
                                }.frame(maxWidth: .infinity, minHeight: 58).contentShape(Rectangle())
                            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("setlist-\(list.name)")
                        }.padding(.horizontal, 12).padding(.vertical, 5)
                            .modifier(WholeSongDrag(enabled: query.isEmpty, id: list.id, dragging: $dragging, session: $dragSession) { id, target in
                                guard let index = model.setlists.firstIndex(where: { $0.id == target }) else { return }
                                reorder { model.moveSetlist(id, to: index) }
                            })
                        if list.id != lists.last?.id { divider }
                    }
                }.insetPanel(p, radius: 16)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if query.isEmpty { shelfHeight = $0 } }
            }
            if !needsSearch { Button { beginEdit(new: true) } label: { Label("New setlist", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("new-setlist") }
        }
    }
    private func songCount(_ count: Int) -> String { L10n.format(count == 1 ? "%d song" : "%d songs", count) }
    private var divider: some View { Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5).padding(.horizontal, 14) }
    private func listDetail(_ list: SongSetlist) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            let title = Text(list.name).font(.system(size: 28, weight: .semibold)).accessibilityIdentifier("setlist-title")
            let count = Text(songCount(list.songs.count)).font(.subheadline).foregroundStyle(p.muted)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) { title; count }.fixedSize()
                VStack(alignment: .leading, spacing: 4) { title; count }
            }
            if !list.songs.isEmpty { songRows(list.songs) }
        }
    }
    private var draftSongs: [SavedPreset] {
        let catalog = Dictionary(model.songLibrary.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return draftSongIDs.compactMap { catalog[$0] }
    }
    private var listEditor: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Setlist name").font(.subheadline).foregroundStyle(p.muted)
            TextField("Setlist name", text: $listName).focused($namingList).submitLabel(.done).onSubmit { namingList = false }
                .padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("setlist-name")
            if !draftSongs.isEmpty {
                EditableSongOrder(songs: draftSongs, order: $draftSongIDs) { index, value in
                    HStack(spacing: 6) {
                        grip("drag-song-\(value.name)")
                        Text(String(format: "%02d", index + 1)).monospacedDigit().font(.caption).foregroundStyle(p.muted)
                            .accessibilityIdentifier("song-position-\(value.name)")
                        songInfo(value).frame(maxWidth: .infinity, alignment: .leading)
                        Button { song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Edit song").accessibilityIdentifier("edit-song-\(value.name)")
                        Button { draftSongIDs.removeAll { $0 == value.id } } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                            .buttonStyle(HardwareButtonStyle(p: p, radius: 8)).accessibilityLabel("Remove from setlist").accessibilityIdentifier("delete-song-\(value.name)")
                    }.padding(.horizontal, 10).padding(.vertical, 10).frame(minHeight: 76)
                        .overlay(alignment: .bottom) { divider }
                        .foregroundStyle(p.ink)
                }
                .frame(height: min(CGFloat(draftSongIDs.count) * 76, 456))
                .insetPanel(p, radius: 16)
            }
            Button { dismissTextInput(); adding = true; search = "" } label: { Label("Add song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("add-song")
            if !creatingList {
                Button { deletingList = true } label: { Text("Delete setlist").foregroundStyle(.red.opacity(0.8)).frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(HardwareButtonStyle(p: p)).foregroundStyle(.red.opacity(0.8)).padding(.top, 18).accessibilityIdentifier("delete-setlist")
                Text("Songs stay in your library.").font(.subheadline).foregroundStyle(p.muted).frame(maxWidth: .infinity)
            }
        }
    }
    private func songRows(_ songs: [SavedPreset]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, value in
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
                if value.id != songs.last?.id { divider }
            }
        }.insetPanel(p, radius: 16)
    }
    private func reorder(_ action: () -> Void) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2), action) }
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
        return VStack(alignment: .leading, spacing: 14) {
            searchField
            HStack {
                Text("Song library").font(.headline)
                Spacer()
                Button {
                    dismissTextInput()
                    song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy)
                } label: {
                    Label("New song", systemImage: "plus").padding(.horizontal, 12).frame(minHeight: 44)
                }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("new-song")
            }
            if entries.isEmpty {
                Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted).padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { value in
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
                        if value.id != entries.last?.id { divider }
                    }
                }.insetPanel(p, radius: 14)
            }
        }
    }
    private var searchField: some View {
        TextField("Search", text: $search).submitLabel(.done).onSubmit { dismissTextInput() }
            .padding(14).insetPanel(p, radius: 10).accessibilityIdentifier("song-search")
    }
    private var managedLibrary: some View {
        // Build memberships once per render, not once per song and search predicate.
        var membership: [UUID: [String]] = [:]
        for list in model.setlists { for song in list.songs { membership[song.id, default: []].append(list.name) } }
        let entries = model.songLibrary.filter { search.isEmpty || $0.name.localizedStandardContains(search) || (membership[$0.id] ?? []).contains { $0.localizedStandardContains(search) } }
        return VStack(alignment: .leading, spacing: 18) {
            searchField
            Button { dismissTextInput(); song = SavedPreset(name: "", rhythm: model.rhythm.performanceCopy) } label: {
                Label("New song", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("library-new-song")
            if entries.isEmpty { Text(L10n.text(search.isEmpty ? "No songs yet." : "No matches.")).foregroundStyle(p.muted).padding(.vertical, 20) }
            else {
                VStack(spacing: 0) {
                    ForEach(entries) { value in
                        libraryRow(value, memberships: membership[value.id] ?? []).id(value.id)
                            .modifier(WholeSongDrag(enabled: search.isEmpty, id: value.id, dragging: $dragging, session: $dragSession) { id, target in
                                guard search.isEmpty, let index = model.songLibrary.firstIndex(where: { $0.id == target }) else { return }
                                reorder { model.moveLibrarySong(id, to: index) }
                            })
                        if value.id != entries.last?.id { divider }
                    }
                }.padding(.vertical, 4).insetPanel(p, radius: 16)
            }
        }.onChange(of: search) { _, _ in dragging = nil }
    }
    private func libraryRow(_ value: SavedPreset, memberships: [String]) -> some View {
        HStack(spacing: 10) {
            Button { dismissTextInput(); model.loadStandaloneSong(value.id); performing = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { songInfo(value); Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(p.muted) }
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
            Button { dismissTextInput(); song = value } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                .buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityLabel("Edit song").accessibilityIdentifier("library-edit-\(value.name)")
            if search.isEmpty { grip("library-drag-\(value.name)") }
        }.padding(14).accessibilityElement(children: .contain).accessibilityIdentifier("library-row-\(value.name)")
    }
    private func songEditor(_ initial: SavedPreset) -> some View {
        let exists = model.songLibrary.contains { $0.id == initial.id }
        return VStack(spacing: 16) {
            SongEditor(model: model, initial: initial, p: p, picker: $songPicker, divisionEditing: $songDivisionEditing,
                       addToSetlist: exists && startInSongLibrary ? { sharing = initial } : nil,
                       delete: exists && startInSongLibrary ? { deletingSong = true } : nil,
                       cancel: { song = nil }) { value in
                if exists { model.editSong(value.id, name: value.name, rhythm: value.rhythm, notes: value.notes) }
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
                let exists = list.songs.contains { $0.id == value.id }
                Button { model.addExistingSong(value.id, to: list.id); sharing = nil } label: {
                    HStack { Text(list.name); Spacer(); Image(systemName: exists ? "checkmark" : "plus") }.padding(18).frame(minHeight: 60)
                }.buttonStyle(HardwareButtonStyle(p: p)).disabled(exists).accessibilityIdentifier("share-to-\(list.name)")
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

private struct WholeSongDrag: ViewModifier {
    let enabled: Bool
    let id: UUID
    @Binding var dragging: UUID?
    @Binding var session: UUID
    let move: (UUID, UUID) -> Void
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            FullSizeSongDrag(content: content, id: id, dragging: $dragging, session: $session, move: move)
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
    let move: (UUID, UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        host.sizingOptions = [.intrinsicContentSize]
        let interaction = UIDragInteraction(delegate: context.coordinator)
        interaction.isEnabled = true
        host.view.addInteraction(interaction)
        host.view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return host
    }
    func updateUIViewController(_ host: UIHostingController<Content>, context: Context) {
        context.coordinator.parent = self
        host.rootView = content
        host.view.invalidateIntrinsicContentSize()
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<Content>, context: Context) -> CGSize? {
        uiViewController.sizeThatFits(in: CGSize(width: proposal.width ?? 320, height: .greatestFiniteMagnitude))
    }
    final class Coordinator: NSObject, UIDragInteractionDelegate, UIDropInteractionDelegate {
        private final class DraggedRow {
            let id: UUID
            init(_ id: UUID) { self.id = id }
        }
        var parent: FullSizeSongDrag
        private var token: UUID?
        init(_ parent: FullSizeSongDrag) { self.parent = parent }
        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            dismissTextInput()
            let token = UUID(); self.token = token
            parent.session = token
            parent.dragging = parent.id
            session.localContext = DraggedRow(parent.id)
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
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.localDragSession?.localContext is DraggedRow
        }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: session.localDragSession?.localContext is DraggedRow ? .move : .cancel)
        }
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            // Commit once on release. Moving hosting controllers while UIKit is still
            // tracking their drop regions can bounce the row back on a second enter.
            if let row = session.localDragSession?.localContext as? DraggedRow, row.id != parent.id {
                parent.move(row.id, parent.id)
            }
            parent.dragging = nil
        }
        func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) {
            if parent.session == token { parent.dragging = nil }
        }
    }
}

/// UIKit owns the moving gap until the gesture ends; SwiftUI owns the saved draft.
private struct EditableSongOrder<Row: View>: UIViewRepresentable {
    let songs: [SavedPreset]
    @Binding var order: [UUID]
    @ViewBuilder let row: (Int, SavedPreset) -> Row

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICollectionView {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(76))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let layout = UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: group))
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = false
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "song")
        view.dataSource = context.coordinator
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.drag(_:)))
        gesture.minimumPressDuration = 0.18
        gesture.delegate = context.coordinator
        view.addGestureRecognizer(gesture)
        return view
    }
    func updateUIView(_ view: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if !coordinator.moving && coordinator.items != songs {
            coordinator.items = songs
            view.reloadData()
        }
    }
    final class Coordinator: NSObject, UICollectionViewDataSource, UIGestureRecognizerDelegate {
        var parent: EditableSongOrder
        var items: [SavedPreset]
        var moving = false
        var grabOffset: CGFloat = 0
        init(_ parent: EditableSongOrder) { self.parent = parent; items = parent.songs }
        func collectionView(_ view: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
        func collectionView(_ view: UICollectionView, cellForItemAt path: IndexPath) -> UICollectionViewCell {
            let cell = view.dequeueReusableCell(withReuseIdentifier: "song", for: path)
            configure(cell, at: path.item)
            return cell
        }
        private func configure(_ cell: UICollectionViewCell, at index: Int) {
            cell.contentConfiguration = UIHostingConfiguration { parent.row(index, items[index]) }.margins(.all, 0)
        }
        func collectionView(_ view: UICollectionView, canMoveItemAt path: IndexPath) -> Bool { items.count > 1 }
        func collectionView(_ view: UICollectionView, moveItemAt source: IndexPath, to destination: IndexPath) {
            let moved = items.remove(at: source.item)
            items.insert(moved, at: destination.item)
            parent.order = items.map(\.id)
            DispatchQueue.main.async {
                for path in view.indexPathsForVisibleItems where self.items.indices.contains(path.item) {
                    if let cell = view.cellForItem(at: path) { self.configure(cell, at: path.item) }
                }
            }
        }
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let view = recognizer.view as? UICollectionView else { return false }
            let point = recognizer.location(in: view)
            return items.count > 1 && point.x <= 48 && view.indexPathForItem(at: point) != nil
        }
        @objc func drag(_ gesture: UILongPressGestureRecognizer) {
            guard let view = gesture.view as? UICollectionView else { return }
            let point = gesture.location(in: view)
            switch gesture.state {
            case .began:
                guard let path = view.indexPathForItem(at: point) else { return }
                dismissTextInput()
                grabOffset = (view.layoutAttributesForItem(at: path)?.center.y ?? point.y) - point.y
                moving = view.beginInteractiveMovementForItem(at: path)
            case .changed where moving:
                view.updateInteractiveMovementTargetPosition(CGPoint(x: view.bounds.midX, y: point.y + grabOffset))
            case .ended where moving: view.endInteractiveMovement(); moving = false
            case .cancelled, .failed: view.cancelInteractiveMovement(); moving = false
            default: break
            }
        }
    }
}
