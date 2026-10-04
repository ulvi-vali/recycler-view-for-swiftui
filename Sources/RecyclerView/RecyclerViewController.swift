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
@MainActor
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

    /// Scrolls until the item sits in the middle of the visible area, as far as the content allows.
    ///
    /// The visible area is the list without its content insets, so an item centred under a floating
    /// bar is centred in what is left uncovered. Use it to bring a selected item into view without
    /// pressing it against an edge, where the rows around it would be out of sight.
    ///
    /// - Parameters:
    ///   - index: The index of the item. Indices outside the list are ignored.
    ///   - offset: How far above the middle the item's centre should sit, or before it in a horizontal
    ///     list. Negative values place it below or after.
    ///   - animated: Whether to animate the scroll.
    public func scrollToItemCentered(at index: Int, offset: CGFloat = 0, animated: Bool = true) {
        guard let collectionView = collectionView, let frame = frameOfItem(at: index, in: collectionView) else { return }

        let insets = collectionView.adjustedContentInset
        // A reversed list is turned upside down, so "above" on screen is further along its content.
        let shift = collectionView.transform == .identity ? offset : -offset
        let point: CGPoint
        if axis == .horizontal {
            let visible = collectionView.bounds.width - insets.left - insets.right
            let x = clamp(frame.midX - insets.left - visible / 2 + shift, to: horizontalOffsetRange(of: collectionView))
            point = CGPoint(x: x, y: collectionView.contentOffset.y)
        } else {
            let visible = collectionView.bounds.height - insets.top - insets.bottom
            let y = clamp(frame.midY - insets.top - visible / 2 + shift, to: verticalOffsetRange(of: collectionView))
            point = CGPoint(x: collectionView.contentOffset.x, y: y)
        }
        collectionView.setContentOffset(point, animated: animated)
    }

    // MARK: - Insets

    /// The list's content insets, by the edges of the list as it appears on screen.
    ///
    /// `.zero` until the list has been created.
    public var contentInsets: UIEdgeInsets {
        guard let collectionView = collectionView else { return .zero }
        return Self.screenEdges(of: collectionView.contentInset, in: collectionView)
    }

    /// Adds room to scroll beyond the content on each edge, without changing the list's size.
    ///
    /// Use it when bars float over the list. Padding the list instead would stop the content at a
    /// bar's edge, leaving nothing behind a translucent bar or a fade drawn over it; a content inset
    /// lets the content run underneath while the first and last rows can still be scrolled clear.
    /// The scroll indicators are inset by the same amounts, so they stay clear of the bars too.
    ///
    /// Edges refer to the list as it appears on screen. A list flipped by
    /// ``RecyclerView/reverseLayout(_:)`` or ``RecyclerView/stackFromEnd(_:)`` still takes its
    /// bottom inset at the bottom of the screen.
    ///
    /// ```swift
    /// controller.setContentInsets(UIEdgeInsets(top: headerHeight, left: 0, bottom: barHeight, right: 0))
    /// ```
    ///
    /// - Parameters:
    ///   - insets: The content insets, in points.
    ///   - animated: Whether to animate the change, so the content moves together with a bar sliding
    ///     in or out.
    ///   - duration: The duration of the animation, in seconds.
    public func setContentInsets(_ insets: UIEdgeInsets, animated: Bool = false, duration: Double = 0.3) {
        guard let collectionView = collectionView else { return }

        let applied = Self.screenEdges(of: insets, in: collectionView)
        guard collectionView.contentInset != applied
            || collectionView.verticalScrollIndicatorInsets != applied
            || collectionView.horizontalScrollIndicatorInsets != applied
        else { return }

        let apply = {
            collectionView.contentInset = applied
            collectionView.verticalScrollIndicatorInsets = applied
            collectionView.horizontalScrollIndicatorInsets = applied
        }

        if animated {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }

    /// Adds room to scroll past the end of the content without changing the list's size.
    ///
    /// Use it when a bar floats over the bottom of the list. Equivalent to
    /// ``setContentInsets(_:animated:duration:)`` with the other edges left as they are.
    ///
    /// - Parameters:
    ///   - inset: The bottom content inset, in points.
    ///   - animated: Whether to animate the change, so the content moves together with a bar sliding
    ///     in or out.
    ///   - duration: The duration of the animation, in seconds.
    public func setBottomInset(_ inset: CGFloat, animated: Bool = false, duration: Double = 0.3) {
        var insets = contentInsets
        insets.bottom = inset
        setContentInsets(insets, animated: animated, duration: duration)
    }

    /// Converts insets between the edges of the screen and those of the collection view, which differ
    /// when a reversed layout has turned the collection view upside down. The conversion is its own
    /// inverse.
    private static func screenEdges(of insets: UIEdgeInsets, in collectionView: UICollectionView) -> UIEdgeInsets {
        guard collectionView.transform != .identity else { return insets }
        return UIEdgeInsets(top: insets.bottom, left: insets.right, bottom: insets.top, right: insets.left)
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
