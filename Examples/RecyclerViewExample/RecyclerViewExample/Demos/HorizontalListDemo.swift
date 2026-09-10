import RecyclerView
import SwiftUI

struct HorizontalListDemo: View {
    private struct Category: Identifiable {
        let id: Int
        let title: String
    }

    private let categories = ["All", "Breakfast", "Burgers", "Pizza", "Sushi", "Salads", "Desserts", "Coffee", "Juices", "Vegan"]
        .enumerated()
        .map { Category(id: $0.offset, title: $0.element) }

    @State private var chipsController = RecyclerViewController()
    @State private var selected = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Categories")
                    .font(.headline)
                    .padding(.horizontal)

                RecyclerView(data: categories, layout: .linear(orientation: .horizontal, spacing: 8)) { index, category in
                    Chip(title: category.title, isSelected: index == selected)
                }
                .onItemClick { index, _ in
                    selected = index
                    // Keep the chosen chip in view, with part of the previous one showing.
                    chipsController.scrollToItem(at: index, topOffset: 48)
                }
                .controller(chipsController)
                .verticalLayout(.matchParent)
                .frame(height: 52)

                Text("Featured")
                    .font(.headline)
                    .padding(.horizontal)

                // Wrap content: the list is as tall as its tallest card.
                RecyclerView(data: SampleData.articles(count: 12), layout: .linear(orientation: .horizontal, spacing: 12)) { article in
                    FeaturedCard(article: article)
                }
            }
            .padding(.vertical)
        }
    }
}
