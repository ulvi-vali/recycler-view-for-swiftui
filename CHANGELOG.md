# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RecyclerViewController.setContentInsets(_:animated:duration:)` sets the content inset on every
  edge and insets both scroll indicators to match, and `contentInsets` reads it back.
  `setBottomInset(_:animated:duration:)` remains, built on top of it.
- `.dismissesKeyboardOnScroll(_:)` accepting a `RecyclerViewKeyboardDismissal`: `.list` ends editing
  in text input inside the list, `.window` anywhere in the list's window.
  `RecyclerViewAdapter.keyboardDismissal` sets the same for an adapter.
- Move detection. Items that keep their `id` but change position are moved with
  `moveItem(at:to:)` in the same batch update as deletions and insertions, keeping their cells,
  instead of being deleted and inserted again.
- `RecyclerViewAdapter.notifyItemMoved(from:to:)`.
- `RecyclerViewAdapter.invalidateMeasurement(at:)` and `invalidateAllMeasurements()`, for rows that
  depend on state outside their item.
- Separators for linear lists: `.separator(color:thickness:insets:drawAfterLast:)`,
  `.separator(_:)` and `RecyclerViewSeparator`. None are drawn by default. They sit between rows,
  after the last row only with `drawAfterLast`, and are placed from the rows' final frames without
  taking space, so row measurement and wrap-content heights are unaffected.

### Changed

- `.dismissesKeyboardOnScroll()` and `.dismissesKeyboardOnScroll(true)` only end editing in text
  input inside the list, instead of ending editing in the whole window. Pass `.window` for the old
  behaviour, for example when a search field or chat composer sits outside the list.

- The package builds in the Swift 6 language mode with strict concurrency checking, and needs
  Xcode 16 (swift-tools-version 6.0). Apps in the Swift 5 language mode can still use it.
- `RecyclerViewAdapter`, `RecyclerViewController` and `ViewHolder` are `@MainActor`.
- Background diffing sends only integer stand-ins for item identities to the background queue, so
  `Item` and `Item.ID` need not be `Sendable`.
- Wrap-content lists measure against the space SwiftUI proposes. Rows are measured at the container's
  width, and the height is capped at the container's proposed height, through `sizeThatFits` on
  iOS 16 and later and a measurement after layout on iOS 13–15. The fixed allowances for a navigation
  bar, a header, the safe area and a bottom margin are gone, as is any reading of the screen size.
- Wrap-content horizontal lists and grids measure items at their ideal size instead of an assumed
  150pt width, and no longer add 15pt below the tallest item.

### Fixed

- Wrap-content lists narrower than the screen, such as lists inside cards or split views, were
  measured at the screen's width and came out too short.
- `withoutStatusBar` read the safe area of the app's key window, which is the wrong window for a list
  in a secondary window or scene. It now reads the list's own window, falling back to the key window
  only until the list is in a window.
- A row whose content changed while its `id` stayed the same kept its old cached height, as did a
  wrap-content list sized from it. Assigning items now drops the measurements of changed items:
  exactly those that differ when `Item` is `Equatable`, and the rows on screen otherwise.
  `notifyItemChanged(at:)` drops the item's measurement and invalidates the layout, and
  `notifyDataSetChanged()` drops all of them.
- `setBottomInset` on a list flipped by `reverseLayout` or `stackFromEnd` inset the top of the screen,
  because the flipped collection view's bottom edge is on top. Insets now follow the screen edges.

## [1.0.0] - 2026-09-10

The first tagged release.

### Added

- `RecyclerViewController`, attached with `.controller(_:)`, to drive a list from outside it:
  `scrollToItem(at:topOffset:animated:)`, `scrollToItem(at:screenY:animated:)`,
  `indexOfItem(atScreenY:)`, `isUserScrolling` and `setBottomInset(_:animated:duration:)`.
- An initializer whose content builder receives each item's index along with the item.
- `.dismissesKeyboardOnScroll(_:)` to dismiss the keyboard when the list is dragged.
- `.precomputesItemHeights(_:)`. Vertical linear lists now measure each row once per item and width
  and lay out with that height as the estimate, so rows no longer shift as they scroll into view.
  Pass `false` to fall back to uniform estimates for very large data sets.
- `.onLoadMore(pageSize:perform:)`, the labelled form the documentation already showed.
- A default layout of `.linear()` in both initializers.
- `RecyclerViewAdapter.spanSizeLookup`, `precomputesItemHeights` and `measuredHeight(for:at:width:)`.
- DocC documentation, unit tests, an example app and continuous integration.

### Changed

- `RecyclerViewAdapter.content` receives the item's index along with the item. A convenience
  initializer still accepts an `(Item) -> Content` builder.
- `.withoutStatusBar()` without an argument now enables the behaviour. It used to default to `false`.
- Wrap-content lists measure rows the way cells size themselves, so wrapping text and vertical
  spacers no longer produce wrong heights.
- `RecyclerViewLayoutManager` and `RecyclerViewVerticalLayout` conform to `Sendable`.
- The sources are split into one file per type under `Sources/RecyclerView`.

### Fixed

- A crash when an update arrived before the previous update's diff was applied. The next diff was
  measured from items the collection view never received, so its batch update failed UIKit's
  consistency check.
- Rows growing by the height of the status bar as they scrolled beneath it in a list drawn with
  `withoutStatusBar`.
- `withoutStatusBar` having no effect on iOS versions with three components, such as 17.2.1.
- Visible rows keeping stale values when an item changed without changing its `id`.
- Changes to `spanSizeLookup` being ignored until the layout itself changed.
- A grid with a `spanCount` below 1 crashing.

### Removed

- The static `RecyclerView.statusBarHeight`, `navBarHeight` and `displaySize` properties, which could
  not be used without naming the view's generic parameters.
- The public `RecyclerViewCoordinator` type and `UIHostingController.init(rootView:ignoreSafeArea:)`
  extension, which were implementation details.

[Unreleased]: https://github.com/ulvi-vali/recycler-view-for-swiftui/compare/1.0.0...HEAD
[1.0.0]: https://github.com/ulvi-vali/recycler-view-for-swiftui/releases/tag/1.0.0
