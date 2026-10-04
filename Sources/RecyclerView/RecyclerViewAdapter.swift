import SwiftUI
import UIKit

/// The data source and delegate that shows a list of items as SwiftUI views in a `UICollectionView`.
///
/// ``RecyclerView`` creates and manages an adapter. Create one yourself only to show SwiftUI rows in
/// a collection view built in UIKit: the adapter registers ``ViewHolder`` and makes itself the
/// collection view's data source and delegate.
@MainActor
public class RecyclerViewAdapter<Item: Identifiable, Content: View>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    /// Whether cells are rotated to counter a collection view flipped for a reversed layout.
    public var reverseLayout = false
    /// Builds the view for an item from its index and the item.
    public var content: (Int, Item) -> Content
    /// Called when an item is tapped, with its index and the item.
    public var onItemClick: ((Int, Item) -> Void)?
    /// Called when the next page should load, with the page index and the current item count.
    public var onLoadMore: ((Int, Int) -> Void)?
    /// The arrangement the collection view's layout was built for.
    public var layout: RecyclerViewLayoutManager = .linear(orientation: .vertical, spacing: 0)
    /// How many columns each item spans in a vertical grid.
    public var spanSizeLookup: ((Item) -> Int)?
    /// The number of items in a full page. Pagination stops after a page comes back shorter.
    public var pageSize = RecyclerViewDefaults.pageSize
    /// Called with the content offset whenever the collection view scrolls.
    public var onScroll: ((CGPoint) -> Void)?
    /// Which text input dragging the collection view ends, or `nil` to leave the keyboard alone.
    public var keyboardDismissal: RecyclerViewKeyboardDismissal?

    /// Whether dragging the collection view dismisses the keyboard of text input inside it.
    ///
    /// Setting `true` sets ``keyboardDismissal`` to ``RecyclerViewKeyboardDismissal/list``.
    public var dismissesKeyboardOnScroll: Bool {
        get { keyboardDismissal != nil }
        set { keyboardDismissal = newValue ? .list : nil }
    }
    /// Whether a vertical linear layout measures its rows up front with ``measuredHeight(for:at:width:)``.
    public var precomputesItemHeights = true
    /// The line drawn between rows of a linear layout, or `nil` for none.
    ///
    /// Separators are placed by the layout ``RecyclerView`` builds; a collection view with a layout of
    /// your own draws none. After changing it, invalidate the collection view's layout.
    public var separator: RecyclerViewSeparator? {
        didSet {
            if separator != oldValue {
                refreshVisibleSeparators()
            }
        }
    }

    /// The items being displayed.
    ///
    /// Assigning items does not update the collection view. Call ``notifyDataSetChanged()``, or one
    /// of the granular `notify` methods, afterwards.
    ///
    /// Assigning items drops the cached measurements of items that kept their `id` but changed, so
    /// their rows are measured again. When `Item` is `Equatable`, exactly the items that differ from
    /// the old item with the same `id` are measured again. Otherwise every item shown on screen is,
    /// since those are the rows rebound with the new values.
    public var items: [Item] = [] {
        didSet {
            if items.count > previousItemCount {
                loadMoreTriggered = false
            }
            previousItemCount = items.count
            invalidateMeasurements(ofItemsChangedFrom: oldValue, to: items)
        }
    }

    /// The collection view the adapter serves.
    public weak var collectionView: UICollectionView?
    /// The view controller that hosting controllers are added to as children before iOS 16. Found
    /// through the responder chain when not set.
    public weak var parentViewController: UIViewController?

    private var previousItemCount = 0
    private var loadMoreTriggered = false
    private var measurements = RowMeasurementCache()

    /// Creates an adapter that builds each row from its index and item, and attaches it to
    /// `collectionView`.
    public init(collectionView: UICollectionView, content: @escaping (Int, Item) -> Content) {
        self.collectionView = collectionView
        self.content = content
        super.init()

        collectionView.register(ViewHolder<Content>.self, forCellWithReuseIdentifier: ViewHolder<Content>.reuseIdentifier)
        collectionView.register(
            SeparatorView.self,
            forSupplementaryViewOfKind: RecyclerViewSeparator.elementKind,
            withReuseIdentifier: SeparatorView.reuseIdentifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    /// Creates an adapter that builds each row from its item, and attaches it to `collectionView`.
    public convenience init(collectionView: UICollectionView, content: @escaping (Item) -> Content) {
        self.init(collectionView: collectionView, content: { _, item in content(item) })
    }

    /// A string identifying `item`, used to key cached row heights and passed to its cell.
    ///
    /// Items without an identity, such as `nil` placeholders in an array of optionals, are identified
    /// by their index instead.
    public func getItemIDString(for item: Item, at index: Int) -> String {
        let idString = String(describing: item.id)
        if idString == "nil" || idString.isEmpty || idString == "Optional(nil)" {
            return "placeholder_\(index)"
        }
        return idString
    }

    /// Measures the row for `item` at `width`, caching the result per item identity and width.
    ///
    /// The vertical linear layout gives these heights to the collection view as estimates. With one
    /// shared estimate, every cell is placed at the estimate and then moved once SwiftUI has sized
    /// it, shifting the rows below; when row heights vary widely those corrections show as rows
    /// sliding while the list scrolls. A close estimate leaves nothing to correct.
    ///
    /// Rows are measured the way their cells size themselves, so the estimate matches the final height.
    /// Each measurement costs one hosting view and is made once per item identity and width, until the
    /// item changes; see ``items``.
    public func measuredHeight(for item: Item, at index: Int, width: CGFloat) -> CGFloat {
        let id = getItemIDString(for: item, at: index)
        if let cached = measurements.height(for: id, width: width) {
            return cached
        }

        let height = max(1, ceil(SwiftUIMeasurement.fittingHeight(of: content(index, item), width: width)))
        measurements.setHeight(height, for: id, width: width)
        return height
    }

    /// Measures the ideal size of the row for `item`, caching the result per item identity.
    ///
    /// Items in horizontal layouts choose their own width, so a wrap-content horizontal list is as
    /// tall as the tallest ideal height among its items.
    func measuredIdealSize(for item: Item, at index: Int) -> CGSize {
        let id = getItemIDString(for: item, at: index)
        if let cached = measurements.idealSize(for: id) {
            return cached
        }

        let size = SwiftUIMeasurement.idealSize(of: content(index, item))
        let rounded = CGSize(width: max(1, ceil(size.width)), height: max(1, ceil(size.height)))
        measurements.setIdealSize(rounded, for: id)
        return rounded
    }

    /// Drops the cached measurements of the item at `index`, so its row is measured again the next
    /// time the layout asks.
    ///
    /// Assigning ``items`` and calling ``notifyItemChanged(at:)`` already do this for items that
    /// changed. Call it when a row's content depends on state outside its item.
    public func invalidateMeasurement(at index: Int) {
        guard items.indices.contains(index) else { return }
        measurements.invalidate([getItemIDString(for: items[index], at: index)])
    }

    /// Drops every cached measurement, so all rows are measured again.
    public func invalidateAllMeasurements() {
        measurements.removeAll()
    }

    /// Drops the cached measurements of the items in `newItems` that kept their identity from
    /// `oldItems` but changed.
    func invalidateMeasurements(ofItemsChangedFrom oldItems: [Item], to newItems: [Item]) {
        guard !measurements.isEmpty else { return }

        if let changed = ItemChanges.changedIndices(from: oldItems, to: newItems) {
            measurements.invalidate(changed.map { getItemIDString(for: newItems[$0], at: $0) })
            return
        }

        // Without Equatable there is no telling which items changed. The rows on screen are the ones
        // rebound with the new values, so those are measured again; the others size themselves as they
        // scroll into view.
        guard let collectionView = collectionView else { return }
        let newIDs = Set(newItems.map(\.id))
        let rebound = collectionView.indexPathsForVisibleItems
            .map(\.item)
            .filter { oldItems.indices.contains($0) && newIDs.contains(oldItems[$0].id) }
        measurements.invalidate(rebound.map { getItemIDString(for: oldItems[$0], at: $0) })
    }

    // MARK: - Notifying changes

    /// Inserts the item at `index`, which must already be in ``items``.
    public func notifyItemInserted(at index: Int) {
        collectionView?.insertItems(at: [IndexPath(item: index, section: 0)])
    }

    /// Removes the item at `index`, which must already be gone from ``items``.
    public func notifyItemRemoved(at index: Int) {
        collectionView?.deleteItems(at: [IndexPath(item: index, section: 0)])
    }

    /// Moves the item at `from` to `to`, where it must already be in ``items``.
    ///
    /// The item keeps its cell, which animates to its new position.
    public func notifyItemMoved(from: Int, to: Int) {
        collectionView?.moveItem(at: IndexPath(item: from, section: 0), to: IndexPath(item: to, section: 0))
    }

    /// Rebinds the item at `index`, reloading it if its cell is not on screen.
    ///
    /// The item's cached measurement is dropped and the layout invalidated, so the row takes the
    /// height of its new content.
    public func notifyItemChanged(at index: Int) {
        guard let collectionView = collectionView else { return }

        invalidateMeasurement(at: index)
        let indexPath = IndexPath(item: index, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? ViewHolder<Content> {
            let item = items[index]
            cell.bind(content(index, item), itemID: getItemIDString(for: item, at: index), parentViewController: parentViewController)
            collectionView.collectionViewLayout.invalidateLayout()
        } else {
            collectionView.reloadItems(at: [indexPath])
        }
    }

    /// Reloads every item, measuring every row again.
    public func notifyDataSetChanged() {
        measurements.removeAll()
        collectionView?.reloadData()
    }

    /// Resets pagination, so the next page can be requested again.
    public func resetState() {
        previousItemCount = 0
        loadMoreTriggered = false
    }

    // MARK: - UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewHolder<Content>.reuseIdentifier, for: indexPath) as? ViewHolder<Content> else {
            return UICollectionViewCell()
        }

        if parentViewController == nil {
            parentViewController = collectionView.parentViewController
        }

        let item = items[indexPath.item]
        cell.bind(content(indexPath.item, item), itemID: getItemIDString(for: item, at: indexPath.item), parentViewController: parentViewController)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cell.transform = reverseLayout ? CGAffineTransform(rotationAngle: .pi) : .identity
        CATransaction.commit()

        return cell
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SeparatorView.reuseIdentifier, for: indexPath)
        if let separatorView = view as? SeparatorView {
            configure(separatorView, at: indexPath)
        }
        return view
    }

    private func configure(_ separatorView: SeparatorView, at indexPath: IndexPath) {
        guard let separator = separator else {
            separatorView.isHidden = true
            return
        }
        separatorView.configure(color: separator.color, isHidden: false)
    }

    /// Brings the separators on screen up to date with ``separator``.
    func refreshVisibleSeparators() {
        guard let collectionView = collectionView else { return }
        let kind = RecyclerViewSeparator.elementKind
        for indexPath in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: kind) {
            if let view = collectionView.supplementaryView(forElementKind: kind, at: indexPath) as? SeparatorView {
                configure(view, at: indexPath)
            }
        }
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        onItemClick?(indexPath.item, items[indexPath.item])
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let itemCount = items.count
        guard itemCount > 0 else { return }

        if indexPath.item < itemCount - RecyclerViewDefaults.loadMoreResetDistance {
            loadMoreTriggered = false
        }

        guard !loadMoreTriggered,
              indexPath.item >= itemCount - RecyclerViewDefaults.loadMoreTriggerDistance,
              pageSize > 0,
              itemCount % pageSize == 0
        else { return }

        loadMoreTriggered = true
        onLoadMore?(itemCount / pageSize, itemCount)
    }

    // MARK: - UIScrollViewDelegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView.contentOffset)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Resigning the first responder lets the keyboard leave with the system's own transition.
        switch keyboardDismissal {
        case .list:
            // Looks for the first responder among the collection view's own subviews only.
            scrollView.endEditing(true)
        case .window:
            scrollView.window?.endEditing(true)
        case nil:
            break
        }
    }
}
