import SwiftUI
import UIKit

struct RecyclerViewRepresentable<Item: Identifiable, Content: View>: UIViewRepresentable {
    let data: [Item]
    let layout: RecyclerViewLayoutManager
    let content: (Int, Item) -> Content
    let spanSizeLookup: ((Item) -> Int)?
    let onItemClick: ((Int, Item) -> Void)?
    let showsScrollIndicator: Bool
    let withAnimation: Bool
    let reverseLayout: Bool
    let pageSize: Int
    let onScroll: ((CGPoint) -> Void)?
    let onLoadMore: ((Int, Int) -> Void)?
    let verticalLayout: RecyclerViewVerticalLayout
    let keyboardDismissal: RecyclerViewKeyboardDismissal?
    let separator: RecyclerViewSeparator?
    let precomputesItemHeights: Bool
    let controller: RecyclerViewController?
    /// Receives the measured height of a wrap-content list where SwiftUI cannot ask the list for its
    /// size directly, before iOS 16. `nil` when the list answers `sizeThatFits` itself.
    var onWrapContentHeight: ((CGFloat) -> Void)?
    /// Receives the safe-area insets of the list's own window, for lists drawn under the status bar.
    var onWindowSafeAreaInsets: ((UIEdgeInsets) -> Void)?
    /// Receives how far the list can still scroll each way.
    var onScrollEdges: ((RecyclerViewScrollEdges) -> Void)?

    func makeCoordinator() -> RecyclerViewCoordinator<Item, Content> {
        RecyclerViewCoordinator()
    }

