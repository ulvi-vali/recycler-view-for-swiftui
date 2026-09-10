import UIKit

/// The collection view behind ``RecyclerView``.
///
/// Reversed layouts flip the collection view with a transform; this subclass keeps that transform
/// from animating implicitly.
public class UIRecyclerView: UICollectionView {
    override public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "transform" {
            return NSNull()
        }
        return super.action(for: layer, forKey: event)
    }
}
