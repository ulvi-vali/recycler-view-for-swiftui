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

    // MARK: - Moves

    /// Updates to `ids` and waits for the batch update, then checks that every visible cell shows the
    /// item at its position. An inconsistent batch update would raise instead.
    private func assertSettles(_ hosted: Hosted, on ids: [Int], file: StaticString = #filePath, line: UInt = #line) throws {
        let adapter = try XCTUnwrap(hosted.collectionView.dataSource as? RecyclerViewAdapter<TestItem, Text>, file: file, line: line)
        hosted.update(to: makeList(ids: ids))

        let settled = waitUntil {
            adapter.items.map(\.id) == ids && hosted.collectionView.numberOfItems(inSection: 0) == ids.count
        }
        XCTAssertTrue(settled, "Expected \(ids), got \(adapter.items.map(\.id))", file: file, line: line)

        hosted.collectionView.layoutIfNeeded()
        for case let cell as ViewHolder<Text> in hosted.collectionView.visibleCells {
            let indexPath = try XCTUnwrap(hosted.collectionView.indexPath(for: cell), file: file, line: line)
            XCTAssertEqual(cell.itemID, String(ids[indexPath.item]), "Cell at \(indexPath.item)", file: file, line: line)
        }
    }

    func testReorderingMovesRows() throws {
        let hosted = try host(makeList(ids: Array(0..<10)))
        try assertSettles(hosted, on: [9, 0, 1, 2, 3, 4, 5, 6, 7, 8])
        try assertSettles(hosted, on: Array((0..<10).reversed()))
        try assertSettles(hosted, on: [0, 2, 1, 3, 5, 4, 6, 8, 7, 9])
    }

    func testMoveTogetherWithInsertions() throws {
        let hosted = try host(makeList(ids: Array(0..<6)))
        try assertSettles(hosted, on: [5, 0, 100, 1, 2, 101, 3, 4])
    }

    func testMoveTogetherWithDeletions() throws {
        let hosted = try host(makeList(ids: Array(0..<8)))
        try assertSettles(hosted, on: [7, 0, 2, 4, 3])
    }

    func testMovesInsertionsAndDeletionsInOneUpdate() throws {
        let hosted = try host(makeList(ids: Array(0..<12)))
        try assertSettles(hosted, on: [11, 3, 200, 1, 0, 5, 201, 9, 7])
    }

    func testAnimatedMovesSettle() throws {
        let hosted = try host(makeList(ids: Array(0..<10)).withAnimation(true))
        let adapter = try XCTUnwrap(hosted.collectionView.dataSource as? RecyclerViewAdapter<TestItem, Text>)
        let ids = [3, 0, 1, 2, 50, 4, 6, 9, 8]
        hosted.update(to: makeList(ids: ids).withAnimation(true))
        XCTAssertTrue(waitUntil { adapter.items.map(\.id) == ids && hosted.collectionView.numberOfItems(inSection: 0) == ids.count })
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

    // MARK: - Under the status bar

    /// The list moves up by the top inset of the window it is in, which here is not the app's key
    /// window, so it ends up flush with the window's top edge.
    func testWithoutStatusBarShiftsByItsOwnWindowsTopInset() throws {
        let hosted = try host(makeList(ids: Array(0..<20)).withoutStatusBar())
        let window = hosted.window
        let topInset = window.safeAreaInsets.top
        XCTAssertGreaterThan(topInset, 0, "The simulator's window should have a status bar inset")
        XCTAssertFalse(window.isKeyWindow)

        let collectionView = hosted.collectionView
        let flush = waitUntil {
            hosted.hostingController.view.layoutIfNeeded()
            return abs(collectionView.convert(CGPoint.zero, to: nil).y) < 0.5
        }
        XCTAssertTrue(flush, "Expected the list at the window's top edge, \(topInset)pt above the safe area")
    }

    func testListWithTheStatusBarStartsBelowTheSafeArea() throws {
        let hosted = try host(makeList(ids: Array(0..<20)))
        let topInset = hosted.window.safeAreaInsets.top
        _ = waitUntil(timeout: 0.2) { false }

        hosted.hostingController.view.layoutIfNeeded()
        XCTAssertEqual(hosted.collectionView.convert(CGPoint.zero, to: nil).y, topInset, accuracy: 0.5)
    }
}
