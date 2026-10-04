import CoreGraphics

/// Row measurements, kept per item identity so that every measurement of an item can be dropped at
/// once when the item changes.
struct RowMeasurementCache {
    /// Fitting heights by item identity, then by width rounded to whole points.
    private var heights: [String: [Int: CGFloat]] = [:]
    /// Ideal sizes by item identity.
    private var idealSizes: [String: CGSize] = [:]

    var isEmpty: Bool {
        heights.isEmpty && idealSizes.isEmpty
    }

    func height(for id: String, width: CGFloat) -> CGFloat? {
        heights[id]?[Self.widthKey(width)]
    }

    mutating func setHeight(_ height: CGFloat, for id: String, width: CGFloat) {
        heights[id, default: [:]][Self.widthKey(width)] = height
    }

    func idealSize(for id: String) -> CGSize? {
        idealSizes[id]
    }

    mutating func setIdealSize(_ size: CGSize, for id: String) {
        idealSizes[id] = size
    }

    /// Drops every measurement of the items with the given identities.
    mutating func invalidate<IDs: Sequence>(_ ids: IDs) where IDs.Element == String {
        for id in ids {
            heights[id] = nil
            idealSizes[id] = nil
        }
    }

    mutating func removeAll() {
        heights.removeAll()
        idealSizes.removeAll()
    }

    private static func widthKey(_ width: CGFloat) -> Int {
        Int(width.rounded())
    }
}

/// Finds items that kept their identity across an update but whose values changed.
enum ItemChanges {
    /// The positions in `new` of items whose identity is also in `old` but whose value differs from
    /// the old item with that identity.
    ///
    /// Values can only be compared when `Item` is `Equatable`; otherwise the result is `nil` and the
    /// caller has to assume any item may have changed.
    static func changedIndices<Item: Identifiable>(from old: [Item], to new: [Item]) -> [Int]? {
        guard Item.self is any Equatable.Type else { return nil }
        guard !old.isEmpty, !new.isEmpty else { return [] }

        var oldByID: [Item.ID: Item] = [:]
        oldByID.reserveCapacity(old.count)
        for item in old {
            oldByID[item.id] = item
        }

        return new.indices.filter { index in
            guard let oldItem = oldByID[new[index].id] else { return false }
            return !areEqual(oldItem, new[index])
        }
    }

    private static func areEqual<Item>(_ lhs: Item, _ rhs: Item) -> Bool {
        guard let lhs = lhs as? any Equatable else { return false }
        return lhs.isEqual(toValue: rhs)
    }
}

private extension Equatable {
    func isEqual(toValue other: Any) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}
