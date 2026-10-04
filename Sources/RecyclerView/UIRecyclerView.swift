import UIKit

/// The collection view behind ``RecyclerView``.
///
/// Reversed layouts flip the collection view with a transform; this subclass keeps that transform
/// from animating implicitly.
public class UIRecyclerView: UICollectionView {
    /// Called after layout whenever the width of the collection view changes.
    var onWidthChange: ((CGFloat) -> Void)?
    private var lastLaidOutWidth: CGFloat?

    override public func layoutSubviews() {
        super.layoutSubviews()

        let width = bounds.width
        if width != lastLaidOutWidth {
            lastLaidOutWidth = width
            onWidthChange?(width)
        }
    }

    override public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "transform" {
            return NSNull()
        }
        return super.action(for: layer, forKey: event)
    }
}
