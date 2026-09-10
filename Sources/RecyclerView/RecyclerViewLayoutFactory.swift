import SwiftUI
import UIKit

/// Builds the compositional layout for each ``RecyclerViewLayoutManager``.
@MainActor
enum RecyclerViewLayoutFactory {
    static func makeLayout<Item: Identifiable, Content: View>(
        for layout: RecyclerViewLayoutManager,
        adapter: RecyclerViewAdapter<Item, Content>
    ) -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = layout.orientation == .horizontal ? .horizontal : .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: { [weak adapter] _, environment in
            guard let adapter = adapter else { return nil }

            switch layout {
            case .linear(let orientation, let spacing):
                if orientation == .horizontal {
                    return horizontalLinearSection(spacing: spacing)
                }
                return verticalLinearSection(adapter: adapter, spacing: spacing, environment: environment)

            case .grid(let spanCount, let spacing, let orientation):
                guard !adapter.items.isEmpty else { return emptySection() }
                let spanCount = max(1, spanCount)
                if orientation == .horizontal {
                    return horizontalGridSection(spanCount: spanCount, spacing: spacing)
                }
                return verticalGridSection(adapter: adapter, spanCount: spanCount, spacing: spacing)
            }
        }, configuration: configuration)
    }

    private static func verticalLinearSection<Item: Identifiable, Content: View>(
        adapter: RecyclerViewAdapter<Item, Content>,
        spacing: CGFloat,
        environment: any NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let items = adapter.items
        let insets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
        let width = environment.container.effectiveContentSize.width - spacing * 2

        // Measuring needs a real width and at least one row, since a group cannot be empty.
        guard adapter.precomputesItemHeights, !items.isEmpty, width > 0 else {
            let size = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(RecyclerViewDefaults.estimatedItemHeight)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = insets
            return section
        }

        // One group holding every row at its measured height, rather than a repeating group sharing
        // one estimate. See RecyclerViewAdapter.measuredHeight(for:at:width:).
        var subitems: [NSCollectionLayoutItem] = []
        subitems.reserveCapacity(items.count)
        var totalHeight = spacing * CGFloat(items.count - 1)

        for (index, item) in items.enumerated() {
            let height = adapter.measuredHeight(for: item, at: index, width: width)
            // Estimated rather than absolute: an exact measurement leaves nothing to correct, while an
            // inexact one still lets the cell size itself instead of clipping its content.
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(height))
            subitems.append(NSCollectionLayoutItem(layoutSize: size))
            totalHeight += height
        }

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(totalHeight))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: subitems)
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = insets
        return section
    }

    private static func horizontalLinearSection(spacing: CGFloat) -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(
            widthDimension: .estimated(RecyclerViewDefaults.estimatedItemWidth),
            heightDimension: .fractionalHeight(1.0)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
        return section
    }

    private static func verticalGridSection<Item: Identifiable, Content: View>(
        adapter: RecyclerViewAdapter<Item, Content>,
        spanCount: Int,
        spacing: CGFloat
    ) -> NSCollectionLayoutSection {
        let estimatedHeight = RecyclerViewDefaults.estimatedItemHeight
        let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))

        if let spanSizeLookup = adapter.spanSizeLookup, spanCount > 1 {
            let spans = adapter.items.map { SpanRows.clamp(spanSizeLookup($0), spanCount: spanCount) }
            let rows = SpanRows.build(count: spans.count, spanCount: spanCount, span: { spans[$0] })

            let rowGroups = rows.map { row -> NSCollectionLayoutItem in
                let subitems = row.map { index in
                    NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(CGFloat(spans[index]) / CGFloat(spanCount)),
                        heightDimension: .estimated(estimatedHeight)
                    ))
                }
                let rowGroup = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: subitems)
                rowGroup.interItemSpacing = .fixed(spacing)
                return rowGroup
            }

            let rootGroup = NSCollectionLayoutGroup.vertical(layoutSize: rowSize, subitems: rowGroups)
            rootGroup.interItemSpacing = .fixed(spacing)
            let section = NSCollectionLayoutSection(group: rootGroup)
            section.contentInsets = .zero
            return section
        }

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitem: NSCollectionLayoutItem(layoutSize: rowSize), count: spanCount)
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = .zero
        return section
    }

    private static func horizontalGridSection(spanCount: Int, spacing: CGFloat) -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(RecyclerViewDefaults.estimatedGridColumnWidth),
            heightDimension: .fractionalHeight(1.0)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: spanCount)
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = .zero
        return section
    }

    /// The section used while a grid has no items.
    private static func emptySection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(0.1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        return NSCollectionLayoutSection(group: group)
    }
}
