import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class RecyclerViewAdapterTests: XCTestCase {
    private func makeAdapter(count: Int, pageSize: Int = 10) -> (UICollectionView, RecyclerViewAdapter<TestItem, Text>) {
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
        let adapter = RecyclerViewAdapter<TestItem, Text>(collectionView: collectionView) { item in
            Text("Row \(item.id)")
        }
        adapter.pageSize = pageSize
        adapter.items = (0..<count).map { TestItem(id: $0) }
        return (collectionView, adapter)
    }

    private func display(_ index: Int, in collectionView: UICollectionView, adapter: RecyclerViewAdapter<TestItem, Text>) {
        adapter.collectionView(collectionView, willDisplay: UICollectionViewCell(), forItemAt: IndexPath(item: index, section: 0))
    }

    func testBecomesTheDataSourceAndDelegate() {
        let (collectionView, adapter) = makeAdapter(count: 3)
        XCTAssertTrue(collectionView.dataSource === adapter)
        XCTAssertTrue(collectionView.delegate === adapter)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 3)
    }

    func testTapReportsIndexAndItem() {
        let (collectionView, adapter) = makeAdapter(count: 3)
        var tapped: [(index: Int, id: Int)] = []
        adapter.onItemClick = { tapped.append(($0, $1.id)) }

        adapter.collectionView(collectionView, didSelectItemAt: IndexPath(item: 2, section: 0))

        XCTAssertEqual(tapped.map(\.index), [2])
        XCTAssertEqual(tapped.map(\.id), [2])
    }

    // MARK: - Pagination

    func testLoadMoreFiresNearTheEndOfAFullPage() {
        let (collectionView, adapter) = makeAdapter(count: 20)
        var requests: [(page: Int, itemCount: Int)] = []
        adapter.onLoadMore = { requests.append(($0, $1)) }

        display(14, in: collectionView, adapter: adapter)
        XCTAssertTrue(requests.isEmpty)

        display(15, in: collectionView, adapter: adapter)
        XCTAssertEqual(requests.map(\.page), [2])
        XCTAssertEqual(requests.map(\.itemCount), [20])
    }

    func testLoadMoreFiresOncePerPage() {
        let (collectionView, adapter) = makeAdapter(count: 20)
        var requestCount = 0
        adapter.onLoadMore = { _, _ in requestCount += 1 }

        for index in 15..<20 {
            display(index, in: collectionView, adapter: adapter)
        }
        XCTAssertEqual(requestCount, 1)
    }

    func testLoadMoreStopsAfterAShortPage() {
        let (collectionView, adapter) = makeAdapter(count: 25)
        var requestCount = 0
        adapter.onLoadMore = { _, _ in requestCount += 1 }

        display(24, in: collectionView, adapter: adapter)
        XCTAssertEqual(requestCount, 0)
    }

    func testLoadMoreRearmsWhenItemsAreAppended() {
        let (collectionView, adapter) = makeAdapter(count: 20)
        var pages: [Int] = []
        adapter.onLoadMore = { page, _ in pages.append(page) }

        display(15, in: collectionView, adapter: adapter)
        adapter.items = (0..<30).map { TestItem(id: $0) }
        display(25, in: collectionView, adapter: adapter)

        XCTAssertEqual(pages, [2, 3])
    }

    // MARK: - Identity

    func testItemsAreIdentifiedByTheirID() {
        let (_, adapter) = makeAdapter(count: 0)
        XCTAssertEqual(adapter.getItemIDString(for: TestItem(id: 42), at: 0), "42")
    }

    func testNilPlaceholdersAreIdentifiedByPosition() {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        let adapter = RecyclerViewAdapter<TestItem?, Text>(collectionView: collectionView) { _ in
            Text("Loading")
        }
        XCTAssertEqual(adapter.getItemIDString(for: nil, at: 3), "placeholder_3")
        XCTAssertNotEqual(adapter.getItemIDString(for: TestItem(id: 7), at: 3), "placeholder_3")
    }

    // MARK: - Measuring

    func testMeasuredHeightsAreCachedPerItemAndWidth() {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        var builds = 0
        let adapter = RecyclerViewAdapter<TestItem, Text>(collectionView: collectionView) { _, item in
            builds += 1
            return Text(item.title)
        }
        let item = TestItem(id: 1, title: "Hello")

        let first = adapter.measuredHeight(for: item, at: 0, width: 320)
        let second = adapter.measuredHeight(for: item, at: 0, width: 320)
        XCTAssertGreaterThan(first, 1)
        XCTAssertEqual(first, second)
        XCTAssertEqual(builds, 1)

        _ = adapter.measuredHeight(for: item, at: 0, width: 200)
        XCTAssertEqual(builds, 2)
    }
}
