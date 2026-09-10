import RecyclerView
import SwiftUI

struct VerticalListDemo: View {
    @State private var articles = SampleData.articles(count: 60)
    @State private var nextID = 60
    @State private var status = "Tap a row"

    var body: some View {
        RecyclerView(data: articles, layout: .linear(spacing: 12)) { article in
            ArticleRow(article: article)
        }
        .onItemClick { index, article in
            status = "Tapped row \(index): \(article.title)"
        }
        .showsScrollIndicator(true)
        .verticalLayout(.matchParent)
        .safeAreaInset(edge: .bottom) {
            Text(status)
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Remove") {
                    if !articles.isEmpty {
                        articles.remove(at: 0)
                    }
                }
                Button("Insert") {
                    articles.insert(contentsOf: SampleData.articles(count: 1, startingAt: nextID), at: 0)
                    nextID += 1
                }
            }
        }
    }
}
