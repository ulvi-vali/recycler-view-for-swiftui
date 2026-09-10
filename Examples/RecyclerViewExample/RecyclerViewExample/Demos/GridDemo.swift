import RecyclerView
import SwiftUI

struct GridDemo: View {
    private let feed = SampleData.feed

    var body: some View {
        RecyclerView(data: feed, layout: .grid(spanCount: 2, spacing: 12)) { item in
            switch item {
            case .header(_, let title):
                Text(title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

            case .banner(_, let title, let color):
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            case .product(_, let name, let price, let color):
                ProductCard(name: name, price: price, color: color)
            }
        }
        .spanSizeLookup { item in
            if case .product = item {
                return 1
            }
            return 2
        }
        .verticalLayout(.matchParent)
        .padding(.horizontal, 16)
    }
}
