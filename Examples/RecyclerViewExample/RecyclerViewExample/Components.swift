import SwiftUI

struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(article.color.gradient)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ProductCard: View {
    let name: String
    let price: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.25))
                .frame(height: 110)
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
            Text(price)
                .font(.caption.bold())
        }
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FeaturedCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(article.color.gradient)
                .frame(width: 140, height: 90)
            Text(article.title)
                .font(.subheadline.weight(.semibold))
            Text("\(article.id + 3) min read")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, alignment: .leading)
    }
}

struct Chip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12), in: Capsule())
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isMine {
                Spacer(minLength: 48)
            }
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(message.isMine ? Color.white : Color.primary)
                .background(
                    message.isMine ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            if !message.isMine {
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal, 12)
    }
}

struct MenuRowView: View {
    let row: MenuRow

    var body: some View {
        if row.isHeader {
            Text(row.title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 20, leading: 16, bottom: 8, trailing: 16))
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                    Text("Freshly made, serves one")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("$\(8 + row.id % 7)")
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
