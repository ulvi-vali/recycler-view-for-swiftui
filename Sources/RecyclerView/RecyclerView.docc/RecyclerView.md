# ``RecyclerView``

A `UICollectionView`-backed list for SwiftUI, modelled on Android's RecyclerView.

## Overview

RecyclerView brings the strengths of `UICollectionView` to SwiftUI: cells are reused, each row sizes
itself to its SwiftUI content, and updates are applied as animated batch updates matched by item
identity, moves included. On top of that it offers the parts of Android's `RecyclerView` that
SwiftUI lists lack: grids whose items span several columns, lists anchored to the bottom for chat, a
pagination callback, separators, placeholder rows, and a controller for scrolling to a row, setting
content insets and finding the row under a point on screen. Wrap-content lists size themselves by
the space their container proposes, so they fit any container.

```swift
import RecyclerView
import SwiftUI

struct ArticlesScreen: View {
    @ObservedObject var model: ArticlesModel

    var body: some View {
        RecyclerView(data: model.articles, layout: .linear(spacing: 12)) { article in
            ArticleRow(article: article)
        }
        .onItemClick { _, article in
            model.open(article)
        }
        .onLoadMore(pageSize: 20) { page, _ in
            model.loadPage(page)
        }
        .verticalLayout(.matchParent)
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:MigratingFrom1x>
- ``RecyclerView/RecyclerView``
- ``RecyclerViewLayoutManager``
- ``RecyclerViewVerticalLayout``

### Appearance and behaviour

- ``RecyclerViewSeparator``
- ``RecyclerViewKeyboardDismissal``
- ``RecyclerViewItem``

### Scrolling programmatically

- ``RecyclerViewController``

### Showing SwiftUI rows in UIKit

- ``RecyclerViewAdapter``
- ``ViewHolder``
- ``UIRecyclerView``
