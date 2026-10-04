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

    func testScrollToItemCenteredPutsTheItemInTheMiddle() {
        let fixture = makeFixture()
        fixture.controller.scrollToItemCentered(at: 5, animated: false)
        // Item 5 spans 500–600; its centre at the middle of a 480pt list.
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 550 - 240)
    }

    func testScrollToItemCenteredLeavesTheOffsetBelowTheItem() {
        let fixture = makeFixture()
        fixture.controller.scrollToItemCentered(at: 5, offset: 50, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 550 - 240 + 50)
    }

    func testScrollToItemCenteredStopsAtTheEdgesOfTheContent() {
        let fixture = makeFixture()
        fixture.controller.scrollToItemCentered(at: 0, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 0)
        fixture.controller.scrollToItemCentered(at: 19, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 2000 - 480)
    }

    func testScrollToItemCenteredCentresInTheAreaLeftByTheInsets() {
        let fixture = makeFixture()
        fixture.controller.setContentInsets(UIEdgeInsets(top: 80, left: 0, bottom: 0, right: 0))
        fixture.controller.scrollToItemCentered(at: 5, animated: false)
        // 400pt are left below the inset: the centre is 200pt into them.
        XCTAssertEqual(fixture.collectionView.contentOffset.y, 550 - 80 - 200)
    }

    func testScrollToItemCenteredInAHorizontalList() {
        let fixture = makeFixture(axis: .horizontal)
        fixture.controller.scrollToItemCentered(at: 4, animated: false)
        // Item 4 spans 400–500 in a 320pt-wide list.
        XCTAssertEqual(fixture.collectionView.contentOffset, CGPoint(x: 450 - 160, y: 0))
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

    // MARK: - Insets

    func testSetContentInsetsMovesContentAndBothIndicatorInsets() {
        let fixture = makeFixture()
        let insets = UIEdgeInsets(top: 40, left: 8, bottom: 64, right: 12)
        fixture.controller.setContentInsets(insets)

        XCTAssertEqual(fixture.collectionView.contentInset, insets)
        XCTAssertEqual(fixture.collectionView.verticalScrollIndicatorInsets, insets)
        XCTAssertEqual(fixture.collectionView.horizontalScrollIndicatorInsets, insets)
        XCTAssertEqual(fixture.controller.contentInsets, insets)
    }

    func testAnimatedSetContentInsetsLandsOnTheNewInsets() {
        let fixture = makeFixture()
        let insets = UIEdgeInsets(top: 20, left: 0, bottom: 30, right: 0)
        fixture.controller.setContentInsets(insets, animated: true, duration: 0.2)
        XCTAssertEqual(fixture.collectionView.contentInset, insets)
    }

    func testScrollToItemReachesContentBehindATopInset() {
        let fixture = makeFixture()
        fixture.controller.setContentInsets(UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0))
        fixture.controller.scrollToItem(at: 0, topOffset: 40, animated: false)
        XCTAssertEqual(fixture.collectionView.contentOffset.y, -40)
    }

    func testSetBottomInsetKeepsTheOtherEdges() {
        let fixture = makeFixture()
        fixture.controller.setContentInsets(UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0))
        fixture.controller.setBottomInset(64)
        XCTAssertEqual(fixture.collectionView.contentInset, UIEdgeInsets(top: 40, left: 0, bottom: 64, right: 0))
    }

    /// A reversed list is turned upside down, so its bottom edge on screen is the collection view's top.
    func testInsetsFollowTheScreenEdgesOfAReversedList() {
        let fixture = makeFixture()
        fixture.collectionView.transform = CGAffineTransform(rotationAngle: .pi)

        fixture.controller.setBottomInset(64)
        XCTAssertEqual(fixture.collectionView.contentInset, UIEdgeInsets(top: 64, left: 0, bottom: 0, right: 0))
        XCTAssertEqual(fixture.controller.contentInsets.bottom, 64)

        fixture.controller.setContentInsets(UIEdgeInsets(top: 10, left: 1, bottom: 20, right: 2))
        XCTAssertEqual(fixture.collectionView.contentInset, UIEdgeInsets(top: 20, left: 2, bottom: 10, right: 1))
    }

    func testUnattachedControllerDoesNothing() {
        let controller = RecyclerViewController()
        controller.scrollToItem(at: 0, animated: false)
        controller.setBottomInset(10)
        controller.setContentInsets(UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
        XCTAssertEqual(controller.contentInsets, .zero)
        XCTAssertNil(controller.indexOfItem(atScreenY: 0))
        XCTAssertFalse(controller.isUserScrolling)
    }
}
