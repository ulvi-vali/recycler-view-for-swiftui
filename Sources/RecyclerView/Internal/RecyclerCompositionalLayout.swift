import SwiftUI
import UIKit

/// The compositional layout behind ``RecyclerView``, which also places the separators of a linear list.
///
/// Separators are derived from the final frames of the rows, after the rows have sized themselves,
/// rather than declared as supplementary items of the layout's groups. That keeps them out of the
/// sizes the layout computes, so they never change how rows are measured, and lets them follow every
/// row of a vertical list measured up front, whose rows all share one group.
final class RecyclerCompositionalLayout: UICollectionViewCompositionalLayout {
    /// How the separators of a linear list are placed.
    struct Separators {
        /// The axis the list scrolls along.
        let axis: Axis
        /// The space between rows.
        let spacing: CGFloat
        /// The separator to draw, read whenever the layout is queried.
        let separator: @MainActor () -> RecyclerViewSeparator?
    }

    /// Set for linear lists; grids have no separators.
    var separators: Separators?

    private var separatorKind: String {
        RecyclerViewSeparator.elementKind
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)
        guard let attributes = attributes, separators?.separator() != nil else { return attributes }

        let separatorsInRect = attributes
            .filter { $0.representedElementCategory == .cell }
            .compactMap { separatorAttributes(forRow: $0) }
            .filter { $0.frame.intersects(rect) }
        return attributes + separatorsInRect
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard elementKind == separatorKind else {
            return super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)
        }
        guard let row = layoutAttributesForItem(at: indexPath) else { return nil }
        return separatorAttributes(forRow: row)
    }

    override func initialLayoutAttributesForAppearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == separatorKind else {
            return super.initialLayoutAttributesForAppearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath)
        }
        return fading(layoutAttributesForSupplementaryView(ofKind: elementKind, at: elementIndexPath))
    }

    override func finalLayoutAttributesForDisappearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == separatorKind else {
            return super.finalLayoutAttributesForDisappearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath)
        }
        return fading(layoutAttributesForSupplementaryView(ofKind: elementKind, at: elementIndexPath))
    }

    /// The separator that follows a row, or `nil` when the row is last and none is drawn after it.
    private func separatorAttributes(forRow row: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes? {
        guard let separators = separators, let separator = separators.separator(), let collectionView = collectionView else {
            return nil
        }

        let indexPath = row.indexPath
        let isLast = indexPath.item >= collectionView.numberOfItems(inSection: indexPath.section) - 1
        guard !isLast || separator.drawsAfterLast else { return nil }

        let thickness = separator.resolvedThickness(displayScale: collectionView.traitCollection.displayScale)
        let beyondRow = separator.offsetBeyondRow(spacing: separators.spacing, thickness: thickness)
        let insets = separator.insets
        let rowFrame = row.frame

        let frame: CGRect
        if separators.axis == .vertical {
            frame = CGRect(
                x: rowFrame.minX + insets.leading,
                y: rowFrame.maxY + beyondRow - thickness,
                width: rowFrame.width - insets.leading - insets.trailing,
                height: thickness
            )
        } else {
            frame = CGRect(
                x: rowFrame.maxX + beyondRow - thickness,
                y: rowFrame.minY + insets.top,
                width: thickness,
                height: rowFrame.height - insets.top - insets.bottom
            )
        }
        guard thickness > 0, frame.width > 0, frame.height > 0 else { return nil }

        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: separatorKind, with: indexPath)
        attributes.frame = frame
        attributes.zIndex = row.zIndex + 1
        return attributes
    }

    private func fading(_ attributes: UICollectionViewLayoutAttributes?) -> UICollectionViewLayoutAttributes? {
        guard let attributes = attributes?.copy() as? UICollectionViewLayoutAttributes else { return nil }
        attributes.alpha = 0
        return attributes
    }
}
