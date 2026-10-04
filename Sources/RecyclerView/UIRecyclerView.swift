import UIKit

/// The collection view behind ``RecyclerView``.
///
/// Reversed layouts flip the collection view with a transform; this subclass keeps that transform
/// from animating implicitly.
public class UIRecyclerView: UICollectionView {
    /// Called after layout whenever the width of the collection view changes.
    var onWidthChange: ((CGFloat) -> Void)?
    private var lastLaidOutWidth: CGFloat?

    /// Called with the safe-area insets of the window the collection view is in, when it moves to a
    /// window and whenever those insets change.
    var onWindowSafeAreaInsetsChange: ((UIEdgeInsets) -> Void)? {
        didSet { reportWindowSafeAreaInsets() }
    }
    private var reportedWindowSafeAreaInsets: UIEdgeInsets?

    /// Called with how far the list can still scroll each way, whenever that changes: when it
    /// scrolls, and when its content or size changes.
    var onScrollEdgesChange: ((RecyclerViewScrollEdges) -> Void)? {
        didSet {
            // Replaced on every SwiftUI update: only a first callback needs a report of its own, or
            // each report would cause an update that asks for the next one.
            guard oldValue == nil, onScrollEdgesChange != nil else { return }
            reportedScrollEdges = nil
            setNeedsLayout()
        }
    }
    private var reportedScrollEdges: RecyclerViewScrollEdges?
    /// The axis the list scrolls along.
    var scrollAxis: RecyclerViewScrollEdges.Axis = .vertical

    override public func layoutSubviews() {
        super.layoutSubviews()

        let width = bounds.width
        if width != lastLaidOutWidth {
            lastLaidOutWidth = width
            onWidthChange?(width)
        }
        reportWindowSafeAreaInsets()
        // A scroll view lays out on every change of its offset, so this follows scrolling too.
        reportScrollEdges()
    }

    private func reportScrollEdges() {
        guard let onScrollEdgesChange = onScrollEdgesChange else { return }

        let edges = RecyclerViewScrollEdges(of: self, axis: scrollAxis, flipped: transform != .identity)
        if let reported = reportedScrollEdges, reported.isClose(to: edges) { return }
        reportedScrollEdges = edges
        onScrollEdgesChange(edges)
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        reportWindowSafeAreaInsets()
    }

    override public func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        reportWindowSafeAreaInsets()
    }

    private func reportWindowSafeAreaInsets() {
        guard let onWindowSafeAreaInsetsChange = onWindowSafeAreaInsetsChange, let window = window else { return }

        let insets = window.safeAreaInsets
        guard insets != reportedWindowSafeAreaInsets else { return }
        reportedWindowSafeAreaInsets = insets
        onWindowSafeAreaInsetsChange(insets)
    }

    override public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "transform" {
            return NSNull()
        }
        return super.action(for: layer, forKey: event)
    }
}
