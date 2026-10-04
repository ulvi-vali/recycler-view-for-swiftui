import SwiftUI
import UIKit

/// Computes the height a ``RecyclerViewVerticalLayout/wrapContent`` list needs to show its items.
///
/// The list is measured at the width its container gives it, the same way the collection view lays
/// it out, so the result matches the content height of the list. Nothing about the window, the screen
/// or the bars around the list is assumed: the height is only capped by `maxHeight`, the height the
/// container proposes.
@MainActor
enum WrapContentMeasurement {
    static func height<Item: Identifiable, Content: View>(
        of items: [Item],
        layout: RecyclerViewLayoutManager,
        spanSizeLookup: ((Item) -> Int)?,
        width: CGFloat,
        maxHeight: CGFloat = .infinity,
        adapter: RecyclerViewAdapter<Item, Content>
    ) -> CGFloat {
        guard !items.isEmpty, width > 0, maxHeight > 0 else { return 0 }

        switch layout {
        case .linear(let orientation, let spacing):
            if orientation == .horizontal {
                // Items choose their own width, and each is as tall as the list less its insets.
                let tallest = items.enumerated().reduce(CGFloat(0)) { tallest, element in
                    max(tallest, adapter.measuredIdealSize(for: element.element, at: element.offset).height)
                }
                return min(tallest + 2 * spacing, maxHeight)
            }

            // The section is inset by `spacing` on every side, with `spacing` between rows.
            let rowWidth = width - 2 * spacing
            guard rowWidth > 0 else { return 0 }
            var total = spacing
            for (index, item) in items.enumerated() {
                if index > 0 {
                    total += spacing
                }
                total += adapter.measuredHeight(for: item, at: index, width: rowWidth)
                if total + spacing >= maxHeight {
                    return maxHeight
                }
            }
            return min(total + spacing, maxHeight)

        case .grid(let spanCount, let spacing, let orientation):
            let spanCount = max(1, spanCount)

            if orientation == .horizontal {
                // `spanCount` rows share the list's height, with `spacing` between them.
                let tallest = items.enumerated().reduce(CGFloat(0)) { tallest, element in
                    max(tallest, adapter.measuredIdealSize(for: element.element, at: element.offset).height)
                }
                return min(CGFloat(spanCount) * tallest + CGFloat(spanCount - 1) * spacing, maxHeight)
            }

            let columnWidth = (width - CGFloat(spanCount - 1) * spacing) / CGFloat(spanCount)
            guard columnWidth > 0 else { return 0 }
            let spans = items.map { spanCount > 1 ? SpanRows.clamp(spanSizeLookup?($0) ?? 1, spanCount: spanCount) : 1 }
            var total: CGFloat = 0

            for (rowIndex, row) in SpanRows.build(count: items.count, spanCount: spanCount, span: { spans[$0] }).enumerated() {
                if rowIndex > 0 {
                    total += spacing
                }
                var tallest: CGFloat = 0
                for index in row {
                    let span = CGFloat(spans[index])
                    let itemWidth = span * columnWidth + (span - 1) * spacing
                    tallest = max(tallest, adapter.measuredHeight(for: items[index], at: index, width: itemWidth))
                }
                total += tallest
                if total >= maxHeight {
                    return maxHeight
                }
            }
            return min(total, maxHeight)
        }
    }
}
