# RecyclerView for SwiftUI

`RecyclerView` is a highly optimized custom component designed for **SwiftUI** projects that leverages the power, flexibility, and performance of **UIKit's** `UICollectionView`. It serves as a superior alternative to standard SwiftUI `List` or `ScrollView` + `LazyVStack` configurations, especially when dealing with complex behaviors.

It is the perfect solution for large datasets, dynamic cell heights, heterogeneous Grid or Linear layouts, infinite scrolling (pagination), and reversed list alignments (`reverseLayout` / `stackFromEnd`).

## Features

* ⚡ **High Performance:** Implements cell reuse natively by integrating `UICollectionView` and `UIHostingController`.
* 📐 **Dynamic Cell Height:** Automatically calculates heights based on the intrinsic size of the embedded SwiftUI views.
* 🔀 **Layout Managers:** Switch between a single-row linear view (`linear` - vertical or horizontal) or a multi-column grid (`grid`) with a single line of code.
* 🔄 **Reverse Layout Support:** Ideal for Chat applications, offering robust support for `reverseLayout` and `stackFromEnd`.
* 📈 **Infinite Scrolling (Pagination):** Equipped with an intelligent `onLoadMore` mechanism that triggers data fetching efficiently before reaching the end of the list.
* 📱 **Wrap Content Support:** Capable of dynamically adjusting its own frame height based on the total height of its items (`calculateWrapHeight`).
* 🛠️ **iOS 16+ Optimization:** Utilizes native `UIHostingConfiguration` for enhanced performance when running on iOS 16 and above.

## Installation

### Swift Package Manager (SPM)

You can add this package as a dependency to your project via `Package.swift` or directly within Xcode using the repository URL:

```swift
dependencies: [
    .package(url: "https://github.com/ulvi-vali/recycler-view-for-swiftui.git", from: "1.0.0")
]

```

## Usage Guide

### 1. Simple Vertical List (Linear Vertical)

```swift
import SwiftUI

struct ItemModel: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

struct ExampleView: View {
    @State private var items = (1...100).map { ItemModel(title: "Title \($0)", description: "Description details go here...") }
    
    var body: some View {
        RecyclerView(data: items, layout: .linear(orientation: .vertical, spacing: 10)) { item in
            VCornerCard(item: item)
        }
        .onItemClick { index, item in
            print("Clicked: \(item.title) at index: \(index)")
        }
    }
}

struct VCornerCard: View {
    let item: ItemModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.headline)
            Text(item.description).font(.subheadline).foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
}

```

### 2. Grid Layout with Span Size Lookup

`spanSizeLookup` allows you to create heterogeneous grid structures where different items span a different number of columns. This is perfect for dashboards, feed streams, or e-commerce categories where you want to mix banners, full-width headers, and double-column product items inside a single grid layout.

#### Dynamic Spans with Enum-based Feed

Here is an example demonstrating how to build a grid with a `spanCount` of 4, where headers occupy the full width (4 spans), banners occupy 4 spans, and standard products occupy 2 spans (creating a 2-column look):

```swift
import SwiftUI

enum FeedItem: Identifiable {
    case header(id: UUID, title: String)
    case promoBanner(id: UUID, imageColor: Color, title: String)
    case product(id: UUID, name: String, price: String)
    
    var id: UUID {
        switch self {
        case .header(let id, _): return id
        case .promoBanner(let id, _, _): return id
        case .product(let id, _, _): return id
        }
    }
}

struct DashboardView: View {
    @State private var feedItems: [FeedItem] = [
        .header(id: UUID(), title: "Exclusive Offers"),
        .promoBanner(id: UUID(), imageColor: .orange, title: "Summer Sale! Up to 50% Off"),
        .header(id: UUID(), title: "Popular Products"),
        .product(id: UUID(), name: "Wireless Headphones", price: "$99"),
        .product(id: UUID(), name: "Smart Watch", price: "$199"),
        .product(id: UUID(), name: "Mechanical Keyboard", price: "$120"),
        .product(id: UUID(), name: "Gaming Mouse", price: "$60")
    ]
    
    var body: some View {
        RecyclerView(data: feedItems, layout: .grid(spanCount: 4, spacing: 12, orientation: .vertical)) { item in
            switch item {
            case .header(_, let title):
                Text(title)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                
            case .promoBanner(_, let color, let title):
                VStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(color)
                .cornerRadius(12)
                
            case .product(_, let name, let price):
                VStack(alignment: .leading, spacing: 6) {
                    Color.gray.opacity(0.2)
                        .frame(height: 120)
                        .cornerRadius(8)
                    Text(name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(price)
                        .font(.caption)
                        .bold()
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        .spanSizeLookup { item in
            switch item {
            case .header:
                return 4
            case .promoBanner:
                return 4
            case .product:
                return 2
            }
        }
        .padding(.horizontal)
    }
}

```

### 3. Infinite Scroll (Load More / Pagination)

Implement the `onLoadMore` modifier to seamlessly load new items as the user scrolls down:

```swift
RecyclerView(data: items, layout: .linear(orientation: .vertical, spacing: 8)) { item in
    Text(item.title)
}
.onLoadMore(pageSize: 20) { page, totalItemCount in
    print("Loading page: \(page). Total items currently: \(totalItemCount)")
}

```

### 4. Reverse & Stack From End for Chat Layouts

To build chat feeds where messages flow from the bottom up and the viewport initializes at the bottom:

```swift
RecyclerView(data: messages, layout: .linear(orientation: .vertical, spacing: 8)) { message in
    MessageBubble(message: message)
}
.reverseLayout(true)
.stackFromEnd(true)

```

## Configuration API (Modifiers)

The `RecyclerView` component provides fluid chaining methods for precise configuration:

| Modifier | Type | Description |
| --- | --- | --- |
| `.onItemClick((Int, Item) -> Void)` | Closure | Triggered when an item in the list is selected. |
| `.onLoadMore(pageSize: Int, (Int, Int) -> Void)` | Closure | Sets page limit and provides callbacks for triggering pagination. |
| `.spanSizeLookup((Item) -> Int)` | Closure | Defines how many column spans an item should occupy in Grid mode. |
| `.showsScrollIndicator(Bool)` | Boolean | Toggles visibility of the vertical or horizontal scroll indicator. |
| `.reverseLayout(Bool)` | Boolean | Flips the visual rendering and scroll mechanics of the list. |
| `.stackFromEnd(Bool)` | Boolean | Begins filling the layout from the bottom/end of the container. |
| `.verticalLayout(RecyclerViewVerticalLayout)` | Enum | Choose between `.wrapContent` (calculates total size) or `.matchParent` (fills screen bounds). |
| `.withAnimation(Bool)` | Boolean | Controls whether incremental data changes should be animated. |
| `.onScroll((CGPoint) -> Void)` | Closure | Provides real-time stream of content offset adjustments. |

## Requirements

* iOS 13.0+ (with native underlying optimizations for iOS 16+)
* Xcode 11+
* Swift 5.5+

## License

This project is available under the MIT License. Feel free to use, modify, and distribute it in your applications.
