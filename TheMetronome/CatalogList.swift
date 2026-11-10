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

private final class CatalogCell: UICollectionViewCell {
    var configuredRevision = -1
    var swipeID: UUID?
    var actionsView: UIView?
    private let swipeMask = CAGradientLayer()
    private var swipeHighlight: UIView?
    var swipeHighlightColor: UIColor = .clear
    private(set) var rowView: (UIView & UIContentView)?

    func setRow(_ configuration: UIContentConfiguration) {
        if let rowView, rowView.supports(configuration) {
            rowView.configuration = configuration
            rowView.invalidateIntrinsicContentSize()
        } else {
            rowView?.removeFromSuperview()
            let row = configuration.makeContentView()
            row.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                row.topAnchor.constraint(equalTo: contentView.topAnchor),
                row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            rowView = row
        }
    }

    // Hosted content lives in our own subview so swipe can translate it separately.
    // Explicit fitting keeps multiline titles from inheriting the old cell height.
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let result = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        let target = CGSize(width: layoutAttributes.size.width, height: UIView.layoutFittingCompressedSize.height)
        let fit = contentView.systemLayoutSizeFitting(target, withHorizontalFittingPriority: .required,
                                                     verticalFittingPriority: .fittingSizeLevel)
        result.size.height = ceil(fit.height)
        return result
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if swipeID != nil {
            updateSwipeMask()
            swipeHighlight?.frame = contentView.bounds.insetBy(dx: 12, dy: 0)
        }
    }

    private func updateSwipeMask() {
        let viewport = contentView.bounds.insetBy(dx: 12, dy: 0)
        let fade = min(0.1, 2 / max(1, viewport.width))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        swipeMask.frame = viewport
        swipeMask.startPoint = CGPoint(x: 0, y: 0.5)
        swipeMask.endPoint = CGPoint(x: 1, y: 0.5)
        swipeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        swipeMask.locations = [0, NSNumber(value: fade), NSNumber(value: 1 - fade), 1]
        contentView.layer.mask = swipeMask
        CATransaction.commit()
    }

    func setSwipeOffset(_ offset: CGFloat, width: CGFloat) {
        updateSwipeMask()
        if swipeHighlight == nil {
            let highlight = UIView()
            highlight.isUserInteractionEnabled = false
            highlight.accessibilityElementsHidden = true
            contentView.insertSubview(highlight, at: 0)
            swipeHighlight = highlight
        }
        // One subtle, stationary band connects the shifted song with its revealed actions.
        // It stays inside the same inset mask so the screen's bezel and shadow remain intact.
        swipeHighlight?.backgroundColor = swipeHighlightColor
        swipeHighlight?.frame = contentView.bounds.insetBy(dx: 12, dy: 0)
        swipeHighlight?.alpha = min(1, abs(offset) / max(width, 1))
        rowView?.transform = CGAffineTransform(translationX: offset, y: 0)
        // Reveal only the trailing strip. The transparent row preserves the shared inset shadow.
        actionsView?.frame = CGRect(x: bounds.width + offset, y: (bounds.height - 60) / 2,
                                    width: -offset, height: 60)
        actionsView?.subviews.first?.frame = CGRect(x: -offset - width, y: 0, width: width, height: 60)
    }

    func closeSwipe() {
        contentView.layer.mask = nil
        swipeHighlight?.removeFromSuperview()
        swipeHighlight = nil
        rowView?.layer.removeAllAnimations()
        rowView?.transform = .identity
        rowView?.isUserInteractionEnabled = true
        actionsView?.removeFromSuperview()
        actionsView = nil
        swipeID = nil
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        closeSwipe()
    }
}

struct CatalogRowAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    var destructive = false
    let perform: () -> Void
}

/// Shared physical key for actions inside inset catalog screens.
private struct CatalogRoundKeySurface: View {
    let p: InstrumentPalette
    let pressed: Bool
    var body: some View {
        HardwareKeySurface(p: p, radius: 19, pressed: pressed).frame(width: 38, height: 38)
    }
}

struct CatalogIconButtonStyle: ButtonStyle {
    let p: InstrumentPalette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .regular))
            .frame(width: 38, height: 38)
            .background { CatalogRoundKeySurface(p: p, pressed: configuration.isPressed) }
            .offset(y: configuration.isPressed ? 1 : 0)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct CatalogRowActionButton: View {
    let action: CatalogRowAction
    let p: InstrumentPalette
    var body: some View {
        Button(action: action.perform) {
            Image(systemName: action.icon)
                .foregroundStyle(action.destructive ? (p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C)) : p.ink)
        }.buttonStyle(CatalogIconButtonStyle(p: p))
            .accessibilityLabel(Text(verbatim: L10n.text(action.title)))
            .accessibilityIdentifier(action.id)
    }
}

