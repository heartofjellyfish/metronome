import SwiftUI

/// Live starts with the musician's repertoire; opening a list never changes playback.
struct LiveModeHome: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    let openSong: (UUID, LiveSetlistAction) -> Void
    let openSetlist: (UUID?, LiveSetlistAction) -> Void
    @State private var bookmarks = ListBookmarks()
    @State private var recentSongOpen = false
    @State private var standalone = true
    @State private var songsTab = false
    @AppStorage("lastPlayedLiveSongID") private var lastPlayedID = ""
    @AppStorage("lastPlayedLiveSetlistID") private var lastSetlistID = ""
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }
    private var songs: [SavedPreset] { model.songLibrary }
    private var recentSong: SavedPreset? {
        songs.first { $0.id.uuidString == lastPlayedID } ?? model.recentSongs.first
    }
    private var hasPlaybackHistory: Bool { recentSong?.id.uuidString == lastPlayedID }
    private var recentSetlist: SongSetlist? {
        model.setlists.first { $0.id.uuidString == lastSetlistID && $0.songs.contains { $0.id.uuidString == lastPlayedID } }
    }
    var body: some View {
        VStack(spacing: 18) {
            resumeDisplay.frame(height: 144).insetPanel(p)
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    tab("Setlists", songs: false)
                    tab("Songs", songs: true)
                }.highPriorityGesture(DragGesture(minimumDistance: 24).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    songsTab = value.translation.width < 0
                }).padding(5).background { HardwareKeySurface(p: p, radius: 15, pressed: true) }
                    .padding(.bottom, 12)
                Group {
                    if songsTab {
                        if songs.isEmpty { emptyCatalog } else { songCatalog }
                    } else {
                        if model.setlists.isEmpty { emptyCatalog } else { catalog }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).liveScreen(p)
            }.frame(maxHeight: .infinity)
            HStack {
                Text(L10n.format(songsTab ? (songs.count == 1 ? "%d song" : "%d songs") : (model.setlists.count == 1 ? "%d setlist" : "%d setlists"), songsTab ? songs.count : model.setlists.count))
                    .font(.system(size: 13)).foregroundStyle(p.muted)
                Spacer()
                Button {
                    if songsTab { open(.songLibrary) }
                    else { openSetlist(nil, model.setlists.isEmpty ? .create : .browse) }
                } label: {
                    Label(L10n.text(songsTab ? (songs.isEmpty ? "Add songs" : "All songs") : (model.setlists.isEmpty ? "New setlist" : "All setlists")), systemImage: (songsTab ? songs.isEmpty : model.setlists.isEmpty) ? "plus" : "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium)).padding(.horizontal, 16).frame(minHeight: 46)
                }.buttonStyle(HardwareButtonStyle(p: p))
                    .accessibilityIdentifier(songsTab ? "live-all-songs" : "live-all-setlists")
            }
            if model.playing { SettingsPlaybackBar(model: model, p: p) }
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
            .fullScreenCover(isPresented: $recentSongOpen) {
                PerformanceView(model: model, fromSongLibrary: standalone, back: { recentSongOpen = false })
            }
    }
    private func tab(_ title: String, songs: Bool) -> some View {
        Button { songsTab = songs } label: {
            HStack(spacing: 9) { if songs { BeamedNotesIcon().frame(width: 20, height: 22) } else { Image(systemName: "folder") }; Text(L10n.text(title)) }
                .font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 46)
        }.buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: songsTab == songs))
            .accessibilityIdentifier(songs ? "live-tab-songs" : "live-tab-setlists")
            .accessibilityAddTraits(songsTab == songs ? .isSelected : [])
    }
    private var emptyCatalog: some View {
        VStack(spacing: 10) {
            Image(systemName: songsTab ? "music.note.list" : "folder").font(.system(size: 26))
            Text(L10n.text(songsTab ? "No songs yet." : "No setlists yet.")).font(.system(size: 17, weight: .medium))
            Text(L10n.text(songsTab ? "Save a song with its tempo and notes." : "Group your songs for a rehearsal or show."))
                .font(.system(size: 14)).multilineTextAlignment(.center)
        }.foregroundStyle(p.muted).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var resumeDisplay: some View {
        Group {
            if let song = recentSong {
                Button {
                    if model.selectedSongID != song.id || model.activeSetlistID != recentSetlist?.id {
                        if let list = recentSetlist { model.loadSong(song, from: list.id) }
                        else { model.loadStandaloneSong(song.id) }
                    }
                    standalone = recentSetlist == nil
                    recentSongOpen = true
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text(hasPlaybackHistory ? "Last played" : "Recently opened")).font(.system(size: 12)).foregroundStyle(p.muted)
                            Text(verbatim: song.name).font(.system(size: 25, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                            Text("\(song.rhythm.bpm) BPM · \(song.rhythm.beats)/\(song.rhythm.denominator)").font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(p.muted)
                    }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("live-last-played")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ready?").font(InstrumentType.display(50))
                    Text(L10n.text(songs.isEmpty ? "Add a song. Build your setlist." : "Choose a song. Follow the beat."))
                        .font(.system(size: 15)).foregroundStyle(p.muted)
                }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
    private var songCatalog: some View {
        CatalogList(items: songs, p: p, bookmarks: bookmarks, page: "live-songs", compactMargins: true, swipeActions: { song in
            songLibraryActions(song, edit: { openSong(song.id, .edit) }, delete: { openSong(song.id, .delete) })
        }, row: { _, song in
            Button {
                model.loadStandaloneSong(song.id)
                standalone = true
                recentSongOpen = true
            } label: {
                HStack(spacing: 12) {
                    BeamedNotesIcon().foregroundStyle(p.muted).frame(width: 25, height: 25)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: song.name).font(.system(size: 17, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Text("\(song.rhythm.bpm) BPM · \(song.rhythm.beats)/\(song.rhythm.denominator)").font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(p.muted)
                }.padding(.horizontal, 14).frame(minHeight: 68).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("live-song-\(song.id)")
        }, above: { EmptyView() }, below: { EmptyView() })
    }

    private var catalog: some View {
        CatalogList(items: model.setlists, p: p, bookmarks: bookmarks, page: "live-home", compactMargins: true, swipeActions: { list in
                        setlistActions(list, edit: { openSetlist(list.id, .edit) }, delete: { openSetlist(list.id, .delete) })
                    },
                    row: { _, list in
            Button { SetlistRecency.touch(list.id); openSetlist(list.id, .browse) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "folder").font(.system(size: 21)).foregroundStyle(p.muted).frame(width: 25)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: list.name).font(.system(size: 17, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Text(L10n.format(list.songs.count == 1 ? "%d song" : "%d songs", list.songs.count))
                            .font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(p.muted)
                }.frame(maxWidth: .infinity, minHeight: 58).padding(.horizontal, 14).padding(.vertical, 5).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("live-setlist-\(list.id)")
        }, above: { EmptyView() }, below: { EmptyView() })
    }

}

private extension View {
    func liveScreen(_ p: InstrumentPalette) -> some View {
        self.mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 10)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 22)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 16)).insetPanel(p, radius: 16)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16).stroke(p.edge.opacity(0.2), lineWidth: 1).padding(2).allowsHitTesting(false)
            }
    }
}