    /// Sizes a wrap-content list to its items, measured at the width SwiftUI proposes and capped at the
    /// proposed height.
    ///
    /// A `nil` height proposal, as inside a vertical `ScrollView`, leaves the list as tall as all of its
    /// items. A list that is not wrap-content falls back to the default sizing, filling the proposal.
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIRecyclerView, context: Context) -> CGSize? {
        guard verticalLayout == .wrapContent, onWrapContentHeight == nil, let adapter = context.coordinator.adapter else {
            return nil
        }

        let proposedWidth = proposal.width ?? uiView.bounds.width
        guard proposedWidth.isFinite, proposedWidth > 0 else { return nil }

        let maxHeight = proposal.height ?? .infinity
        let height = WrapContentMeasurement.height(
            of: data,
            layout: layout,
            spanSizeLookup: spanSizeLookup,
            width: proposedWidth,
            maxHeight: maxHeight,
            adapter: adapter
        )
        return CGSize(width: proposedWidth, height: height)
    }

    func makeUIView(context: Context) -> UIRecyclerView {
        let collectionView = UIRecyclerView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = verticalLayout == .matchParent ? .never : .automatic
        applyTransform(to: collectionView)
        configureScrolling(of: collectionView)

        let adapter = RecyclerViewAdapter<Item, Content>(collectionView: collectionView, content: content)
        configure(adapter)
        adapter.items = data

        let coordinator = context.coordinator
        coordinator.adapter = adapter
        coordinator.lastData = data
        coordinator.lastLayout = layout

        collectionView.collectionViewLayout = RecyclerViewLayoutFactory.makeLayout(for: layout, adapter: adapter)
        controller?.attach(to: collectionView, axis: layout.orientation)

        collectionView.onWidthChange = { [weak coordinator] _ in
            coordinator?.reportWrapContentHeight?()
        }
        coordinator.reportWrapContentHeight = makeWrapContentReporter(for: collectionView, coordinator: coordinator)
        configureWindowReporting(of: collectionView)
        configureEdgeReporting(of: collectionView)
        return collectionView
    }

    private func configureEdgeReporting(of collectionView: UIRecyclerView) {
        collectionView.scrollAxis = layout.orientation == .vertical ? .vertical : .horizontal
        guard let onScrollEdges = onScrollEdges else {
            collectionView.onScrollEdgesChange = nil
            return
        }
        collectionView.onScrollEdgesChange = { edges in
            // Reported on a later turn: this runs during layout, when SwiftUI state must not change.
            Task { @MainActor in
                onScrollEdges(edges)
            }
        }
    }

    private func configureWindowReporting(of collectionView: UIRecyclerView) {
        guard let onWindowSafeAreaInsets = onWindowSafeAreaInsets else {
            collectionView.onWindowSafeAreaInsetsChange = nil
            return
        }
        collectionView.onWindowSafeAreaInsetsChange = { insets in
            // Reported on a later turn: this runs during layout, when SwiftUI state must not change.
            Task { @MainActor in
                onWindowSafeAreaInsets(insets)
            }
        }
    }

    /// Before iOS 16 SwiftUI cannot ask a representable for its size, so the list measures itself at
    /// its laid-out width, which is the width its container proposes, and reports the height back to
    /// ``RecyclerView``, which frames the list with it.
    private func makeWrapContentReporter(
        for collectionView: UIRecyclerView,
        coordinator: RecyclerViewCoordinator<Item, Content>
    ) -> (() -> Void)? {
        guard verticalLayout == .wrapContent, let onWrapContentHeight = onWrapContentHeight else { return nil }
        let data = data
        let layout = layout
        let spanSizeLookup = spanSizeLookup

        return { [weak collectionView, weak coordinator] in
            guard let collectionView = collectionView,
                  let coordinator = coordinator,
                  let adapter = coordinator.adapter,
                  collectionView.bounds.width > 0
            else { return }

            let height = WrapContentMeasurement.height(
                of: data,
                layout: layout,
                spanSizeLookup: spanSizeLookup,
                width: collectionView.bounds.width,
                adapter: adapter
            )
            guard height != coordinator.reportedWrapContentHeight else { return }
            coordinator.reportedWrapContentHeight = height

            // Reported on a later turn: this runs during layout or a view update, when SwiftUI state
            // must not change.
            Task { @MainActor in
                onWrapContentHeight(height)
            }
        }
    }

    func updateUIView(_ collectionView: UIRecyclerView, context: Context) {
        let coordinator = context.coordinator
        controller?.attach(to: collectionView, axis: layout.orientation)
        applyTransform(to: collectionView)
        configureScrolling(of: collectionView)
        configureWindowReporting(of: collectionView)
        configureEdgeReporting(of: collectionView)

        guard let adapter = coordinator.adapter else { return }
        if configure(adapter) {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        coordinator.animatesUpdates = withAnimation
        defer {
            coordinator.reportWrapContentHeight = makeWrapContentReporter(for: collectionView, coordinator: coordinator)
            coordinator.reportWrapContentHeight?()
        }

        let layoutChanged = coordinator.lastLayout != layout
        coordinator.lastLayout = layout

        // Every update supersedes a diff still in flight for an earlier one.
        coordinator.updateVersion += 1
        coordinator.pendingData = nil
        let version = coordinator.updateVersion

        // lastData is what the collection view holds, and so the baseline a diff is measured from.
        // It moves only when items are actually handed to the collection view. A diff is applied on
        // a later turn of the main queue and may be abandoned for a newer update; had the baseline
        // moved up front, the next diff would be measured from a state the list never reached and its
        // batch update would fail UIKit's consistency check.
        let newData = data
        let oldIDs = coordinator.lastData.map(\.id)
        let newIDs = newData.map(\.id)

        if layoutChanged {
            adapter.items = newData
            coordinator.lastData = newData
            collectionView.setCollectionViewLayout(RecyclerViewLayoutFactory.makeLayout(for: layout, adapter: adapter), animated: false)
            adapter.notifyDataSetChanged()
        } else if oldIDs != newIDs {
            // Rows that keep their identity but changed are measured again from now, so a wrap-content
            // list sized before the diff is applied already sees their new heights.
            adapter.invalidateMeasurements(ofItemsChangedFrom: coordinator.lastData, to: newData)
            applyDiff(from: oldIDs, to: newIDs, newData: newData, version: version, collectionView: collectionView, coordinator: coordinator)
        } else {
            // Same identities, but the items themselves may carry new values.
            adapter.items = newData
            coordinator.lastData = newData
            Self.rebindVisibleCells(of: collectionView, adapter: adapter)
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    private func applyDiff(
        from oldIDs: [Item.ID],
        to newIDs: [Item.ID],
        newData: [Item],
        version: Int,
        collectionView: UIRecyclerView,
        coordinator: RecyclerViewCoordinator<Item, Content>
    ) {
        // Only Sendable values cross to the background queue: integer stand-ins for the identities.
        // The items stay on the main actor with the coordinator until the diff comes back.
        let tokens = ListDiff.tokens(from: oldIDs, to: newIDs)
        coordinator.pendingData = newData

        DispatchQueue.global(qos: .userInteractive).async {
            let diff = ListDiff(from: tokens.old, to: tokens.new)

            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    Self.apply(diff, version: version, collectionView: collectionView, coordinator: coordinator)
                }
            }
        }
    }

    private static func apply(
        _ diff: ListDiff,
        version: Int,
        collectionView: UIRecyclerView,
        coordinator: RecyclerViewCoordinator<Item, Content>
    ) {
        // A newer update has taken over. The baseline stays where it is, so that update's diff is
        // measured from what the collection view really holds.
        guard coordinator.updateVersion == version,
              let adapter = coordinator.adapter,
              let newData = coordinator.pendingData
        else { return }

        // The collection view takes the new items from here, so this is where the baseline moves.
        coordinator.pendingData = nil
        coordinator.lastData = newData

        guard !diff.isEmpty else {
            adapter.items = newData
            adapter.notifyDataSetChanged()
            collectionView.collectionViewLayout.invalidateLayout()
            return
        }

        let performUpdates = {
            collectionView.performBatchUpdates({
                adapter.items = newData
                // UIKit resolves a batch as a whole: deletions and move sources are read against the
                // old items, insertions and move destinations against the new ones, whatever order
                // they are issued in. ListDiff produces positions on exactly those terms.
                if !diff.deletions.isEmpty {
                    collectionView.deleteItems(at: diff.deletions)
                }
                if !diff.insertions.isEmpty {
                    collectionView.insertItems(at: diff.insertions)
                }
                for move in diff.moves {
                    collectionView.moveItem(at: move.from, to: move.to)
                }
            }, completion: { _ in
                // Rows that stayed in place or moved keep their cells, which may show stale values,
                // such as content built from an index that has changed.
                rebindVisibleCells(of: collectionView, adapter: adapter)
                collectionView.collectionViewLayout.invalidateLayout()
            })
        }

        if coordinator.animatesUpdates {
            performUpdates()
        } else {
            UIView.performWithoutAnimation(performUpdates)
        }

        // A wrap-content list was sized for these items before they reached the collection view. Rows
        // measured since then by the layout may have changed, so the list is sized once more.
        coordinator.reportWrapContentHeight?()
        collectionView.invalidateIntrinsicContentSize()
    }

    /// Hands the configuration to the adapter. Returns whether the layout has to be invalidated for
    /// it, which a change of separator needs.
    @discardableResult
    private func configure(_ adapter: RecyclerViewAdapter<Item, Content>) -> Bool {
        let separatorChanged = adapter.separator != separator
        adapter.separator = separator
        adapter.content = content
        adapter.onItemClick = onItemClick
        adapter.reverseLayout = reverseLayout
        adapter.layout = layout
        adapter.spanSizeLookup = spanSizeLookup
        adapter.pageSize = pageSize
        adapter.onScroll = onScroll
        adapter.onLoadMore = onLoadMore
        adapter.keyboardDismissal = keyboardDismissal
        adapter.precomputesItemHeights = precomputesItemHeights
        return separatorChanged
    }

    private func configureScrolling(of collectionView: UICollectionView) {
        let isVertical = layout.orientation == .vertical
        collectionView.showsVerticalScrollIndicator = isVertical && showsScrollIndicator
        collectionView.showsHorizontalScrollIndicator = !isVertical && showsScrollIndicator
        collectionView.alwaysBounceVertical = isVertical
        collectionView.alwaysBounceHorizontal = !isVertical
    }

    private func applyTransform(to collectionView: UICollectionView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        collectionView.transform = reverseLayout ? CGAffineTransform(rotationAngle: .pi) : .identity
        CATransaction.commit()
    }

    private static func rebindVisibleCells(of collectionView: UICollectionView, adapter: RecyclerViewAdapter<Item, Content>) {
        for cell in collectionView.visibleCells {
            if let viewHolder = cell as? ViewHolder<Content>,
               let indexPath = collectionView.indexPath(for: viewHolder),
               indexPath.item < adapter.items.count {
                let item = adapter.items[indexPath.item]
                viewHolder.bind(
                    adapter.content(indexPath.item, item),
                    itemID: adapter.getItemIDString(for: item, at: indexPath.item),
                    parentViewController: adapter.parentViewController
                )
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            cell.transform = adapter.reverseLayout ? CGAffineTransform(rotationAngle: .pi) : .identity
            CATransaction.commit()
        }
    }
}

@MainActor
final class RecyclerViewCoordinator<Item: Identifiable, Content: View> {
    var adapter: RecyclerViewAdapter<Item, Content>?
    /// The items the collection view holds: the baseline the next diff is measured from.
    var lastData: [Item] = []
    /// The items of the latest update, waiting for their diff to come back from the background queue.
    var pendingData: [Item]?
    /// Whether batch updates are animated.
    var animatesUpdates = true
    /// Measures a wrap-content list and reports its height, before iOS 16.
    var reportWrapContentHeight: (() -> Void)?
    /// The height last reported by ``reportWrapContentHeight``.
    var reportedWrapContentHeight: CGFloat?
    var lastLayout: RecyclerViewLayoutManager?
    /// Incremented on every update, so a diff that finishes after a newer update can tell it is stale.
    var updateVersion = 0
}
