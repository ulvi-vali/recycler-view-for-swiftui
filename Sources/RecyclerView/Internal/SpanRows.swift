/// Groups grid items into rows by the number of columns each one spans.
enum SpanRows {
    /// Splits `count` items into rows of at most `spanCount` columns.
    ///
    /// Items fill the current row in order. An item that does not fit in the columns left on the row
    /// starts a new one.
    ///
    /// - Parameters:
    ///   - count: The number of items.
    ///   - spanCount: The number of columns in a row. Values below 1 are treated as 1.
    ///   - span: The number of columns the item at an index spans, clamped with ``clamp(_:spanCount:)``.
    /// - Returns: The item indices of each row, in order.
    static func build(count: Int, spanCount: Int, span: (Int) -> Int) -> [[Int]] {
        let spanCount = max(1, spanCount)
        var rows: [[Int]] = []
        var currentRow: [Int] = []
        var remainingSpans = spanCount

        for index in 0..<max(0, count) {
            let itemSpan = clamp(span(index), spanCount: spanCount)
            if itemSpan > remainingSpans {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                }
                remainingSpans = spanCount
            }
            currentRow.append(index)
            remainingSpans -= itemSpan
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }

    /// Limits `span` to `1...spanCount`.
    static func clamp(_ span: Int, spanCount: Int) -> Int {
        min(max(1, span), max(1, spanCount))
    }
}
