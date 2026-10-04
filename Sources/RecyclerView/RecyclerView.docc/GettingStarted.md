# Getting Started with RecyclerView

Display a list, choose a layout, and respond to taps, scrolling and pagination.

## Overview

A ``RecyclerView/RecyclerView`` takes an array of `Identifiable` items and a view builder for a row.
Identities matter: when the array changes, items are matched by `id`, and insertions, removals and
moves are applied as batch updates instead of reloading the list. A reordered item keeps its cell
and animates to its new position.

### Display a list

```swift
struct Contact: Identifiable {
    let id: UUID
    let name: String
}

struct ContactsScreen: View {
    let contacts: [Contact]

    var body: some View {
        RecyclerView(data: contacts) { contact in
            Text(contact.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .verticalLayout(.matchParent)
    }
}
```

By default a list sizes itself to its rows, like Android's `wrap_content`. The rows are measured at
the width the container proposes, and the list grows no taller than the height the container
proposes, so it fits any container without assumptions about the window or the bars around it. A
list that is the main content of a screen should fill its container instead, with
``RecyclerView/RecyclerView/verticalLayout(_:)`` set to ``RecyclerViewVerticalLayout/matchParent``.

> Important: The modifiers declared on ``RecyclerView/RecyclerView`` return a `RecyclerView`. Apply
> them before general SwiftUI modifiers such as `padding(_:)` or `frame(width:height:)`.

### Choose a layout

``RecyclerViewLayoutManager`` describes the arrangement:

```swift
RecyclerView(data: contacts, layout: .linear(spacing: 8)) { ... }                  // vertical list
RecyclerView(data: tags, layout: .linear(orientation: .horizontal, spacing: 8)) { ... } // horizontal list
RecyclerView(data: photos, layout: .grid(spanCount: 3, spacing: 2)) { ... }         // three-column grid
```

In a vertical grid, ``RecyclerView/RecyclerView/spanSizeLookup(_:)`` lets an item span several
columns, which suits section headers and banners:

```swift
RecyclerView(data: feed, layout: .grid(spanCount: 2, spacing: 12)) { item in
    FeedCell(item: item)
}
.spanSizeLookup { item in item.isHeader ? 2 : 1 }
```

### Respond to taps and load more

```swift
RecyclerView(data: model.articles) { article in
    ArticleRow(article: article)
}
.onItemClick { index, article in
    model.open(article)
}
.onLoadMore(pageSize: 20) { page, itemCount in
    model.loadPage(page)
}
```

The pagination callback fires as one of the last five rows appears, provided the item count is a
multiple of the page size, and only once per page. A final page with fewer items ends pagination.

### Anchor a conversation to the bottom

Use ``RecyclerView/RecyclerView/stackFromEnd(_:)`` when messages are ordered oldest first. The list
starts at the newest message, and a short conversation rests against the bottom edge:

```swift
RecyclerView(data: messages, layout: .linear(spacing: 6)) { message in
    MessageBubble(message: message)
}
.stackFromEnd(true)
.dismissesKeyboardOnScroll(.window) // the composer is outside the list
.verticalLayout(.matchParent)
```

``RecyclerView/RecyclerView/dismissesKeyboardOnScroll(_:)-(Bool)`` without an argument only ends
editing in text fields inside the list. Pass ``RecyclerViewKeyboardDismissal/window`` when the text
input sits outside it, as a chat composer or a search field does.

When messages are ordered newest first, use ``RecyclerView/RecyclerView/reverseLayout(_:)`` instead.

### Scroll from elsewhere on screen

Keep a ``RecyclerViewController`` alongside the view and attach it with
``RecyclerView/RecyclerView/controller(_:)``:

```swift
struct MenuScreen: View {
    @State private var controller = RecyclerViewController()
    let rows: [MenuRow]

    var body: some View {
        RecyclerView(data: rows) { row in
            MenuRowView(row: row)
        }
        .controller(controller)
        .verticalLayout(.matchParent)
        .toolbar {
            Button("Desserts") {
                if let index = rows.firstIndex(where: \.isDessertsHeader) {
                    controller.scrollToItem(at: index, topOffset: 8)
                }
            }
        }
    }
}
```

The controller also sets content insets, so that bars floating over the list do not hide its first
and last rows. ``RecyclerViewController/setContentInsets(_:animated:duration:)`` insets every edge
and the scroll indicators with it; edges follow the screen, even in a reversed list:

```swift
controller.setContentInsets(UIEdgeInsets(top: 56, left: 0, bottom: 72, right: 0), animated: true)
```

### Separate rows

Linear lists have no separators by default.
``RecyclerView/RecyclerView/separator(color:thickness:insets:drawAfterLast:)`` draws a line between
rows, and after the last row only when asked. Separators take no space, so rows are measured the same
with or without them:

```swift
RecyclerView(data: contacts) { contact in
    ContactRow(contact: contact)
}
.separator(insets: EdgeInsets(top: 0, leading: 72, bottom: 0, trailing: 0))
```

### Show placeholders while content loads

Wrap items in ``RecyclerViewItem`` to mix loaded values with placeholder rows. Each placeholder has
an identity of its own, so replacing placeholders with values animates like any other update:

```swift
let rows: [RecyclerViewItem<Article>] = model.isLoading
    ? RecyclerViewItem.placeholders(count: 6)
    : model.articles.map(RecyclerViewItem.value)

RecyclerView(data: rows) { row in
    switch row {
    case .value(let article): ArticleRow(article: article)
    case .placeholder: ArticleRow.skeleton
    }
}
```

An array of optionals works as well: each `nil` becomes a placeholder, and the row builder receives
the optional.

### Reorder rows

Items are matched by `id`, so sorting or reordering `data` moves the rows: they keep their cells and
animate to their new positions, in the same batch update as any insertions and removals. When the
item type is `Equatable`, an item that keeps its `id` but changes is measured again, so its row takes
its new height.
