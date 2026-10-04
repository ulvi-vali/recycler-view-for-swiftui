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

    override public func layoutSubviews() {
        super.layoutSubviews()

        let width = bounds.width
        if width != lastLaidOutWidth {
            lastLaidOutWidth = width
            onWidthChange?(width)
        }
        reportWindowSafeAreaInsets()
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