enum LiveSetlistAction { case browse, create, edit, delete }
enum SetlistRecency {
    static var dates: [String: Double] { UserDefaults.standard.dictionary(forKey: "recentSetlistDates") as? [String: Double] ?? [:] }
    static func touch(_ id: UUID) {
        var values = dates; values[id.uuidString] = Date().timeIntervalSince1970
        UserDefaults.standard.set(values, forKey: "recentSetlistDates")
    }
}
func setlistActions(_ list: SongSetlist, edit: @escaping () -> Void, delete: @escaping () -> Void) -> [CatalogRowAction] {
    [CatalogRowAction(id: "edit-setlist-" + list.name, title: "Edit", icon: "pencil", perform: edit),
     CatalogRowAction(id: "delete-setlist-" + list.name, title: "Delete", icon: "trash", destructive: true, perform: delete)]
}

/// Shared by the Live shelf, library swipe, and library edit controls.
func songLibraryActions(_ song: SavedPreset, edit: @escaping () -> Void, delete: @escaping () -> Void) -> [CatalogRowAction] {
    [CatalogRowAction(id: "library-edit-" + song.name, title: "Edit", icon: "pencil", perform: edit),
     CatalogRowAction(id: "library-delete-" + song.name, title: "Delete", icon: "trash", destructive: true, perform: delete)]
}

struct BeamedNotesIcon: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                let w = g.size.width, h = g.size.height
                p.addEllipse(in: CGRect(x: 0, y: h * 0.69, width: w * 0.34, height: h * 0.24))
                p.addEllipse(in: CGRect(x: w * 0.58, y: h * 0.57, width: w * 0.34, height: h * 0.24))
                p.addRect(CGRect(x: w * 0.27, y: h * 0.15, width: w * 0.07, height: h * 0.66))
                p.addRect(CGRect(x: w * 0.85, y: h * 0.03, width: w * 0.07, height: h * 0.66))
                p.move(to: CGPoint(x: w * 0.27, y: h * 0.15))
                p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.03))
                p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.18))
                p.addLine(to: CGPoint(x: w * 0.27, y: h * 0.30)); p.closeSubpath()
            }.fill()
        }.accessibilityHidden(true)
    }
}
