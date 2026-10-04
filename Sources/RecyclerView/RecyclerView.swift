import SwiftUI
import UIKit

/// A SwiftUI list backed by `UICollectionView`, modelled on Android's `RecyclerView`.
///
/// `RecyclerView` reuses cells, sizes each one to fit its SwiftUI content, and supports linear and
/// grid layouts, per-item column spans, pagination, reversed chat-style lists and programmatic
/// scrolling.
///
/// ```swift
/// RecyclerView(data: messages, layout: .linear(spacing: 8)) { message in
///     MessageRow(message: message)
/// }
/// .onItemClick { index, message in
///     print("Tapped \(message.id) at \(index)")
/// }
/// .verticalLayout(.matchParent)
/// ```
///
/// The configuration modifiers declared on `RecyclerView` return a new `RecyclerView`, so apply them
/// before any general SwiftUI modifier such as `padding(_:)`.
public struct RecyclerView<Item: Identifiable, Content: View>: View {
    private let data: [Item]
    private let layout: RecyclerViewLayoutManager
    private let content: (Int, Item) -> Content

    private var spanSizeLookup: ((Item) -> Int)?
    private var onItemClick: ((Int, Item) -> Void)?
    private var showsScrollIndicator = false
    private var verticalLayout: RecyclerViewVerticalLayout = .wrapContent
    private var withAnimation = true
    private var reverseLayout = false
    private var stackFromEnd = false
    private var pageSize = RecyclerViewDefaults.pageSize
    private var onScroll: ((CGPoint) -> Void)?
    private var onLoadMore: ((Int, Int) -> Void)?
    private var withoutStatusBar = false
    private var dismissesKeyboardOnScroll = false
    private var precomputesItemHeights = true
    private var controller: RecyclerViewController?

    /// The height a wrap-content list measured for itself, before iOS 16.
    @State private var legacyWrapContentHeight: CGFloat?
    /// The top safe-area inset of the window the list is in, once it is in one.
    @State private var windowTopInset: CGFloat?

    /// Creates a list that builds a row for each item.
    ///
    /// - Parameters:
    ///   - data: The items to display. Items are matched across updates by their `id`, so insertions
    ///     and removals are applied as batch updates instead of reloading the whole list.
    ///   - layout: How the items are arranged. Defaults to a vertical linear list.
    ///   - content: A view builder that creates the row for an item.
    public init(
        data: [Item],
        layout: RecyclerViewLayoutManager = .linear(),
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.data = data
        self.layout = layout
        self.content = { _, item in content(item) }
    }

    /// Creates a list that builds a row for each item from the item and its index.
    ///
    /// Use this form when a row depends on its position, for example to pad the first and last rows
    /// differently. The index is the item's position in `data`, including when ``stackFromEnd(_:)``
    /// is enabled.
    ///
    /// - Parameters:
    ///   - data: The items to display. Items are matched across updates by their `id`.
    ///   - layout: How the items are arranged. Defaults to a vertical linear list.
    ///   - content: A view builder that creates the row for an item at an index.
    public init(
        data: [Item],
        layout: RecyclerViewLayoutManager = .linear(),
        @ViewBuilder content: @escaping (_ index: Int, _ item: Item) -> Content
    ) {
        self.data = data
        self.layout = layout
        self.content = content
    }

    // MARK: - Layout

    /// Sets how many columns each item spans in a vertical grid.
    ///
    /// Spans are clamped to `1...spanCount`. An item that does not fit in the space left on the
    /// current row starts a new row, so a span equal to `spanCount` makes an item full width, which
    /// suits section headers and banners.
    ///
    /// ```swift
    /// RecyclerView(data: feed, layout: .grid(spanCount: 2)) { item in
    ///     FeedCell(item: item)
    /// }
    /// .spanSizeLookup { item in item.isHeader ? 2 : 1 }
    /// ```
    public func spanSizeLookup(_ lookup: @escaping (Item) -> Int) -> Self {
        var copy = self
        copy.spanSizeLookup = lookup
        return copy
    }

    /// Sets whether the list fills its container or sizes itself to its items.
    ///
    /// Defaults to ``RecyclerViewVerticalLayout/wrapContent``.
    public func verticalLayout(_ verticalLayout: RecyclerViewVerticalLayout) -> Self {
        var copy = self
        copy.verticalLayout = verticalLayout
        return copy
    }

