import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

/// Rows whose content changes while their `id` stays the same are measured again.
@MainActor
final class MeasurementInvalidationTests: XCTestCase {
    private let shortText = "Short"
    private let longText = String(repeating: "A much longer title that wraps. ", count: 12)

    /// An item that cannot be compared, so the adapter cannot tell which items changed.
    private struct OpaqueItem: Identifiable {
        let id: Int
        var title: String
    }

    private func height(of text: String, width: CGFloat = 320) -> CGFloat {
        max(1, ceil(SwiftUIMeasurement.fittingHeight(of: Text(text), width: width)))
    }

    // MARK: - Detecting changes

    func testChangedIndicesCompareEquatableItemsWithTheSameIdentity() {
        let old = [TestItem(id: 1, title: "a"), TestItem(id: 2, title: "b"), TestItem(id: 3, title: "c")]
        let new = [TestItem(id: 3, title: "c"), TestItem(id: 1, title: "changed"), TestItem(id: 4, title: "new")]
        XCTAssertEqual(ItemChanges.changedIndices(from: old, to: new), [1])
    }

    func testChangedIndicesAreUnknownWithoutEquatable() {
        let items = [OpaqueItem(id: 1, title: "a")]
        XCTAssertNil(ItemChanges.changedIndices(from: items, to: items))
    }

    // MARK: - Adapter

    func testChangedEquatableItemIsMeasuredAgain() {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        var builds: [Int: Int] = [:]
        let adapter = RecyclerViewAdapter<TestItem, Text>(collectionView: collectionView) { _, item in
            builds[item.id, default: 0] += 1
            return Text(item.title)
        }
        adapter.items = [TestItem(id: 1, title: shortText), TestItem(id: 2, title: shortText)]
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: shortText))
        _ = adapter.measuredHeight(for: adapter.items[1], at: 1, width: 320)

        adapter.items = [TestItem(id: 1, title: longText), TestItem(id: 2, title: shortText)]

        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: longText))
        _ = adapter.measuredHeight(for: adapter.items[1], at: 1, width: 320)
        XCTAssertEqual(builds[1], 2, "The changed item is measured again")
        XCTAssertEqual(builds[2], 1, "The unchanged item keeps its measurement")
    }

    func testRowsOnScreenAreMeasuredAgainWhenItemsCannotBeCompared() throws {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 320, height: 100)
        layout.minimumLineSpacing = 0
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 250))
        let collectionView = UICollectionView(frame: window.bounds, collectionViewLayout: layout)
        collectionView.contentInsetAdjustmentBehavior = .never
        window.addSubview(collectionView)
        window.isHidden = false

        let adapter = RecyclerViewAdapter<OpaqueItem, Text>(collectionView: collectionView) { item in
            Text(item.title)
        }
        adapter.items = (0..<10).map { OpaqueItem(id: $0, title: shortText) }
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        let visible = Set(collectionView.indexPathsForVisibleItems.map(\.item))
        XCTAssertEqual(visible, [0, 1, 2])

        for (index, item) in adapter.items.enumerated() {
            XCTAssertEqual(adapter.measuredHeight(for: item, at: index, width: 320), height(of: shortText))
        }

        adapter.items = (0..<10).map { OpaqueItem(id: $0, title: longText) }

        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[1], at: 1, width: 320), height(of: longText), "A row on screen")
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[8], at: 8, width: 320), height(of: shortText), "A row off screen keeps its measurement")
    }

    func testNotifyItemChangedMeasuresTheItemAgain() {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        let adapter = RecyclerViewAdapter<OpaqueItem, Text>(collectionView: collectionView) { item in
            Text(item.title)
        }
        adapter.items = [OpaqueItem(id: 1, title: shortText)]
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: shortText))

        adapter.items[0].title = longText
        adapter.notifyItemChanged(at: 0)

        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: longText))
    }

    func testInvalidatingMeasurementsExplicitly() {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        var suffix = ""
        let adapter = RecyclerViewAdapter<TestItem, Text>(collectionView: collectionView) { item in
            Text(item.title + suffix)
        }
        adapter.items = [TestItem(id: 1, title: shortText)]
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: shortText))

        // The row depends on state outside its item, which the adapter cannot see change.
        suffix = longText
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: shortText))
        adapter.invalidateMeasurement(at: 0)
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: shortText + longText))

        suffix = ""
        adapter.invalidateAllMeasurements()
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: 320), height(of: shortText))
    }

    // MARK: - RecyclerView

    private func host<Root: View>(_ root: Root) -> (UIWindow, UIHostingController<Root>) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        let hostingController = UIHostingController(rootView: root)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        return (window, hostingController)
    }

    private func list(_ items: [TestItem], verticalLayout: RecyclerViewVerticalLayout) -> RecyclerView<TestItem, Text> {
        RecyclerView(data: items) { item in
            Text(item.title)
        }
        .withAnimation(false)
        .verticalLayout(verticalLayout)
    }

    func testRowGrowsWhenItsContentChangesUnderTheSameIdentity() throws {
        let (window, hostingController) = host(list([TestItem(id: 1, title: shortText)], verticalLayout: .matchParent))
        _ = window
        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))

        hostingController.rootView = list([TestItem(id: 1, title: longText)], verticalLayout: .matchParent)
        let grown = waitUntil {
            hostingController.view.layoutIfNeeded()
            let frame = collectionView.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame
            // The cell sizes itself to the exact height, which the cached estimate rounds up.
            return abs((frame?.height ?? 0) - height(of: longText)) < 1
        }
        XCTAssertTrue(grown)

        // The layout's estimate for the row, not only the cell's own sizing, reflects the new content.
        let adapter = try XCTUnwrap(collectionView.dataSource as? RecyclerViewAdapter<TestItem, Text>)
        XCTAssertEqual(adapter.measuredHeight(for: adapter.items[0], at: 0, width: collectionView.bounds.width), height(of: longText))
    }

    func testWrapContentListFollowsAChangedRow() throws {
        let (window, hostingController) = host(list([TestItem(id: 1, title: shortText)], verticalLayout: .wrapContent))
        _ = window
        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
        XCTAssertEqual(collectionView.frame.height, height(of: shortText), accuracy: 0.5)

        hostingController.rootView = list([TestItem(id: 1, title: longText)], verticalLayout: .wrapContent)
        let grown = waitUntil {
            hostingController.view.layoutIfNeeded()
            return abs(collectionView.frame.height - height(of: longText)) < 0.5
        }
        XCTAssertTrue(grown, "Height \(collectionView.frame.height), expected \(height(of: longText))")
    }

    func testWrapContentListFollowsAChangedRowAlongsideAnInsertion() throws {
        let (window, hostingController) = host(list([TestItem(id: 1, title: shortText)], verticalLayout: .wrapContent))
        _ = window
        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))

        hostingController.rootView = list([TestItem(id: 1, title: longText), TestItem(id: 2, title: shortText)], verticalLayout: .wrapContent)
        let expected = height(of: longText) + height(of: shortText)
        let settled = waitUntil {
            hostingController.view.layoutIfNeeded()
            return abs(collectionView.frame.height - expected) < 0.5
        }
        XCTAssertTrue(settled, "Height \(collectionView.frame.height), expected \(expected)")
    }
}
