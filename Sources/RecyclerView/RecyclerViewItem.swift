/// An item of a ``RecyclerView`` that is either a value or a placeholder standing in for one, such
/// as a skeleton row shown while content loads.
///
/// Placeholders need an identity of their own to be diffed like any other item. A placeholder is
/// identified by its slot, a number you choose, which is usually its position:
///
/// ```swift
/// let rows: [RecyclerViewItem<Article>] = isLoading
///     ? RecyclerViewItem.placeholders(count: 8)
///     : articles.map(RecyclerViewItem.value)
///
/// RecyclerView(data: rows) { row in
///     switch row {
///     case .value(let article): ArticleRow(article: article)
///     case .placeholder: ArticleRow.skeleton
///     }
/// }
/// ```
///
/// An array of optionals can also be passed to ``RecyclerView`` directly. The list then wraps each
/// element, turning `nil` elements into placeholders identified by their position, and hands the row
/// builder the optional back:
///
/// ```swift
/// RecyclerView(data: articlesOrNil) { (article: Article?) in
///     if let article = article { ArticleRow(article: article) } else { ArticleRow.skeleton }
/// }
/// ```
public enum RecyclerViewItem<Value: Identifiable>: Identifiable {
    /// A loaded value.
    case value(Value)
    /// A placeholder in the given slot. Slots identify placeholders, so give each placeholder in a
    /// list a different one, such as its position.
    case placeholder(Int)

    /// The identity of a ``RecyclerViewItem``: the value's own `id`, or the placeholder's slot.
    ///
    /// A value and a placeholder never share an identity, so replacing placeholders with values is
    /// applied as removals and insertions.
    public enum ID: Hashable {
        /// The identity of a value.
        case value(Value.ID)
        /// The identity of a placeholder in the given slot.
        case placeholder(Int)
    }

    public var id: ID {
        switch self {
        case .value(let value):
            return .value(value.id)
        case .placeholder(let slot):
            return .placeholder(slot)
        }
    }

    /// The value, or `nil` for a placeholder.
    public var value: Value? {
        if case .value(let value) = self {
            return value
        }
        return nil
    }

    /// Whether the item is a placeholder.
    public var isPlaceholder: Bool {
        value == nil
    }

    /// Wraps an optional, turning `nil` into a placeholder in `slot`.
    public init(_ value: Value?, placeholderSlot slot: Int) {
        if let value = value {
            self = .value(value)
        } else {
            self = .placeholder(slot)
        }
    }

    /// `count` placeholders in slots `0..<count`.
    public static func placeholders(count: Int) -> [Self] {
        (0..<max(0, count)).map { .placeholder($0) }
    }

    /// Wraps each optional, turning a `nil` element into a placeholder whose slot is its position.
    public static func items(from values: [Value?]) -> [Self] {
        values.enumerated().map { RecyclerViewItem($0.element, placeholderSlot: $0.offset) }
    }
}

extension RecyclerViewItem: Equatable where Value: Equatable {}

extension RecyclerViewItem: Sendable where Value: Sendable {}

extension RecyclerViewItem.ID: Sendable where Value.ID: Sendable {}
