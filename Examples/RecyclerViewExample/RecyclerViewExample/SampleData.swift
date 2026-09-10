import SwiftUI

struct Article: Identifiable, Hashable {
    let id: Int
    let title: String
    let summary: String
    let color: Color
}

struct Message: Identifiable {
    let id: Int
    let text: String
    let isMine: Bool
}

struct MenuRow: Identifiable {
    let id: Int
    let section: Int
    let title: String
    let isHeader: Bool
}

enum FeedItem: Identifiable {
    case header(id: Int, title: String)
    case banner(id: Int, title: String, color: Color)
    case product(id: Int, name: String, price: String, color: Color)

    var id: Int {
        switch self {
        case .header(let id, _), .banner(let id, _, _), .product(let id, _, _, _):
            return id
        }
    }
}

enum SampleData {
    static let colors: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .indigo, .red]

    private static let summaries = [
        "A short one.",
        "Rows can hold as much text as they need. Each row is measured, so the list does not jump while you scroll.",
        "Two lines of text make a medium-sized row.",
        "Cells are reused by the underlying UICollectionView, so memory stays flat with thousands of rows. On iOS 16 and later SwiftUI content is hosted with UIHostingConfiguration.",
    ]

    static func articles(count: Int, startingAt start: Int = 0) -> [Article] {
        (start..<start + count).map { index in
            Article(
                id: index,
                title: "Article \(index + 1)",
                summary: summaries[index % summaries.count],
                color: colors[index % colors.count]
            )
        }
    }

    private static let chatLines = [
        "Hey! Are we still on for tonight?",
        "Yes, 8pm works for me.",
        "Great, I'll book a table.",
        "Can you send me the address?",
        "Sure. It's the place next to the old cinema, the one with the green door and the long queue outside.",
        "👍",
    ]

    static let messages: [Message] = (0..<30).map { index in
        Message(id: index, text: chatLines[index % chatLines.count], isMine: index % 3 == 1)
    }

    static let menuSections = ["Starters", "Soups", "Mains", "Desserts", "Drinks"]

    static let menu: [MenuRow] = {
        var rows: [MenuRow] = []
        for (section, title) in menuSections.enumerated() {
            rows.append(MenuRow(id: rows.count, section: section, title: title, isHeader: true))
            for dish in 1...6 {
                rows.append(MenuRow(id: rows.count, section: section, title: "\(title.dropLast()) \(dish)", isHeader: false))
            }
        }
        return rows
    }()

    static let feed: [FeedItem] = {
        let products = ["Wireless headphones", "Smart watch", "Mechanical keyboard", "Gaming mouse", "4K monitor", "USB-C hub"]
        var items: [FeedItem] = [
            .header(id: 0, title: "Exclusive offers"),
            .banner(id: 1, title: "Summer sale: up to 50% off", color: .orange),
            .header(id: 2, title: "Popular products"),
        ]
        for (offset, name) in products.enumerated() {
            items.append(.product(id: 10 + offset, name: name, price: "$\(40 + offset * 15)", color: colors[offset % colors.count]))
        }
        items.append(.banner(id: 100, title: "Free shipping this week", color: .green))
        items.append(.header(id: 101, title: "Recently viewed"))
        for (offset, name) in products.reversed().enumerated() {
            items.append(.product(id: 200 + offset, name: name, price: "$\(35 + offset * 10)", color: colors[(offset + 3) % colors.count]))
        }
        return items
    }()
}
