import RecyclerView
import SwiftUI

struct PaginationDemo: View {
    private static let pageSize = 20
    private static let pageCount = 5

    @State private var articles = SampleData.articles(count: PaginationDemo.pageSize)
    @State private var isLoading = false

    var body: some View {
        RecyclerView(data: articles) { article in
            ArticleRow(article: article)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .onLoadMore(pageSize: Self.pageSize) { page, itemCount in
            loadPage(page, after: itemCount)
        }
        .verticalLayout(.matchParent)
        .safeAreaInset(edge: .bottom) {
            Text(isLoading ? "Loading more…" : "\(articles.count) articles")
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.bar)
        }
    }

    private func loadPage(_ page: Int, after itemCount: Int) {
        guard !isLoading else { return }
        isLoading = true

        // Stands in for a network request. The last page comes back short, which ends pagination.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let count = page == Self.pageCount - 1 ? 7 : Self.pageSize
            articles += SampleData.articles(count: count, startingAt: itemCount)
            isLoading = false
        }
    }
}
