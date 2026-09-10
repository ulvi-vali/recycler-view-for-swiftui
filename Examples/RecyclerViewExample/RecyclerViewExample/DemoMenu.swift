import SwiftUI

enum Demo: String, CaseIterable, Identifiable, Hashable {
    case verticalList
    case grid
    case horizontalList
    case pagination
    case chat
    case scrollController

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verticalList: return "Vertical list"
        case .grid: return "Grid with spans"
        case .horizontalList: return "Horizontal lists"
        case .pagination: return "Pagination"
        case .chat: return "Chat"
        case .scrollController: return "Scroll controller"
        }
    }

    var subtitle: String {
        switch self {
        case .verticalList: return "Measured rows, taps, animated inserts and removals"
        case .grid: return "spanSizeLookup for full-width headers and banners"
        case .horizontalList: return "Chips kept in view by a controller, wrap-content cards"
        case .pagination: return "onLoadMore, ending on a short page"
        case .chat: return "stackFromEnd and dismissesKeyboardOnScroll"
        case .scrollController: return "Section tabs following the list, a floating bottom bar"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .verticalList: VerticalListDemo()
        case .grid: GridDemo()
        case .horizontalList: HorizontalListDemo()
        case .pagination: PaginationDemo()
        case .chat: ChatDemo()
        case .scrollController: ScrollControllerDemo()
        }
    }
}

/// Lists the demos. Launch with `-demo <name>`, for example `-demo grid`, to open one directly.
struct DemoMenu: View {
    @State private var path: [Demo] = UserDefaults.standard.string(forKey: "demo")
        .flatMap(Demo.init(rawValue:))
        .map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            List(Demo.allCases) { demo in
                NavigationLink(value: demo) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(demo.title)
                        Text(demo.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("RecyclerView")
            .navigationDestination(for: Demo.self) { demo in
                demo.destination
                    .navigationTitle(demo.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
