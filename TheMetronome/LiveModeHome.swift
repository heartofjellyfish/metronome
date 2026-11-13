import SwiftUI

/// Live starts with the musician's repertoire; opening a list never changes playback.
struct LiveModeHome: View {
    @ObservedObject var model: MetronomeModel
    let open: (InstrumentPanelKind) -> Void
    let openSetlist: (UUID?, Bool) -> Void
    @State private var bookmarks = ListBookmarks()
    @State private var contentHeight: CGFloat = 0
    @State private var preparation = false
    var p: InstrumentPalette { InstrumentPalette(dark: model.dark) }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(text: "Setlists", p: p)
                    if model.setlists.isEmpty {
                        Text("No setlists yet.").font(.subheadline).foregroundStyle(p.muted)
                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .center).insetPanel(p)
                    } else {
                        catalog.frame(height: min(280, max(76, contentHeight > 0 ? contentHeight : CGFloat(model.setlists.count) * 76 + 16)))
                    }
                    HStack {
                        Spacer()
                        Button { openSetlist(nil, true) } label: {
                            Label("New setlist", systemImage: "plus").font(.system(size: 15, weight: .medium))
                                .padding(.horizontal, 16).frame(minHeight: 44)
                        }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("live-new-setlist")
                    }
                    SectionLabel(text: "Live", p: p).padding(.top, 18)
                    HStack(spacing: 12) {
                        tool("Song library", icon: .songLibrary, kind: .songLibrary)
                        tool("Pedal", icon: .pedal, kind: .pedal)
                    }
                    Button { preparation.toggle() } label: {
                        HStack {
                            Text("Before performing").font(.system(size: 14))
                            Spacer()
                            Image(systemName: preparation ? "chevron.up" : "chevron.down").font(.system(size: 11))
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("live-preparation")
                        .accessibilityValue(L10n.text(preparation ? "Collapse" : "Expand"))
                    if preparation { PerformancePreparation(p: p) }
                }.padding(.top, 22).padding(.bottom, 16)
            }
            // Keep an active session controllable while browsing, without inviting an accidental start.
            if model.playing { SettingsPlaybackBar(model: model, p: p) }
        }.padding(.horizontal, 26).padding(.bottom, 18).foregroundStyle(p.ink)
    }

    private var catalog: some View {
        CatalogList(items: model.setlists, p: p, bookmarks: bookmarks, page: "live-home", compactMargins: true,
                    onContentHeight: { if abs(contentHeight - $0) > 0.5 { contentHeight = $0 } }, row: { _, list in
            Button { openSetlist(list.id, false) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: list.name).font(.system(size: 17, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Text(L10n.format(list.songs.count == 1 ? "%d song" : "%d songs", list.songs.count))
                            .font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 12))
                }.frame(maxWidth: .infinity, minHeight: 58).padding(.horizontal, 14).padding(.vertical, 5).contentShape(Rectangle())
            }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("live-setlist-\(list.id)")
        }, above: { EmptyView() }, below: { EmptyView() }).screen()
    }

    private func tool(_ title: LocalizedStringKey, icon: SettingsIllustration.Kind, kind: InstrumentPanelKind) -> some View {
        Button { open(kind) } label: {
            VStack(spacing: 8) {
                SettingsIllustration(kind: icon).frame(width: 78, height: 58)
                Text(title).font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
            }.frame(maxWidth: .infinity).frame(height: 108)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 12)).accessibilityIdentifier("live-tool-\(kind.rawValue)")
    }
}
