import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class PlaceholderTests: XCTestCase {
    // MARK: - RecyclerViewItem

    func testValuesKeepTheirIdentityAndPlaceholdersUseTheirSlot() {
        XCTAssertEqual(RecyclerViewItem.value(TestItem(id: 5)).id, .value(5))
        XCTAssertEqual(RecyclerViewItem<TestItem>.placeholder(5).id, .placeholder(5))
        XCTAssertNotEqual(RecyclerViewItem.value(TestItem(id: 5)).id, RecyclerViewItem<TestItem>.placeholder(5).id)
    }

    func testValueAndIsPlaceholder() {
        let value = RecyclerViewItem.value(TestItem(id: 1, title: "One"))
        let placeholder = RecyclerViewItem<TestItem>.placeholder(0)
        XCTAssertEqual(value.value?.title, "One")
        XCTAssertFalse(value.isPlaceholder)
        XCTAssertNil(placeholder.value)
        XCTAssertTrue(placeholder.isPlaceholder)
    }

    func testPlaceholdersFillSlotsInOrder() {
        XCTAssertEqual(RecyclerViewItem<TestItem>.placeholders(count: 3).map(\.id), [.placeholder(0), .placeholder(1), .placeholder(2)])
        XCTAssertTrue(RecyclerViewItem<TestItem>.placeholders(count: -1).isEmpty)
    }

    func testOptionalsBecomeValuesAndPlaceholdersByPosition() {
        let items = RecyclerViewItem.items(from: [TestItem(id: 7), nil, TestItem(id: 9), nil])
        XCTAssertEqual(items.map(\.id), [.value(7), .placeholder(1), .value(9), .placeholder(3)])
        XCTAssertEqual(items[0], .value(TestItem(id: 7)))
    }

    // MARK: - RecyclerView

    private typealias List = RecyclerView<RecyclerViewItem<TestItem>, Text>

    private func makeList(_ data: [TestItem?]) -> List {
        RecyclerView(data: data) { (item: TestItem?) in
            Text(item?.title ?? "Loading")
        }
        .withAnimation(false)
        .verticalLayout(.matchParent)
    }

    private func host(_ list: List) throws -> (UIWindow, UIHostingController<List>, UIRecyclerView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hostingController = UIHostingController(rootView: list)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
        return (window, hostingController, collectionView)
    }

    func testOptionalDataShowsPlaceholderRows() throws {
        let (_, _, collectionView) = try host(makeList([nil, nil, nil]))
        let adapter = try XCTUnwrap(collectionView.dataSource as? RecyclerViewAdapter<RecyclerViewItem<TestItem>, Text>)
        XCTAssertEqual(collectionView.numberOfItems(inSection: 0), 3)
        XCTAssertTrue(adapter.items.allSatisfy(\.isPlaceholder))
    }

    func testPlaceholdersAreReplacedByLoadedValues() throws {
        let (_, hostingController, collectionView) = try host(makeList([nil, nil, nil]))
        let adapter = try XCTUnwrap(collectionView.dataSource as? RecyclerViewAdapter<RecyclerViewItem<TestItem>, Text>)

        let loaded = (1...5).map { TestItem(id: $0, title: "Row \($0)") }
        hostingController.rootView = makeList(loaded)

        XCTAssertTrue(waitUntil { adapter.items.compactMap(\.value) == loaded && collectionView.numberOfItems(inSection: 0) == 5 })
        XCTAssertFalse(adapter.items.contains(where: \.isPlaceholder))
    }

    func testRowBuilderReceivesTheOptionalBack() throws {
        var received: [Int: TestItem?] = [:]
        func record(_ index: Int, _ item: TestItem?) -> String {
            received[index] = item
            return item?.title ?? "Loading"
        }
        let list = RecyclerView(data: [TestItem(id: 1, title: "One"), nil]) { index, item in
            Text(record(index, item))
        }
        .verticalLayout(.matchParent)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hostingController = UIHostingController(rootView: list)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()

        XCTAssertEqual(received[0], .some(TestItem(id: 1, title: "One")))
        XCTAssertEqual(received[1], .some(nil))
    }

    func testNonOptionalDataStillUsesTheItemsThemselves() {
        // An array of values picks the plain initializer, so Item is the value type itself.
        let list = RecyclerView(data: [TestItem(id: 1)]) { item in
            Text(item.title)
        }
        XCTAssertTrue(type(of: list) == RecyclerView<TestItem, Text>.self)
    }
}
