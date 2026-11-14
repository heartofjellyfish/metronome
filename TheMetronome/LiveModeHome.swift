import SwiftUI

/// Live starts with the musician's repertoire; opening a list never changes playback.
struct LiveModeHome: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    let openSetlist: (UUID?, LiveSetlistAction) -> Void
    @State private var bookmarks = ListBookmarks()
    @State private var contentHeight: CGFloat = 0
    @State private var preparation = false
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionLabel(text: "Recent setlists", p: p)
                        Button { openSetlist(nil, .browse) } label: { Text("All").font(.system(size: 14, weight: .medium)).padding(.horizontal, 18).frame(minHeight: 44) }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("live-all-setlists")
                    }
                    if model.setlists.isEmpty {
                        Text("No setlists yet.").font(.subheadline).foregroundStyle(p.muted)
                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .center).insetPanel(p)
                    } else {
                        catalog.frame(height: min(310, max(76, contentHeight > 0 ? contentHeight : CGFloat(recentLists.count) * 76 + 16)))
                    }
                    HStack(spacing: 12) {
                        tool("Song library", icon: .songLibrary, kind: .songLibrary)
                        Button { openSetlist(nil, .create) } label: {
                            Label("New setlist", systemImage: "plus").font(.system(size: 15, weight: .medium))
                                .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 48)
                        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("live-new-setlist")
                    }
                    SectionLabel(text: "Performance setup", p: p).padding(.top, 18)
                    tool("Pedal", icon: .pedal, kind: .pedal)
                    Button { preparation.toggle() } label: {
                        HStack {
                            Label("Pre-show checklist", systemImage: "checklist").font(.system(size: 14))
                            Spacer()
                            Image(systemName: preparation ? "chevron.up" : "chevron.down").font(.system(size: 11))
                        }.padding(.horizontal, 14).frame(minHeight: 48).contentShape(Rectangle())
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("live-preparation")
                        .accessibilityValue(L10n.text(preparation ? "Collapse" : "Expand"))
                    if preparation { PerformancePreparation(p: p) }
                }.padding(.top, 22).padding(.bottom, 16)
            }.scrollClipDisabled()
            // Keep an active session controllable while browsing, without inviting an accidental start.
            if model.playing { SettingsPlaybackBar(model: model, p: p) }
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
    }

    private var recentLists: [SongSetlist] {
        let dates = SetlistRecency.dates
        return Array(model.setlists.enumerated().sorted { a, b in
            let x = dates[a.element.id.uuidString, default: 0], y = dates[b.element.id.uuidString, default: 0]
            return x == y ? a.offset < b.offset : x > y
        }.prefix(3).map(\.element))
    }

    private var catalog: some View {
        CatalogList(items: recentLists, p: p, bookmarks: bookmarks, page: "live-home", compactMargins: true, swipeActions: { list in
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
                }.frame(maxWidth: .infinity, minHeight: 58).padding(.horizontal, 14).padding(.vertical, 5).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("live-setlist-\(list.id)")
        }, above: { EmptyView() }, below: { EmptyView() }).screen()
    }

    private func tool(_ title: LocalizedStringKey, icon: SettingsIllustration.Kind, kind: InstrumentPanelKind) -> some View {
        Button { open(kind) } label: {
            HStack(spacing: 8) {
                SettingsIllustration(kind: icon).frame(width: 38, height: 32)
                Text(title).font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
            }.padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading).frame(height: 48)
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
