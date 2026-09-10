import RecyclerView
import SwiftUI

struct ScrollControllerDemo: View {
    private struct MenuSection: Identifiable {
        let id: Int
        let title: String
    }

    private static let basketHeight: CGFloat = 64

    private let rows = SampleData.menu
    private let sections = SampleData.menuSections
        .enumerated()
        .map { MenuSection(id: $0.offset, title: $0.element) }

    @State private var menuController = RecyclerViewController()
    @State private var tabsController = RecyclerViewController()
    @State private var selectedSection = 0
    @State private var listTop: CGFloat = 0
    @State private var showsBasket = false

    var body: some View {
        VStack(spacing: 0) {
            RecyclerView(data: sections, layout: .linear(orientation: .horizontal, spacing: 8)) { index, section in
                Chip(title: section.title, isSelected: index == selectedSection)
            }
            .onItemClick { index, _ in
                select(index)
            }
            .controller(tabsController)
            .verticalLayout(.matchParent)
            .frame(height: 52)

            Divider()

            RecyclerView(data: rows) { row in
                MenuRowView(row: row)
            }
            .controller(menuController)
            .onScroll { _ in
                followScroll()
            }
            .verticalLayout(.matchParent)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { listTop = proxy.frame(in: .global).minY }
                        .onChange(of: proxy.frame(in: .global).minY) { listTop = $0 }
                }
            )
        }
        .overlay(alignment: .bottom) {
            if showsBasket {
                basketBar
                    .transition(.move(edge: .bottom))
            }
        }
        .toolbar {
            Button(showsBasket ? "Hide basket" : "Show basket", action: toggleBasket)
        }
        .onChange(of: selectedSection) { section in
            tabsController.scrollToItem(at: section, topOffset: 48)
        }
    }

    private var basketBar: some View {
        HStack {
            Text("3 items")
            Spacer()
            Text("Checkout")
                .bold()
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .frame(height: Self.basketHeight)
        .background(Color.accentColor.opacity(0.92))
    }

    private func toggleBasket() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showsBasket.toggle()
        }
        // The bar floats over the list: rather than shrinking, the list gains room to scroll the
        // last rows clear of it, moving in step with the bar.
        menuController.setBottomInset(showsBasket ? Self.basketHeight : 0, animated: true, duration: 0.3)
    }

    private func select(_ section: Int) {
        selectedSection = section
        guard let index = rows.firstIndex(where: { $0.isHeader && $0.section == section }) else { return }
        menuController.scrollToItem(at: index)
    }

    /// Highlights the section at the top of the list, but only while the user is scrolling, so that a
    /// tapped tab is not overridden by the rows the list passes on its way there.
    private func followScroll() {
        guard menuController.isUserScrolling,
              let index = menuController.indexOfItem(atScreenY: listTop + 1),
              rows[index].section != selectedSection
        else { return }
        selectedSection = rows[index].section
    }
}
