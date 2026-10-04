import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class SeparatorTests: XCTestCase {
    private typealias List = RecyclerView<TestItem, AnyView>

    @MainActor
    private struct Hosted {
        let window: UIWindow
        let hostingController: UIHostingController<List>
        let collectionView: UIRecyclerView

        /// The frames of the separators the layout places, by the index of the row they follow.
        var separatorFrames: [Int: CGRect] {
            hostingController.view.layoutIfNeeded()
            collectionView.layoutIfNeeded()
            let everything = CGRect(origin: CGPoint(x: -1000, y: -1000), size: CGSize(width: 10_000, height: 10_000))
            let attributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: everything) ?? []
            var frames: [Int: CGRect] = [:]
            for attribute in attributes where attribute.representedElementKind == RecyclerViewSeparator.elementKind {
                frames[attribute.indexPath.item] = attribute.frame
            }
            return frames
        }

        func rowFrame(_ index: Int) -> CGRect {
            collectionView.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame ?? .null
        }
    }

    private func makeList(
        count: Int = 4,
        layout: RecyclerViewLayoutManager = .linear(spacing: 10),
        rowSize: CGSize = CGSize(width: 60, height: 50)
    ) -> List {
        RecyclerView(data: (0..<count).map { TestItem(id: $0) }, layout: layout) { _ in
            AnyView(Color.clear.frame(width: layout.orientation == .horizontal ? rowSize.width : nil, height: rowSize.height))
        }
        .withAnimation(false)
    }

    private func host(_ list: List, height: CGFloat = 800) throws -> Hosted {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: height))
        let hostingController = UIHostingController(rootView: list)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
        collectionView.layoutIfNeeded()
        return Hosted(window: window, hostingController: hostingController, collectionView: collectionView)
    }

    // MARK: - Placement

    func testListsHaveNoSeparatorsByDefault() throws {
        let hosted = try host(makeList().verticalLayout(.matchParent))
        XCTAssertTrue(hosted.separatorFrames.isEmpty)
    }

    func testSeparatorsSitBetweenRowsButNotAfterTheLast() throws {
        let list = makeList()
            .separator(thickness: 2, insets: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 8))
            .verticalLayout(.matchParent)
        let hosted = try host(list)
        let frames = hosted.separatorFrames

        XCTAssertEqual(Set(frames.keys), [0, 1, 2])
        for index in 0..<3 {
            let row = hosted.rowFrame(index)
            let next = hosted.rowFrame(index + 1)
            let separator = try XCTUnwrap(frames[index])
            XCTAssertEqual(separator.height, 2, accuracy: 0.01)
            // Centred in the 10pt gap between the rows.
            XCTAssertEqual(separator.minY - row.maxY, 4, accuracy: 0.5, "Separator \(index)")
            XCTAssertEqual(next.minY - separator.maxY, 4, accuracy: 0.5, "Separator \(index)")
            // Inset from the row's leading and trailing edges.
            XCTAssertEqual(separator.minX, row.minX + 16, accuracy: 0.5)
            XCTAssertEqual(separator.maxX, row.maxX - 8, accuracy: 0.5)
        }
    }

    func testDrawAfterLastAddsASeparatorAfterTheLastRow() throws {
        let hosted = try host(makeList().separator(thickness: 2, drawAfterLast: true).verticalLayout(.matchParent))
        let frames = hosted.separatorFrames
        XCTAssertEqual(Set(frames.keys), [0, 1, 2, 3])
        XCTAssertEqual(try XCTUnwrap(frames[3]).minY - hosted.rowFrame(3).maxY, 4, accuracy: 0.5)
    }

    func testWithoutSpacingTheSeparatorLiesInsideTheRowsBottomEdge() throws {
        let hosted = try host(makeList(layout: .linear()).separator(thickness: 1).verticalLayout(.matchParent))
        let frames = hosted.separatorFrames
        XCTAssertEqual(Set(frames.keys), [0, 1, 2])
        let separator = try XCTUnwrap(frames[0])
        XCTAssertEqual(separator.maxY, hosted.rowFrame(0).maxY, accuracy: 0.5)
        XCTAssertEqual(separator.width, 320, accuracy: 0.5)
    }

    func testHairlineIsOnePixelThick() throws {
        let hosted = try host(makeList().separator().verticalLayout(.matchParent))
        let separator = try XCTUnwrap(hosted.separatorFrames[0])
        XCTAssertEqual(separator.height, 1 / hosted.collectionView.traitCollection.displayScale, accuracy: 0.01)
    }

    func testRowsWithoutPrecomputedHeightsGetSeparatorsToo() throws {
        let hosted = try host(makeList().separator(thickness: 2).precomputesItemHeights(false).verticalLayout(.matchParent))
        let frames = hosted.separatorFrames
        XCTAssertEqual(Set(frames.keys), [0, 1, 2])
        XCTAssertEqual(try XCTUnwrap(frames[1]).minY - hosted.rowFrame(1).maxY, 4, accuracy: 0.5)

        let kind = RecyclerViewSeparator.elementKind
        let view = try XCTUnwrap(hosted.collectionView.supplementaryView(forElementKind: kind, at: IndexPath(item: 0, section: 0)))
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.frame, try XCTUnwrap(frames[0]))
    }

    func testHorizontalSeparatorsRunAlongTheTrailingEdge() throws {
        let layout = RecyclerViewLayoutManager.linear(orientation: .horizontal, spacing: 10)
        let list = makeList(layout: layout)
            .separator(thickness: 2, insets: EdgeInsets(top: 6, leading: 0, bottom: 4, trailing: 0))
            .verticalLayout(.matchParent)
        let hosted = try host(list)
        let frames = hosted.separatorFrames

        XCTAssertEqual(Set(frames.keys), [0, 1, 2])
        let row = hosted.rowFrame(0)
        let separator = try XCTUnwrap(frames[0])
        XCTAssertEqual(separator.width, 2, accuracy: 0.01)
        XCTAssertEqual(separator.minX - row.maxX, 4, accuracy: 0.5)
        XCTAssertEqual(separator.minY, row.minY + 6, accuracy: 0.5)
        XCTAssertEqual(separator.maxY, row.maxY - 4, accuracy: 0.5)
    }

    func testGridsHaveNoSeparators() throws {
        let hosted = try host(makeList(layout: .grid(spanCount: 2)).separator(thickness: 2).verticalLayout(.matchParent))
        XCTAssertTrue(hosted.separatorFrames.isEmpty)
    }

    // MARK: - Measurement

    func testSeparatorsDoNotChangeRowHeightsOrTheWrapContentHeight() throws {
        let plain = try host(makeList())
        let separated = try host(makeList().separator(thickness: 3, drawAfterLast: true))

        XCTAssertEqual(plain.collectionView.frame.height, 4 * 50 + 5 * 10, accuracy: 0.5)
        XCTAssertEqual(separated.collectionView.frame.height, plain.collectionView.frame.height, accuracy: 0.5)
        for index in 0..<4 {
            XCTAssertEqual(separated.rowFrame(index), plain.rowFrame(index))
        }
    }

    // MARK: - Updates

    func testAppendingARowMovesTheLastSeparator() throws {
        let hosted = try host(makeList(count: 3).separator(thickness: 2).verticalLayout(.matchParent))
        XCTAssertEqual(Set(hosted.separatorFrames.keys), [0, 1])

        hosted.hostingController.rootView = makeList(count: 4).separator(thickness: 2).verticalLayout(.matchParent)
        XCTAssertTrue(waitUntil { Set(hosted.separatorFrames.keys) == [0, 1, 2] })
    }

    func testAnimatedMovesInsertionsAndDeletionsKeepSeparatorsBetweenRows() throws {
        func list(_ ids: [Int]) -> List {
            RecyclerView(data: ids.map { TestItem(id: $0) }, layout: .linear(spacing: 10)) { _ in
                AnyView(Color.clear.frame(height: 50))
            }
            .separator(thickness: 2)
            .verticalLayout(.matchParent)
        }
        let hosted = try host(list(Array(0..<6)))
        let adapter = try XCTUnwrap(hosted.collectionView.dataSource as? RecyclerViewAdapter<TestItem, AnyView>)

        let ids = [5, 0, 9, 2, 1]
        hosted.hostingController.rootView = list(ids)
        XCTAssertTrue(waitUntil { adapter.items.map(\.id) == ids })
        XCTAssertTrue(waitUntil { Set(hosted.separatorFrames.keys) == [0, 1, 2, 3] })
    }

    func testTurningSeparatorsOnAndOff() throws {
        let hosted = try host(makeList().verticalLayout(.matchParent))
        XCTAssertTrue(hosted.separatorFrames.isEmpty)

        hosted.hostingController.rootView = makeList().separator(thickness: 2).verticalLayout(.matchParent)
        XCTAssertTrue(waitUntil { Set(hosted.separatorFrames.keys) == [0, 1, 2] })

        hosted.hostingController.rootView = makeList().separator(nil).verticalLayout(.matchParent)
        XCTAssertTrue(waitUntil { hosted.separatorFrames.isEmpty })
    }
}
