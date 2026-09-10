# Getting Started with RecyclerView

Display a list, choose a layout, and respond to taps, scrolling and pagination.

## Overview

A ``RecyclerView/RecyclerView`` takes an array of `Identifiable` items and a view builder for a row.
Identities matter: when the array changes, items are matched by `id`, and insertions and removals
are applied as batch updates instead of reloading the list.

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

By default a list sizes itself to its rows, like Android's `wrap_content`. A list that is the main
content of a screen should fill its container instead, with
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
.dismissesKeyboardOnScroll()
.verticalLayout(.matchParent)
```

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
