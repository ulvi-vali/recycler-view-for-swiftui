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
    let dismissesKeyboardOnScroll: Bool
    let precomputesItemHeights: Bool
    let controller: RecyclerViewController?

    func makeCoordinator() -> RecyclerViewCoordinator<Item, Content> {
        RecyclerViewCoordinator()
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
        return collectionView
    }

    func updateUIView(_ collectionView: UIRecyclerView, context: Context) {
        let coordinator = context.coordinator
        controller?.attach(to: collectionView, axis: layout.orientation)
        applyTransform(to: collectionView)
        configureScrolling(of: collectionView)

        guard let adapter = coordinator.adapter else { return }
        configure(adapter)

        let layoutChanged = coordinator.lastLayout != layout
        coordinator.lastLayout = layout

        // Every update supersedes a diff still in flight for an earlier one.
        coordinator.updateVersion += 1
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
        let withAnimation = self.withAnimation

        DispatchQueue.global(qos: .userInteractive).async {
            let diff = ListDiff(from: oldIDs, to: newIDs)

            DispatchQueue.main.async {
                // A newer update has taken over. The baseline stays where it is, so that update's
                // diff is measured from what the collection view really holds.
                guard coordinator.updateVersion == version, let adapter = coordinator.adapter else { return }

                // The collection view takes the new items from here, so this is where the baseline moves.
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
                        if !diff.deletions.isEmpty {
                            collectionView.deleteItems(at: diff.deletions)
                        }
                        if !diff.insertions.isEmpty {
                            collectionView.insertItems(at: diff.insertions)
                        }
                    }, completion: { _ in
                        // Rows that stayed in place keep their cells, which may show stale values.
                        Self.rebindVisibleCells(of: collectionView, adapter: adapter)
                        collectionView.collectionViewLayout.invalidateLayout()
                    })
                }

                if withAnimation {
                    performUpdates()
                } else {
                    UIView.performWithoutAnimation(performUpdates)
                }
            }
        }
    }

    private func configure(_ adapter: RecyclerViewAdapter<Item, Content>) {
        adapter.content = content
        adapter.onItemClick = onItemClick
        adapter.reverseLayout = reverseLayout
        adapter.layout = layout
        adapter.spanSizeLookup = spanSizeLookup
        adapter.pageSize = pageSize
        adapter.onScroll = onScroll
        adapter.onLoadMore = onLoadMore
        adapter.dismissesKeyboardOnScroll = dismissesKeyboardOnScroll
        adapter.precomputesItemHeights = precomputesItemHeights
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

final class RecyclerViewCoordinator<Item: Identifiable, Content: View> {
    var adapter: RecyclerViewAdapter<Item, Content>?
    /// The items the collection view holds: the baseline the next diff is measured from.
    var lastData: [Item] = []
    var lastLayout: RecyclerViewLayoutManager?
    /// Incremented on every update, so a diff that finishes after a newer update can tell it is stale.
    var updateVersion = 0
}
