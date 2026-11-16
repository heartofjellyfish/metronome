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

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionLabel(text: "Setlists", p: p)
                        Button { openSetlist(nil, .browse) } label: { Text("All").font(.system(size: 14, weight: .medium)).padding(.horizontal, 18).frame(minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("live-all-setlists")
                    }
                    if model.setlists.isEmpty {
                        Text("No setlists yet.").font(.subheadline).foregroundStyle(p.muted)
                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .center).insetPanel(p)
                    } else {
                        catalog.frame(height: min(252, max(76, contentHeight > 0 ? contentHeight : CGFloat(model.setlists.count) * 76 + 16)))
                    }
                    HStack(spacing: 12) {
                        tool("Song library", icon: .songLibrary, kind: .songLibrary)
                        tool("Pedal setup", icon: .pedal, kind: .pedal)
                    }
                    if let song = model.recentSongs.first {
                        SectionLabel(text: "Recent song", p: p).padding(.top, 12)
                        Button {
                            model.loadStandaloneSong(song.id)
                            recentSongOpen = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verbatim: song.name).font(.system(size: 18, weight: .semibold)).lineLimit(2)
                                    Text("\(song.rhythm.bpm) BPM · \(song.rhythm.beats)/\(song.rhythm.denominator)").font(.system(size: 13)).foregroundStyle(p.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12))
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(InsetRowButtonStyle(p: p)).insetPanel(p)
                            .accessibilityIdentifier("live-recent-song")
                    }
                }.padding(.top, 22).padding(.bottom, 16)
            }.scrollClipDisabled()
            // Keep an active session controllable while browsing, without inviting an accidental start.
            if model.playing { SettingsPlaybackBar(model: model, p: p) }
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
            .fullScreenCover(isPresented: $recentSongOpen) { PerformanceView(model: model, fromSongLibrary: true, back: { recentSongOpen = false }) }
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
        }, above: { EmptyView() }, below: { EmptyView() }).screen()
    }

    private func tool(_ title: LocalizedStringKey, icon: SettingsIllustration.Kind, kind: InstrumentPanelKind) -> some View {
        Button { open(kind) } label: {
            VStack(spacing: 6) {
                SettingsIllustration(kind: icon).frame(width: 46, height: 38)
                Text(title).font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
            }.padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .center).frame(height: 88)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 12)).accessibilityIdentifier("live-tool-\(kind.rawValue)")
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