    /// Flips the list so the first item sits at the bottom, where the list starts.
    ///
    /// Suited to chat transcripts whose data is ordered newest first.
    public func reverseLayout(_ enabled: Bool) -> Self {
        var copy = self
        copy.reverseLayout = enabled
        return copy
    }

    /// Keeps items in order but anchors them to the bottom of the list, like Android's `stackFromEnd`.
    ///
    /// The last item sits at the bottom, the list starts scrolled to it, and a list shorter than its
    /// container rests against the bottom edge. Suited to chat transcripts whose data is ordered
    /// oldest first. Indices passed to the content builder and to ``onItemClick(_:)`` still refer to
    /// positions in `data`.
    public func stackFromEnd(_ enabled: Bool) -> Self {
        var copy = self
        copy.stackFromEnd = enabled
        return copy
    }

    /// Extends the list up under the status bar.
    ///
    /// The list is shifted up by the top safe-area inset of its own window so that a full-bleed header
    /// can sit behind the status bar. The inset is read from the window the list is shown in, not the
    /// app's key window, so a list in a secondary window or scene is shifted by the right amount;
    /// before the list is in a window, the key window's inset stands in. Takes effect on iOS 15 and
    /// later. Cells ignore the safe area, so rows do not grow as they scroll beneath the status bar.
    public func withoutStatusBar(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.withoutStatusBar = enabled
        return copy
    }

    /// Controls whether a vertical linear list measures its rows before laying them out.
    ///
    /// Enabled by default. Each row is measured once per item identity and width, and the result is
    /// given to the layout as its estimated height. With close estimates, rows do not shift as they
    /// scroll into view, which is most noticeable when row heights vary widely.
    ///
    /// Measuring costs one hosting controller per item the first time the list lays it out. For a
    /// very large data set loaded all at once, disable it to fall back to lazy, uniform estimates.
    /// Grid and horizontal layouts always use uniform estimates.
    public func precomputesItemHeights(_ enabled: Bool) -> Self {
        var copy = self
        copy.precomputesItemHeights = enabled
        return copy
    }

    // MARK: - Behavior

    /// Sets whether the scroll indicator is visible. Hidden by default.
    public func showsScrollIndicator(_ show: Bool) -> Self {
        var copy = self
        copy.showsScrollIndicator = show
        return copy
    }

    /// Sets whether inserting and removing items is animated. Enabled by default.
    public func withAnimation(_ enabled: Bool) -> Self {
        var copy = self
        copy.withAnimation = enabled
        return copy
    }

    /// Dismisses the keyboard when the user starts dragging the list.
    ///
    /// Suited to search results, where the keyboard hides much of what was found. Off by default,
    /// because a list that contains text fields of its own should not close them.
    public func dismissesKeyboardOnScroll(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.dismissesKeyboardOnScroll = enabled
        return copy
    }

    /// Attaches a controller that scrolls the list and locates its rows.
    ///
    /// See ``RecyclerViewController``.
    public func controller(_ controller: RecyclerViewController) -> Self {
        var copy = self
        copy.controller = controller
        return copy
    }

    // MARK: - Callbacks

    /// Calls `action` when an item is tapped, with the item's index in `data` and the item.
    public func onItemClick(_ action: @escaping (_ index: Int, _ item: Item) -> Void) -> Self {
        var copy = self
        copy.onItemClick = action
        return copy
    }

    /// Calls `action` with the content offset whenever the list scrolls.
    public func onScroll(_ action: @escaping (_ contentOffset: CGPoint) -> Void) -> Self {
        var copy = self
        copy.onScroll = action
        return copy
    }

    /// Requests the next page as the user nears the end of the list.
    ///
    /// Pagination assumes every page except the last holds exactly `pageSize` items. The callback
    /// fires once one of the last five items is displayed while the item count is a multiple of
    /// `pageSize`, so a short final page ends pagination by itself. It fires once per page and
    /// re-arms when items are appended.
    ///
    /// ```swift
    /// RecyclerView(data: articles) { article in
    ///     ArticleRow(article: article)
    /// }
    /// .onLoadMore(pageSize: 20) { page, itemCount in
    ///     viewModel.loadPage(page)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - pageSize: The number of items in a full page.
    ///   - perform: Receives the index of the page to load, `itemCount / pageSize`, and the current
    ///     item count.
    public func onLoadMore(pageSize: Int, perform: @escaping (_ page: Int, _ itemCount: Int) -> Void) -> Self {
        var copy = self
        copy.pageSize = pageSize
        copy.onLoadMore = perform
        return copy
    }

