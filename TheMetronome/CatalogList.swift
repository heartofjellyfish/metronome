import SwiftUI
import UIKit

/// Per-panel history. Identity survives sorting; the index is a fallback for a removed row.
final class ListBookmarks {
    struct Anchor {
        let id: UUID
        let index: Int
        let inset: CGFloat
    }
    var pages: [String: Anchor] = [:]
    var visibleRows: [String: [UUID: Anchor]] = [:]

    func prefer(_ id: UUID, on page: String) {
        if let anchor = visibleRows[page]?[id] { pages[page] = anchor }
    }
    func clear(_ page: String) {
        pages.removeValue(forKey: page)
        visibleRows.removeValue(forKey: page)
    }
}

private struct CatalogWellSurface: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Color.clear.insetPanel(InstrumentPalette(dark: scheme == .dark), radius: 16)
    }
}

private final class CatalogWell: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        let surface = UIHostingConfiguration { CatalogWellSurface() }.margins(.all, 0).makeContentView()
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }
    required init?(coder: NSCoder) { fatalError("CatalogWell requires programmatic initialization") }
}

/// One native scroll surface owns the introductory controls, reorderable rows and footer.
struct CatalogList<Item: Identifiable, Row: View, Above: View, Below: View>: UIViewRepresentable where Item.ID == UUID {
    let items: [Item]
    let p: InstrumentPalette
    let bookmarks: ListBookmarks
    let page: String
    var move: ((UUID, Int) -> Void)? = nil
    var onRowsHeight: ((CGFloat) -> Void)? = nil
    var onHeaderScrolled: ((Bool) -> Void)? = nil
    @ViewBuilder var row: (Int, Item) -> Row
    @ViewBuilder var above: () -> Above
    @ViewBuilder var below: () -> Below

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewCompositionalLayout { section, _ in
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(section == 1 ? 76 : 24))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let part = NSCollectionLayoutSection(group: group)
            part.contentInsets = .init(top: 0, leading: 20, bottom: 0, trailing: 20)
            if section == 1 {
                let well = NSCollectionLayoutDecorationItem.background(elementKind: "well")
                well.contentInsets = part.contentInsets
                part.decorationItems = [well]
            }
            return part
        }
        layout.register(CatalogWell.self, forDecorationViewOfKind: "well")
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.keyboardDismissMode = .interactive
        view.contentInset = .init(top: 12, left: 0, bottom: 20, right: 0)
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "item")
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.drag(_:)))
        gesture.minimumPressDuration = 0.18
        gesture.delegate = context.coordinator
        view.addGestureRecognizer(gesture)
        return view
    }
    func updateUIView(_ view: UICollectionView, context: Context) {
        let c = context.coordinator
        c.parent = self
        // UIKit may reuse a hosting cell while SwiftUI is applying this update.
        // Reconcile once on the next main-loop turn, with the latest query and rows.
        guard !c.updateScheduled else { return }
        c.updateScheduled = true
        DispatchQueue.main.async { [weak view] in
            c.updateScheduled = false
            guard let view, !c.moving else { return }
            let newItems = c.parent.items
            let changed = !newItems.elementsEqual(c.items, by: { $0.id == $1.id })
            c.items = newItems
            if changed { view.reloadData() }
            view.layoutIfNeeded()
            for cell in view.visibleCells {
                if let path = view.indexPath(for: cell) { c.configure(cell, path) }
            }
            if view.window != nil { c.finishLayout(view) }
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate {
        var parent: CatalogList
        var items: [Item]
        var updateScheduled = false
        var moving = false
        private var grabOffset: CGFloat = 0
        private var restored = false
        private var touching = false
        private var compact: Bool?
        private var rowsHeight: CGFloat = -1
        init(_ parent: CatalogList) { self.parent = parent; items = parent.items }

        func numberOfSections(in view: UICollectionView) -> Int { 3 }
        func collectionView(_ view: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            section == 1 ? items.count : 1
        }
        func collectionView(_ view: UICollectionView, cellForItemAt path: IndexPath) -> UICollectionViewCell {
            let cell = view.dequeueReusableCell(withReuseIdentifier: "item", for: path)
            configure(cell, path)
            return cell
        }
        func configure(_ cell: UICollectionViewCell, _ path: IndexPath) {
            let p = parent.p
            switch path.section {
            case 0:
                cell.contentConfiguration = UIHostingConfiguration {
                    VStack(alignment: .leading, spacing: 0) { parent.above() }.frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(p.ink).padding(.bottom, 10)
                }.margins(.all, 0)
            case 2:
                cell.contentConfiguration = UIHostingConfiguration {
                    VStack(spacing: 0) { parent.below() }.foregroundStyle(p.ink).padding(.top, 16)
                }.margins(.all, 0)
            default:
                guard items.indices.contains(path.item) else { return }
                let last = path.item == items.count - 1
                let item = items[path.item]
                let row = parent.row(path.item, item).id(item.id)
                cell.contentConfiguration = UIHostingConfiguration {
                    row.foregroundStyle(p.ink)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .bottom) {
                            if !last { Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5).padding(.horizontal, 14) }
                        }
                }.margins(.all, 0)
            }
        }
        func finishLayout(_ view: UICollectionView) {
            view.layoutIfNeeded()
            guard view.bounds.height > 0 else { return }
            if !restored {
                restored = true
                if let a = parent.bookmarks.pages[parent.page], !items.isEmpty {
                    let i = items.firstIndex { $0.id == a.id } ?? min(a.index, items.count - 1)
                    let path = IndexPath(item: i, section: 1)
                    view.scrollToItem(at: path, at: .top, animated: false)
                    view.layoutIfNeeded()
                    if let frame = view.layoutAttributesForItem(at: path)?.frame {
                        let top = -view.adjustedContentInset.top
                        let end = max(top, view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom)
                        view.contentOffset.y = min(end, max(top, frame.minY - a.inset))
                    }
                }
            }
            if let footer = view.layoutAttributesForItem(at: IndexPath(item: 0, section: 2)),
               let head = view.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)) {
                let height = footer.frame.minY - head.frame.maxY
                if abs(height - rowsHeight) > 1 { rowsHeight = height; parent.onRowsHeight?(height) }
            }
            captureVisibleRows(view)
            updateTitle(view)
        }
        private func captureVisibleRows(_ view: UICollectionView) {
            var visible: [UUID: ListBookmarks.Anchor] = [:]
            for path in view.indexPathsForVisibleItems where path.section == 1 && items.indices.contains(path.item) {
                if let frame = view.layoutAttributesForItem(at: path)?.frame {
                    let id = items[path.item].id
                    visible[id] = .init(id: id, index: path.item, inset: frame.minY - view.contentOffset.y)
                }
            }
            parent.bookmarks.visibleRows[parent.page] = visible
        }
        private func updateTitle(_ view: UICollectionView) {
            guard let callback = parent.onHeaderScrolled,
                  let header = view.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)) else { return }
            let hidden = view.contentOffset.y >= header.frame.maxY
            if compact != hidden { compact = hidden; callback(hidden) }
        }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { touching = true }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard restored, let view = scrollView as? UICollectionView else { return }
            updateTitle(view)
            guard touching else { return }
            captureVisibleRows(view)
            if view.contentOffset.y <= -view.adjustedContentInset.top + 1 {
                parent.bookmarks.clear(parent.page)
            } else if let path = view.indexPathsForVisibleItems.filter({ $0.section == 1 }).min(),
                      items.indices.contains(path.item), let frame = view.layoutAttributesForItem(at: path)?.frame {
                parent.bookmarks.pages[parent.page] = .init(id: items[path.item].id, index: path.item, inset: frame.minY - view.contentOffset.y)
            }
        }
        func collectionView(_ view: UICollectionView, canMoveItemAt path: IndexPath) -> Bool { path.section == 1 && parent.move != nil }
        func collectionView(_ view: UICollectionView, targetIndexPathForMoveFromItemAt source: IndexPath, toProposedIndexPath proposed: IndexPath) -> IndexPath {
            if proposed.section == 1 { return proposed }
            return IndexPath(item: proposed.section == 0 ? 0 : max(0, items.count - 1), section: 1)
        }
        func collectionView(_ view: UICollectionView, moveItemAt source: IndexPath, to dest: IndexPath) {
            guard source.section == 1, dest.section == 1, items.indices.contains(dest.item) else { return }
            let item = items.remove(at: source.item)
            items.insert(item, at: dest.item)
            parent.move?(item.id, dest.item)
        }
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard parent.move != nil, items.count > 1, let view = recognizer.view as? UICollectionView else { return false }
            let point = recognizer.location(in: view)
            guard let path = view.indexPathForItem(at: point), path.section == 1,
                  let frame = view.layoutAttributesForItem(at: path)?.frame else { return false }
            return point.x - frame.minX <= 48
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
            case .changed where moving: view.updateInteractiveMovementTargetPosition(.init(x: view.bounds.midX, y: point.y + grabOffset))
            case .ended where moving: view.endInteractiveMovement(); moving = false
            case .cancelled, .failed: view.cancelInteractiveMovement(); moving = false
            default: break
            }
        }
    }
}
