import SwiftUI

/// Describes how a ``RecyclerView`` arranges its items.
///
/// The names follow Android's `LinearLayoutManager` and `GridLayoutManager`, so a screen ported from
/// Android keeps the same vocabulary.
public enum RecyclerViewLayoutManager: Equatable, Sendable {
    /// A single column (vertical) or row (horizontal) of items.
    ///
    /// - Parameters:
    ///   - orientation: The axis the list scrolls along. Defaults to `.vertical`.
    ///   - spacing: The space between items. The same amount is inset around the content.
    case linear(orientation: Axis = .vertical, spacing: CGFloat = 0)

    /// Items arranged in `spanCount` columns (vertical) or rows (horizontal).
    ///
    /// Combine a vertical grid with ``RecyclerView/spanSizeLookup(_:)`` to let some items, such as
    /// section headers, span several columns.
    ///
    /// - Parameters:
    ///   - spanCount: The number of columns in a vertical grid, or rows in a horizontal one.
    ///   - spacing: The space between items, both along and across the scroll axis.
    ///   - orientation: The axis the grid scrolls along. Defaults to `.vertical`.
    case grid(spanCount: Int, spacing: CGFloat = 10, orientation: Axis = .vertical)

    /// The axis the list scrolls along.
    var orientation: Axis {
        switch self {
        case .linear(let orientation, _), .grid(_, _, let orientation):
            return orientation
        }
    }
}

/// Which text input a ``RecyclerView`` ends when the user starts dragging it.
///
/// Pass it to `RecyclerView.dismissesKeyboardOnScroll(_:)`, or set
/// ``RecyclerViewAdapter/keyboardDismissal`` on an adapter.
public enum RecyclerViewKeyboardDismissal: Equatable, Sendable {
    /// Ends editing only in a text field or text view inside the list, such as one in a row.
    ///
    /// Text input elsewhere on screen keeps the keyboard, so dragging a list does not close a
    /// search field or composer that merely sits next to it.
    case list

    /// Ends editing anywhere in the list's window.
    ///
    /// Suited to a list shown together with its own input outside the list, such as search results
    /// under a search field or a chat transcript above its composer.
    case window
}

/// How a ``RecyclerView`` sizes itself vertically.
public enum RecyclerViewVerticalLayout: Equatable, Sendable {
    /// Fills the height its container proposes, like Android's `match_parent`.
    ///
    /// Use it for a list that is the main content of a screen.
    case matchParent

    /// Sizes itself to fit its items, like Android's `wrap_content`.
    ///
    /// The items are measured at the width the container proposes, the way the list lays them out,
    /// and the list is as tall as they are. A container that proposes less height, such as a `VStack`
    /// sharing the screen with other views, caps the list at that height, and the list scrolls; one
    /// that proposes no height, such as a vertical `ScrollView`, gets a list as tall as all its items.
    /// Nothing about the window, the screen or the bars around the list is assumed.
    ///
    /// Suited to short lists embedded in other content. A horizontal list is as tall as its tallest
    /// item at that item's ideal size.
    case wrapContent
}
