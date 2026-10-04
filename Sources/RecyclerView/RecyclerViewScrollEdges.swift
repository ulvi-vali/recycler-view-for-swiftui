import UIKit

/// How far a ``RecyclerView`` can still scroll towards each end, in points.
///
/// Read it with ``RecyclerView/onScrollEdges(_:)``, for example to show a shadow where the list is
/// cut off, or a "back to top" button once the list has moved away from the start. The ends are those
/// of the list as it appears on screen: in a reversed list, `toStart` is still the distance to the top.
public struct RecyclerViewScrollEdges: Equatable, Sendable {
    /// The distance to the top of the list, or its leading edge in a horizontal list. Zero at the
    /// start, and while the list bounces past it.
    public var toStart: CGFloat
    /// The distance to the bottom of the list, or its trailing edge. Zero when everything fits.
    public var toEnd: CGFloat

    /// Creates edges from the two distances.
    public init(toStart: CGFloat, toEnd: CGFloat) {
        self.toStart = toStart
        self.toEnd = toEnd
    }

    enum Axis: Sendable {
        case vertical
        case horizontal
    }

    /// The distances of a scroll view, its content insets included.
    init(of scrollView: UIScrollView, axis: Axis, flipped: Bool) {
        let insets = scrollView.adjustedContentInset
        let range: CGFloat
        let offset: CGFloat
        switch axis {
        case .vertical:
            range = scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
            offset = scrollView.contentOffset.y + insets.top
        case .horizontal:
            range = scrollView.contentSize.width + insets.left + insets.right - scrollView.bounds.width
            offset = scrollView.contentOffset.x + insets.left
        }
        let fromStart = max(0, min(offset, range))
        let toEnd = max(0, range - fromStart)
        // A reversed list is turned upside down: the start of its content is at the end of the screen.
        self.init(toStart: flipped ? toEnd : fromStart, toEnd: flipped ? fromStart : toEnd)
    }

    /// Changes below half a point are not worth a report.
    func isClose(to other: RecyclerViewScrollEdges) -> Bool {
        abs(toStart - other.toStart) < 0.5 && abs(toEnd - other.toEnd) < 0.5
    }
}
