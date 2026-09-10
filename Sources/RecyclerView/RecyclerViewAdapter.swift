import SwiftUI
import UIKit

/// The data source and delegate that shows a list of items as SwiftUI views in a `UICollectionView`.
///
/// ``RecyclerView`` creates and manages an adapter. Create one yourself only to show SwiftUI rows in
/// a collection view built in UIKit: the adapter registers ``ViewHolder`` and makes itself the
/// collection view's data source and delegate.
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
    /// Whether dragging the collection view dismisses the keyboard.
    public var dismissesKeyboardOnScroll = false
    /// Whether a vertical linear layout measures its rows up front with ``measuredHeight(for:at:width:)``.
    public var precomputesItemHeights = true

    /// The items being displayed.
    ///
    /// Assigning items does not update the collection view. Call ``notifyDataSetChanged()``, or one
    /// of the granular `notify` methods, afterwards.
    public var items: [Item] = [] {
        didSet {
            if items.count > previousItemCount {
                loadMoreTriggered = false
            }
            previousItemCount = items.count
        }
    }

    /// The collection view the adapter serves.
    public weak var collectionView: UICollectionView?
    /// The view controller that hosting controllers are added to as children before iOS 16. Found
    /// through the responder chain when not set.
    public weak var parentViewController: UIViewController?

    private var previousItemCount = 0
    private var loadMoreTriggered = false
    private var heightCache: [String: CGFloat] = [:]

    /// Creates an adapter that builds each row from its index and item, and attaches it to
    /// `collectionView`.
    public init(collectionView: UICollectionView, content: @escaping (Int, Item) -> Content) {
        self.collectionView = collectionView
        self.content = content
        super.init()

        collectionView.register(ViewHolder<Content>.self, forCellWithReuseIdentifier: ViewHolder<Content>.reuseIdentifier)
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
    /// Each measurement costs one hosting view and is made once per item identity and width.
    public func measuredHeight(for item: Item, at index: Int, width: CGFloat) -> CGFloat {
        let key = "\(getItemIDString(for: item, at: index))@\(Int(width.rounded()))"
        if let cached = heightCache[key] {
            return cached
        }

        let height = max(1, ceil(SwiftUIMeasurement.fittingHeight(of: content(index, item), width: width)))
        heightCache[key] = height
        return height
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

    /// Rebinds the item at `index`, reloading it if its cell is not on screen.
    public func notifyItemChanged(at index: Int) {
        guard let collectionView = collectionView else { return }

        let indexPath = IndexPath(item: index, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? ViewHolder<Content> {
            let item = items[index]
            cell.bind(content(index, item), itemID: getItemIDString(for: item, at: index), parentViewController: parentViewController)
        } else {
            collectionView.reloadItems(at: [indexPath])
        }
    }

    /// Reloads every item.
    public func notifyDataSetChanged() {
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
        guard dismissesKeyboardOnScroll else { return }
        // Resigning the first responder lets the keyboard leave with the system's own transition.
        scrollView.window?.endEditing(true)
    }
}
