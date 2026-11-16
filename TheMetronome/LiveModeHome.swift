import SwiftUI

/// Live starts with the musician's repertoire; opening a list never changes playback.
struct LiveModeHome: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    let openSetlist: (UUID?, LiveSetlistAction) -> Void
    @State private var bookmarks = ListBookmarks()
    @State private var contentHeight: CGFloat = 0
    @State private var recentSongOpen = false
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }

    private var songs: [SavedPreset] {
        let recent = model.recentSongs
        let ids = Set(recent.map(\.id))
        return recent + model.songLibrary.filter { !ids.contains($0.id) }
    }
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if model.setlists.isEmpty && model.songLibrary.isEmpty {
                        welcome
                    } else {
                        if !model.setlists.isEmpty {
                            heading("Setlists", id: "live-all-setlists") { openSetlist(nil, .browse) }
                            catalog.frame(height: min(238, max(76, contentHeight > 0 ? contentHeight : CGFloat(model.setlists.count) * 76 + 16)))
                                .liveScreen(p)
                        }
                        heading("Songs", id: "live-all-songs") { open(.songLibrary) }
                        if songs.isEmpty {
                            Text("No songs yet.").foregroundStyle(p.muted).padding(20).frame(maxWidth: .infinity).insetPanel(p)
                        } else {
                            songCatalog.frame(height: min(208, CGFloat(songs.count) * 76 + 20)).liveScreen(p)
                        }
                        if model.setlists.isEmpty {
                            Button { openSetlist(nil, .create) } label: {
                                Label("Create a setlist", systemImage: "text.badge.plus").font(.system(size: 14)).padding(14)
                            }.buttonStyle(HardwareButtonStyle(p: p)).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }.padding(.top, 22).padding(.bottom, 16)
            }.scrollClipDisabled()
            if model.playing { SettingsPlaybackBar(model: model, p: p) }
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
            .fullScreenCover(isPresented: $recentSongOpen) { PerformanceView(model: model, fromSongLibrary: true, back: { recentSongOpen = false }) }
    }
    private func heading(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        HStack {
            SectionLabel(text: title, p: p)
            Button(action: action) { Text("All").font(.system(size: 14, weight: .medium)).padding(.horizontal, 18).frame(minHeight: 44) }
                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier(id)
        }
    }
    private var welcome: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Ready?").font(InstrumentType.display(68))
                HStack(spacing: 22) { ForEach(1...4, id: \.self) { n in Text("\(n)").font(.system(size: 18, weight: n == 1 ? .bold : .regular)).foregroundStyle(n == 1 ? p.ink : p.muted) } }
            }.frame(maxWidth: .infinity).padding(.vertical, 28).insetPanel(p)
            Text("Choose your songs. Then just play.").font(.system(size: 19, weight: .medium)).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button { openSetlist(nil, .create) } label: { Label("New setlist", systemImage: "text.badge.plus").frame(maxWidth: .infinity, minHeight: 60) }
                    .accessibilityIdentifier("live-new-setlist")
                Button { open(.songLibrary) } label: { Label("Add songs", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 60) }
                    .accessibilityIdentifier("live-all-songs")
            }.font(.system(size: 14, weight: .medium)).buttonStyle(HardwareButtonStyle(p: p))
        }.padding(.top, 26)
    }
    private var songCatalog: some View {
        CatalogList(items: songs, p: p, bookmarks: bookmarks, page: "live-songs", compactMargins: true, row: { _, song in
            Button {
                model.loadStandaloneSong(song.id)
                recentSongOpen = true
            } label: {
                HStack {
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
                    onContentHeight: { if abs(contentHeight - $0) > 0.5 { contentHeight = $0 } }, row: { _, list in
            Button { SetlistRecency.touch(list.id); openSetlist(list.id, .browse) } label: {
                HStack(spacing: 12) {
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