    /// Requests the next page as the user nears the end of the list, with pages of 50 items.
    ///
    /// See ``onLoadMore(pageSize:perform:)``.
    public func onLoadMore(_ perform: @escaping (_ page: Int, _ itemCount: Int) -> Void) -> Self {
        onLoadMore(pageSize: RecyclerViewDefaults.pageSize, perform: perform)
    }

    /// Requests the next page as the user nears the end of the list.
    ///
    /// Equivalent to ``onLoadMore(pageSize:perform:)``.
    public func onLoadMore(_ pageSize: Int, _ perform: @escaping (_ page: Int, _ itemCount: Int) -> Void) -> Self {
        onLoadMore(pageSize: pageSize, perform: perform)
    }

    // MARK: - Body

    @ViewBuilder
    public var body: some View {
        if verticalLayout == .wrapContent && !WrapContentSizing.listAnswersSizeThatFits {
            // Before iOS 16 the list measures itself once laid out and reports its height. The flexible
            // frame keeps it at that height but lets a smaller container squeeze it, as
            // `sizeThatFits` does on later versions.
            let height = legacyWrapContentHeight ?? 0
            list(onWrapContentHeight: { legacyWrapContentHeight = $0 })
                .frame(minHeight: 0, idealHeight: height, maxHeight: height)
        } else {
            list(onWrapContentHeight: nil)
        }
    }

    private func list(onWrapContentHeight: ((CGFloat) -> Void)?) -> some View {
        var representable = RecyclerViewRepresentable(
            data: displayedData,
            layout: layout,
            content: { index, item in content(dataIndex(forDisplayedIndex: index), item) },
            spanSizeLookup: spanSizeLookup,
            onItemClick: { index, item in onItemClick?(dataIndex(forDisplayedIndex: index), item) },
            showsScrollIndicator: showsScrollIndicator,
            withAnimation: withAnimation,
            reverseLayout: reverseLayout || stackFromEnd,
            pageSize: pageSize,
            onScroll: onScroll,
            onLoadMore: onLoadMore,
            verticalLayout: verticalLayout,
            dismissesKeyboardOnScroll: dismissesKeyboardOnScroll,
            precomputesItemHeights: precomputesItemHeights,
            controller: controller
        )
        representable.onWrapContentHeight = onWrapContentHeight
        if withoutStatusBar {
            representable.onWindowSafeAreaInsets = { windowTopInset = $0.top }
        }
        return representable.padding(.top, topOffset)
    }

    /// Stacking from the end flips the list, so the items are reversed to keep reading top to bottom.
    private var reversesData: Bool {
        stackFromEnd && !reverseLayout
    }

    private var displayedData: [Item] {
        reversesData ? Array(data.reversed()) : data
    }

    private func dataIndex(forDisplayedIndex index: Int) -> Int {
        reversesData ? data.count - 1 - index : index
    }

    /// Shifts the list up under the status bar by its own window's top safe-area inset.
    ///
    /// The inset is read from the window the list is in, which is reported once the list is in one.
    /// Until then the key window of the app's scenes stands in for it, so the first frame is usually
    /// already in place.
    private var topOffset: CGFloat {
        guard withoutStatusBar, #available(iOS 15.0, *) else { return 0 }
        return -(windowTopInset ?? WindowMetrics.safeAreaInsets.top)
    }
}

/// How a ``RecyclerViewVerticalLayout/wrapContent`` list learns the space it is given.
@MainActor
enum WrapContentSizing {
    /// Makes iOS 16 and later size wrap-content lists the way earlier versions do. For tests only.
    static var forcesLegacySizing = false

    /// Whether SwiftUI asks the list for its size through `UIViewRepresentable.sizeThatFits`, which
    /// carries the proposed width and height. Before iOS 16 the list measures itself once laid out.
    static var listAnswersSizeThatFits: Bool {
        guard #available(iOS 16.0, *) else { return false }
        return !forcesLegacySizing
    }
}
