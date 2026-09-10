import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class RecyclerViewUpdateTests: XCTestCase {
    private typealias List = RecyclerView<TestItem, Text>

    @MainActor
    private struct Hosted {
        let window: UIWindow
        let hostingController: UIHostingController<List>
        let collectionView: UIRecyclerView

        func update(to list: List) {
            hostingController.rootView = list
            hostingController.view.layoutIfNeeded()
        }
    }

    private func makeList(_ items: [TestItem]) -> List {
        RecyclerView(data: items) { item in
            Text(item.title)
        }
        .withAnimation(false)
        .verticalLayout(.matchParent)
    }

    private func makeList(ids: [Int]) -> List {
        makeList(ids.map { TestItem(id: $0, title: "Row \($0)") })
    }

    private func host(_ list: List) throws -> Hosted {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hostingController = UIHostingController(rootView: list)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()

        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
        return Hosted(window: window, hostingController: hostingController, collectionView: collectionView)
    }

    func testShowsTheInitialItems() throws {
        let hosted = try host(makeList(ids: Array(0..<10)))
        XCTAssertEqual(hosted.collectionView.numberOfItems(inSection: 0), 10)

        hosted.collectionView.layoutIfNeeded()
        XCTAssertFalse(hosted.collectionView.visibleCells.isEmpty)
    }

    /// Updates can arrive faster than their diffs are applied. Each diff has to be measured from what
    /// the collection view actually holds, or its batch update fails UIKit's consistency check.
    func testRapidUpdatesSettleOnTheLatestData() throws {
        let hosted = try host(makeList(ids: Array(0..<10)))
        XCTAssertEqual(hosted.collectionView.numberOfItems(inSection: 0), 10)

        hosted.update(to: makeList(ids: Array(0..<20)))
        hosted.update(to: makeList(ids: Array(5..<30)))
        hosted.update(to: makeList(ids: [1, 2, 3]))
        let settled = waitUntil { hosted.collectionView.numberOfItems(inSection: 0) == 3 }
        XCTAssertTrue(settled)

        hosted.update(to: makeList(ids: [1, 2, 3, 4]))
        let settledAgain = waitUntil { hosted.collectionView.numberOfItems(inSection: 0) == 4 }
        XCTAssertTrue(settledAgain)
    }

    func testChangedValuesWithTheSameIdentityReachTheList() throws {
        let hosted = try host(makeList([TestItem(id: 1, title: "Before")]))
        let adapter = try XCTUnwrap(hosted.collectionView.dataSource as? RecyclerViewAdapter<TestItem, Text>)

        hosted.update(to: makeList([TestItem(id: 1, title: "After")]))

        let updated = waitUntil { adapter.items.map(\.title) == ["After"] }
        XCTAssertTrue(updated)
    }

    func testStackFromEndReportsTapsByIndexInData() throws {
        let data = [TestItem(id: 10), TestItem(id: 20), TestItem(id: 30)]
        var tapped: [(index: Int, id: Int)] = []
        let list = makeList(data)
            .stackFromEnd(true)
            .onItemClick { index, item in tapped.append((index, item.id)) }
        let hosted = try host(list)
        let collectionView = hosted.collectionView

        // The first displayed row of a list stacked from the end is the last item in data.
        collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))

        XCTAssertEqual(tapped.map(\.index), [2])
        XCTAssertEqual(tapped.map(\.id), [30])
    }

    func testWrapContentListIsAsTallAsItsRows() throws {
        let list = RecyclerView(data: (0..<3).map { TestItem(id: $0) }) { _ in
            Color.clear.frame(height: 50)
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        let hostingController = UIHostingController(rootView: list)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()

        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
        XCTAssertEqual(collectionView.frame.height, 150, accuracy: 0.5)
    }

    func testControllerAttachesToTheList() throws {
        let controller = RecyclerViewController()
        let hosted = try host(makeList(ids: Array(0..<50)).controller(controller))
        XCTAssertTrue(controller.collectionView === hosted.collectionView)
    }
}