private struct CatalogSwipeKey: View {
    let action: CatalogRowAction
    let p: InstrumentPalette
    var body: some View {
        Button(action: action.perform) {
            VStack(alignment: .center, spacing: 3) {
                Image(systemName: action.icon).font(.system(size: 16, weight: .regular)).frame(width: 38, height: 38)
                Text(L10n.text(action.title)).font(.caption2).lineLimit(1).multilineTextAlignment(.center)
            }.foregroundStyle(action.destructive ? (p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C)) : p.ink)
                .frame(width: 56)
        }.buttonStyle(CatalogSwipeKeyStyle(p: p)).accessibilityIdentifier("swipe-" + action.id)
    }
}

private struct CatalogSwipeKeyStyle: ButtonStyle {
    let p: InstrumentPalette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(alignment: .top) {
                CatalogRoundKeySurface(p: p, pressed: configuration.isPressed)
            }
            .offset(y: configuration.isPressed ? 1 : 0)
            .frame(height: 60, alignment: .center)
            .contentShape(Rectangle())
    }
}

/// One native scroll surface owns the introductory controls, reorderable rows and footer.
struct CatalogList<Item: Identifiable, Row: View, Above: View, Below: View>: UIViewRepresentable where Item.ID == UUID {
    let items: [Item]
    let p: InstrumentPalette
    let bookmarks: ListBookmarks
    let page: String
    var compactMargins = false
    var move: ((UUID, Int) -> Void)? = nil
    var swipeActions: ((Item) -> [CatalogRowAction])? = nil
    var onContentHeight: ((CGFloat) -> Void)? = nil
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
            return part
        }
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.selfSizingInvalidation = .enabledIncludingConstraints
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.keyboardDismissMode = .interactive
        view.contentInset = .init(top: compactMargins ? 8 : 12, left: 0, bottom: compactMargins ? 8 : 20, right: 0)
        view.register(CatalogCell.self, forCellWithReuseIdentifier: "item")
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.drag(_:)))
        gesture.minimumPressDuration = 0
        gesture.delegate = context.coordinator
        view.addGestureRecognizer(gesture)
        view.panGestureRecognizer.require(toFail: gesture)
        let swipe = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipe(_:)))
        swipe.delegate = context.coordinator
        view.addGestureRecognizer(swipe)
        view.panGestureRecognizer.require(toFail: swipe)
        let dismiss = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dismissSwipe))
        dismiss.delegate = context.coordinator
        view.addGestureRecognizer(dismiss)
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
            c.revision += 1
            if changed { c.dismissSwipe(); view.reloadData() }
            view.layoutIfNeeded()
            for cell in view.visibleCells {
                if let path = view.indexPath(for: cell) { c.configure(cell, path) }
            }
            // A hosting view can grow while the collection still caches its old item height.
            // Reflow only when fitting size changes; do not reload the cell or lose text focus.
            let resized = view.visibleCells.contains { cell in
                guard let path = view.indexPath(for: cell),
                      let attributes = view.layoutAttributesForItem(at: path) else { return false }
                let fit = cell.contentView.systemLayoutSizeFitting(
                    CGSize(width: attributes.size.width, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
                return abs(ceil(fit.height) - attributes.size.height) > 0.5
            }
            if resized {
                view.collectionViewLayout.invalidateLayout()
                view.performBatchUpdates(nil)
            }
            if view.window != nil { c.finishLayout(view) }
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate {
        var parent: CatalogList
        var items: [Item]
        var revision = 0
        var updateScheduled = false
        var moving = false
        private weak var swipedCell: CatalogCell?
        private var swipeOrigin: CGFloat = 0
        private var swipeWidth: CGFloat = 0

        private var grabOffset: CGFloat = 0
        private var restored = false
        private var touching = false
        private var compact: Bool?
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
        func collectionView(_ view: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt path: IndexPath) {
            // A prefetched cell can sit off screen through a browse/edit transition.
            if (cell as? CatalogCell)?.configuredRevision != revision { configure(cell, path) }
        }
        func configure(_ candidate: UICollectionViewCell, _ path: IndexPath) {
            guard let cell = candidate as? CatalogCell else { return }
            cell.configuredRevision = revision
            cell.swipeHighlightColor = UIColor(parent.p.ink).withAlphaComponent(parent.p.dark ? 0.07 : 0.055)
            if cell.swipeID != nil {
                if path.section == 1, items.indices.contains(path.item),
                   let actions = parent.swipeActions?(items[path.item]), !actions.isEmpty { return }
                dismissSwipe()
            }
            let p = parent.p
            switch path.section {
            case 0:
                cell.setRow(UIHostingConfiguration {
                    VStack(alignment: .leading, spacing: 0) { parent.above() }.frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(p.ink).padding(.horizontal, 14).padding(.bottom, parent.compactMargins ? 4 : 10)
                }.margins(.all, 0))
            case 2:
                cell.setRow(UIHostingConfiguration {
                    VStack(spacing: 0) { parent.below() }.foregroundStyle(p.ink).padding(.horizontal, 14).padding(.top, parent.compactMargins ? 4 : 16)
                }.margins(.all, 0))
            default:
                guard items.indices.contains(path.item) else { return }
                let last = path.item == items.count - 1
                let item = items[path.item]
                let row = parent.row(path.item, item).id(item.id)
                cell.setRow(UIHostingConfiguration {
                    row.foregroundStyle(p.ink)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .bottom) {
                            if !last { Rectangle().fill(p.edge.opacity(0.4)).frame(height: 0.5).padding(.horizontal, 14) }
                        }
                }.margins(.all, 0))
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
            parent.onContentHeight?(view.contentSize.height + view.adjustedContentInset.top + view.adjustedContentInset.bottom)
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
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { dismissSwipe(); touching = true }
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
        @objc func dismissSwipe() {
            swipedCell?.closeSwipe()
            swipedCell = nil
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer,
                  let view = recognizer.view as? UICollectionView,
                  pan !== view.panGestureRecognizer else { return true }
            let speed = pan.velocity(in: view)
            guard abs(speed.x) > abs(speed.y), abs(speed.x) > 0,
                  let path = view.indexPathForItem(at: pan.location(in: view)),
                  path.section == 1, items.indices.contains(path.item),
                  let actions = parent.swipeActions?(items[path.item]), !actions.isEmpty else { return false }
            return speed.x < 0 || view.cellForItem(at: path) === swipedCell
        }

        @objc func swipe(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? UICollectionView else { return }
            switch gesture.state {
            case .began:
                guard let path = view.indexPathForItem(at: gesture.location(in: view)),
                      items.indices.contains(path.item),
                      let cell = view.cellForItem(at: path) as? CatalogCell,
                      let actions = parent.swipeActions?(items[path.item]), !actions.isEmpty else { return }
                if swipedCell !== cell { dismissSwipe() }
                swipedCell = cell
                swipeWidth = CGFloat(actions.count) * 56 + 40
                swipeOrigin = cell.rowView?.transform.tx ?? 0
                if cell.actionsView == nil {
                    let config = UIHostingConfiguration {
                        HStack(spacing: 0) {
                            ForEach(actions) { action in
                                CatalogSwipeKey(action: CatalogRowAction(id: action.id, title: action.title,
                                    icon: action.icon, destructive: action.destructive, perform: { [weak self] in
                                        self?.dismissSwipe()
                                        action.perform()
                                    }), p: self.parent.p)
                            }
                        }.padding(.horizontal, 20)
                    }.margins(.all, 0)
                    let buttons = config.makeContentView()
                    buttons.backgroundColor = .clear
                    let reveal = UIView()
                    reveal.clipsToBounds = true
                    reveal.addSubview(buttons)
                    cell.contentView.insertSubview(reveal, at: 0)
                    cell.actionsView = reveal
                    cell.swipeID = items[path.item].id
                    cell.clipsToBounds = true
                    cell.setSwipeOffset(swipeOrigin, width: swipeWidth)
                }
                cell.rowView?.isUserInteractionEnabled = false
            case .changed:
                guard let cell = swipedCell else { return }
                let offset = max(-swipeWidth, min(0, swipeOrigin + gesture.translation(in: view).x))
                cell.setSwipeOffset(offset, width: swipeWidth)
            case .ended, .cancelled, .failed:
                guard let cell = swipedCell else { return }
                let velocity = gesture.velocity(in: view).x
                let open = gesture.state == .ended &&
                    (velocity < -350 || (velocity < 350 && (cell.rowView?.transform.tx ?? 0) < -swipeWidth * 0.45))
                let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.18
                UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                    cell.setSwipeOffset(open ? -self.swipeWidth : 0, width: self.swipeWidth)
                } completion: { _ in
                    if !open && self.swipedCell === cell { self.dismissSwipe() }
                }
            default: break
            }
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = recognizer.view as? UICollectionView else { return false }
            if recognizer is UITapGestureRecognizer {
                guard let cell = swipedCell else { return false }
                return cell.actionsView?.point(inside: touch.location(in: cell.actionsView), with: nil) != true
            }
            if recognizer is UIPanGestureRecognizer { return parent.swipeActions != nil }
            guard parent.move != nil, items.count > 1 else { return false }
            let point = touch.location(in: view)
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

extension CatalogList {
    /// The bezel belongs to the viewport. Scrolling moves its contents only.
    func screen() -> some View {
        clipShape(RoundedRectangle(cornerRadius: 16)).insetPanel(p, radius: 16)
    }
}
