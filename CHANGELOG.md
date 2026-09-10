# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
