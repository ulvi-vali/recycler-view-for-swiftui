import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class RecyclerViewControllerTests: XCTestCase {
    private final class StubDataSource: NSObject, UICollectionViewDataSource {
        let count: Int

        init(count: Int) {
            self.count = count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }
    }

    private struct Fixture {
        let window: UIWindow
        let collectionView: UICollectionView
        let dataSource: StubDataSource
        let controller: RecyclerViewController
    }

    /// Twenty 100pt items in a 320x480 list, so the content is 2000pt long.
    private func makeFixture(axis: Axis = .vertical) -> Fixture {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = axis == .vertical ? .vertical : .horizontal
        layout.itemSize = axis == .vertical ? CGSize(width: 320, height: 100) : CGSize(width: 100, height: 480)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let collectionView = UICollectionView(frame: window.bounds, collectionViewLayout: layout)
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        let dataSource = StubDataSource(count: 20)
        collectionView.dataSource = dataSource
        window.addSubview(collectionView)
        collectionView.layoutIfNeeded()

        let controller = RecyclerViewController()
        controller.attach(to: collectionView, axis: axis)
        return Fixture(window: window, collectionView: collectionView, dataSource: dataSource, controller: controller)
    }

    // MARK: - Scrolling

    func testScrollToItemLeavesTheTopOffsetAboveTheItem() {
        let fixture = makeFixture()
        fixture.controller.scrollToItem(at: 3, topOffset: 50, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 250)
    }

    func testScrollToItemStopsAtTheEndOfTheContent() {
        let fixture = makeFixture()
        fixture.controller.scrollToItem(at: 19, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 2000 - 480)
    }

    func testScrollToItemReachesContentBehindABottomInset() {
        let fixture = makeFixture()
        fixture.controller.setBottomInset(80)
        fixture.controller.scrollToItem(at: 19, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 2000 - 480 + 80)
    }

    func testScrollToItemIgnoresIndicesOutsideTheList() {
        let fixture = makeFixture()
        fixture.controller.scrollToItem(at: 20, animated: false)
        fixture.controller.scrollToItem(at: -1, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset, .zero)
    }

    func testScrollToItemInAHorizontalListUsesTheLeadingEdge() {
        let fixture = makeFixture(axis: .horizontal)
        fixture.controller.scrollToItem(at: 4, topOffset: 20, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset, CGPoint(x: 380, y: 0))
    }

    func testScrollToItemAtScreenYPutsTheItemsTopOnTheLine() {
        let fixture = makeFixture()
        fixture.controller.scrollToItem(at: 5, screenY: 100, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 400)
        XCTAssertEqual(fixture.controller.indexOfItem(atScreenY: 150), 5)
    }

    // MARK: - Queries

    func testIndexOfItemAtScreenYFollowsTheScrollPosition() {
        let fixture = makeFixture()
        fixture.collectionView.contentOffset = CGPoint(x: 0, y: 250)
        XCTAssertEqual(fixture.controller.indexOfItem(atScreenY: 10), 2)
        XCTAssertEqual(fixture.controller.indexOfItem(atScreenY: 60), 3)
    }

    func testSetBottomInsetMovesContentAndIndicatorInsets() {
        let fixture = makeFixture()
        fixture.controller.setBottomInset(64)
        XCTAssertEqual(fixture.collectionView.contentInset.bottom, 64)
        XCTAssertEqual(fixture.collectionView.verticalScrollIndicatorInsets.bottom, 64)
    }

    func testUnattachedControllerDoesNothing() {
        let controller = RecyclerViewController()
        controller.scrollToItem(at: 0, animated: false)
        controller.setBottomInset(10)
        XCTAssertNil(controller.indexOfItem(atScreenY: 0))
        XCTAssertFalse(controller.isUserScrolling)
    }
}
