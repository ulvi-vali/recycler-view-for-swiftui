import SwiftUI
import UIKit

/// Scrolls a ``RecyclerView`` and locates its rows from outside the list.
///
/// SwiftUI offers no way to scroll a representable list to a row, adjust its content inset, or ask
/// which row lies under a point on screen. Create a controller, keep it for as long as the view
/// lives, and attach it with ``RecyclerView/controller(_:)``.
///
/// ```swift
/// struct MenuScreen: View {
///     @State private var controller = RecyclerViewController()
///     let sections: [MenuSection]
///
///     var body: some View {
///         RecyclerView(data: sections) { section in
///             SectionRow(section: section)
///         }
///         .controller(controller)
///         .verticalLayout(.matchParent)
///     }
///
///     func show(_ index: Int) {
///         controller.scrollToItem(at: index, topOffset: 56)
///     }
/// }
/// ```
///
/// Until the list has been created, every method does nothing and the queries return `nil` or
/// `false`. A controller drives one list at a time; attaching it to another list moves it there.
public final class RecyclerViewController {
    weak var collectionView: UICollectionView?
    var axis: Axis = .vertical

    /// Creates a controller that is not yet attached to a list.
    public init() {}

    func attach(to collectionView: UICollectionView, axis: Axis) {
        self.collectionView = collectionView
        self.axis = axis
    }

    // MARK: - Scrolling

    /// Scrolls until the item's leading edge sits `topOffset` points past the start of the visible
    /// area.
    ///
    /// In a vertical list that is the item's top edge, which keeps it clear of a bar floating over
    /// the top of the list. In a horizontal list it is the item's leading edge. The resulting offset
    /// is clamped to the scrollable range, including any content inset.
    ///
    /// - Parameters:
    ///   - index: The index of the item. Indices outside the list are ignored.
    ///   - topOffset: The distance to leave between the start of the visible area and the item.
    ///   - animated: Whether to animate the scroll.
    public func scrollToItem(at index: Int, topOffset: CGFloat = 0, animated: Bool = true) {
        guard let collectionView = collectionView, let frame = frameOfItem(at: index, in: collectionView) else { return }

        let offset: CGPoint
        if axis == .horizontal {
            let x = clamp(frame.minX - topOffset, to: horizontalOffsetRange(of: collectionView))
            offset = CGPoint(x: x, y: collectionView.contentOffset.y)
        } else {
            let y = clamp(frame.minY - topOffset, to: verticalOffsetRange(of: collectionView))
            offset = CGPoint(x: collectionView.contentOffset.x, y: y)
        }
        collectionView.setContentOffset(offset, animated: animated)
    }

    /// Scrolls a vertical list until the item's top edge sits on the horizontal line at `screenY`.
    ///
    /// The line is given in window coordinates rather than as a distance into the list, so callers
    /// need not account for where the list sits on screen, for example when it is drawn under the
    /// status bar with ``RecyclerView/withoutStatusBar(_:)``.
    ///
    /// - Parameters:
    ///   - index: The index of the item. Indices outside the list are ignored.
    ///   - screenY: The vertical position of the line, in the window's coordinate space.
    ///   - animated: Whether to animate the scroll.
    public func scrollToItem(at index: Int, screenY: CGFloat, animated: Bool = true) {
        guard let collectionView = collectionView, let frame = frameOfItem(at: index, in: collectionView) else { return }

        let lineY = collectionView.convert(CGPoint(x: 0, y: screenY), from: nil).y
        let y = clamp(collectionView.contentOffset.y + frame.minY - lineY, to: verticalOffsetRange(of: collectionView))
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: y), animated: animated)
    }

    /// Adds room to scroll past the end of the content without changing the list's size.
    ///
    /// Use it when a bar floats over the bottom of the list. Padding the list instead would stop the
    /// content at the bar's edge, leaving nothing behind a translucent bar or a fade drawn over it; a
    /// content inset lets the content run underneath while the last row can still be scrolled clear.
    ///
    /// - Parameters:
    ///   - inset: The bottom content inset, in points.
    ///   - animated: Whether to animate the change, so the content moves together with a bar sliding
    ///     in or out.
    ///   - duration: The duration of the animation, in seconds.
    public func setBottomInset(_ inset: CGFloat, animated: Bool = false, duration: Double = 0.3) {
        guard let collectionView = collectionView, collectionView.contentInset.bottom != inset else { return }

        let apply = {
            collectionView.contentInset.bottom = inset
            collectionView.verticalScrollIndicatorInsets.bottom = inset
        }

        if animated {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }

    // MARK: - Queries

    /// Whether the list is moving because the user is dragging it or it is decelerating from a drag,
    /// as opposed to a programmatic scroll.
    ///
    /// Check it in ``RecyclerView/onScroll(_:)`` to react only to scrolling the user started, for
    /// example to keep a tab bar in sync with the list without undoing a tap that scrolled it.
    public var isUserScrolling: Bool {
        guard let collectionView = collectionView else { return false }
        return collectionView.isDragging || collectionView.isDecelerating
    }

    /// Returns the index of the first item crossing the horizontal line at `screenY`.
    ///
    /// - Parameter screenY: The vertical position of the line, in the window's coordinate space.
    /// - Returns: The lowest index among the items the line crosses, or `nil` if it crosses none.
    public func indexOfItem(atScreenY screenY: CGFloat) -> Int? {
        guard let collectionView = collectionView else { return nil }

        let contentY = collectionView.convert(CGPoint(x: 0, y: screenY), from: nil).y
        let line = CGRect(x: 0, y: contentY, width: max(1, collectionView.bounds.width), height: 1)
        return collectionView.collectionViewLayout.layoutAttributesForElements(in: line)?
            .filter { $0.representedElementCategory == .cell }
            .map { $0.indexPath.item }
            .min()
    }

    // MARK: - Helpers

    private func frameOfItem(at index: Int, in collectionView: UICollectionView) -> CGRect? {
        guard index >= 0, index < collectionView.numberOfItems(inSection: 0) else { return nil }
        return collectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame
    }

    private func verticalOffsetRange(of scrollView: UIScrollView) -> ClosedRange<CGFloat> {
        let insets = scrollView.adjustedContentInset
        let lower = -insets.top
        let upper = scrollView.contentSize.height + insets.bottom - scrollView.bounds.height
        return lower...max(lower, upper)
    }

    private func horizontalOffsetRange(of scrollView: UIScrollView) -> ClosedRange<CGFloat> {
        let insets = scrollView.adjustedContentInset
        let lower = -insets.left
        let upper = scrollView.contentSize.width + insets.right - scrollView.bounds.width
        return lower...max(lower, upper)
    }

    private func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
