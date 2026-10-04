# Migrating from 1.x

Update code written for RecyclerView 1.x to version 2.0.

## Overview

Version 2.0 builds in the Swift 6 language mode, replaces the `Optional: Identifiable` conformance
with ``RecyclerViewItem``, scopes keyboard dismissal to the list, and sizes wrap-content lists by
the space their container proposes. The minimum deployment target stays iOS 13. Most apps only need
Xcode 16 and, if they pass arrays of optionals, a look at their callbacks.

### Build with Xcode 16

The package uses swift-tools-version 6.0 and the Swift 6 language mode. Apps in the Swift 5
language mode can still use it. ``RecyclerViewAdapter``, ``RecyclerViewController`` and
``ViewHolder`` are `@MainActor`.

### Arrays of optionals

1.x made `Optional` conform to `Identifiable` so that an array of optionals could show placeholder
rows. A conformance of a standard library type to a standard library protocol clashes with any
other module that declares the same one, so 2.0 removes it.

Passing `[Value?]` still compiles: ``RecyclerView/RecyclerView`` has initializers that wrap each
element in ``RecyclerViewItem`` and hand the row builder the optional back. Callbacks that receive
items, such as ``RecyclerView/RecyclerView/onItemClick(_:)`` and
``RecyclerView/RecyclerView/spanSizeLookup(_:)``, now receive the ``RecyclerViewItem``:

```swift
RecyclerView(data: articlesOrNil) { article in      // unchanged
    if let article = article { ArticleRow(article: article) } else { ArticleRow.skeleton }
}
.onItemClick { _, item in                            // was: { _, article in ... }
    if let article = item.value { open(article) }
}
```

A type written as `RecyclerView<Article?, Row>` becomes `RecyclerView<RecyclerViewItem<Article>, Row>`.
For new code, build the items yourself with ``RecyclerViewItem/placeholders(count:)`` and
``RecyclerViewItem/value(_:)``.

### Keyboard dismissal

`dismissesKeyboardOnScroll()` used to end editing in the whole window. It now ends editing only in
text input inside the list. When the text input sits outside the list, as a search field or a chat
composer does, pass ``RecyclerViewKeyboardDismissal/window``:

```swift
.dismissesKeyboardOnScroll(.window)
```

### Wrap-content heights

Wrap-content lists used to be measured at the screen's width and capped at the screen's height less
fixed allowances for a navigation bar, a header and margins. They are now measured at the width
their container proposes and capped at the height it proposes. Inside a container that proposes no
height, such as a vertical `ScrollView`, a wrap-content list grows to show all of its rows; give it
a frame to bound it. Horizontal wrap-content lists no longer add 15 points below their tallest item.

### Bottom insets in reversed lists

``RecyclerViewController/setBottomInset(_:animated:duration:)`` and
``RecyclerViewController/setContentInsets(_:animated:duration:)`` follow the edges of the screen,
including in lists flipped by ``RecyclerView/RecyclerView/stackFromEnd(_:)`` or
``RecyclerView/RecyclerView/reverseLayout(_:)``. A workaround that passed a top inset to reach the
bottom of a reversed list should pass the bottom inset instead.
