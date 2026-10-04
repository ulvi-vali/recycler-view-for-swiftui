import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class ScrollEdgesTests: XCTestCase {
    private final class StubDataSource: NSObject, UICollectionViewDataSource {
        var count: Int

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
        let list: UIRecyclerView
        let dataSource: StubDataSource
    }

    /// `count` 100pt rows in a 320x480 list.
    private func makeFixture(count: Int = 20, axis: Axis = .vertical) -> Fixture {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = axis == .vertical ? .vertical : .horizontal
        layout.itemSize = axis == .vertical ? CGSize(width: 320, height: 100) : CGSize(width: 100, height: 480)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let list = UIRecyclerView(frame: window.bounds, collectionViewLayout: layout)
        list.contentInsetAdjustmentBehavior = .never
        list.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        let dataSource = StubDataSource(count: count)
        list.dataSource = dataSource
        list.scrollAxis = axis == .vertical ? .vertical : .horizontal
        window.addSubview(list)
        list.layoutIfNeeded()
        return Fixture(window: window, list: list, dataSource: dataSource)
    }

    func testAListThatHasNotMovedReportsWhatIsLeftBelow() {
        let fixture = makeFixture()
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reported, [RecyclerViewScrollEdges(toStart: 0, toEnd: 2000 - 480)])
    }

    func testScrollingMovesTheDistanceFromOneEndToTheOther() {
        let fixture = makeFixture()
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.layoutIfNeeded()

        fixture.list.contentOffset = CGPoint(x: 0, y: 300)
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reported.last, RecyclerViewScrollEdges(toStart: 300, toEnd: 2000 - 480 - 300))
    }

    func testAnUnchangedPositionIsReportedOnce() {
        let fixture = makeFixture()
        var reports = 0
        fixture.list.onScrollEdgesChange = { _ in reports += 1 }
        fixture.list.layoutIfNeeded()
        fixture.list.setNeedsLayout()
        fixture.list.layoutIfNeeded()

        // A new callback, as every SwiftUI update hands over, does not ask for another report.
        fixture.list.onScrollEdgesChange = { _ in reports += 1 }
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reports, 1)
    }

    func testBouncingPastAnEndCountsAsBeingAtIt() {
        let fixture = makeFixture()
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.contentOffset = CGPoint(x: 0, y: -40)
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reported.last, RecyclerViewScrollEdges(toStart: 0, toEnd: 2000 - 480))
    }

    func testAListThatFitsHasNothingLeftEitherWay() {
        let fixture = makeFixture(count: 3)
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reported.last, RecyclerViewScrollEdges(toStart: 0, toEnd: 0))
    }

    func testContentInsetsAddToTheDistances() {
        let fixture = makeFixture()
        fixture.list.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 60, right: 0)
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.contentOffset = CGPoint(x: 0, y: -40)
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reported.last, RecyclerViewScrollEdges(toStart: 0, toEnd: 2000 + 40 + 60 - 480))
    }

    func testAReversedListMeasuresFromTheTopOfTheScreen() {
        let fixture = makeFixture()
        fixture.list.transform = CGAffineTransform(rotationAngle: .pi)
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.layoutIfNeeded()

        // The start of the content is at the bottom of the screen.
        XCTAssertEqual(reported.last, RecyclerViewScrollEdges(toStart: 2000 - 480, toEnd: 0))
    }

    func testAHorizontalListMeasuresAlongItsWidth() {
        let fixture = makeFixture(axis: .horizontal)
        var reported: [RecyclerViewScrollEdges] = []
        fixture.list.onScrollEdgesChange = { reported.append($0) }
        fixture.list.contentOffset = CGPoint(x: 500, y: 0)
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reported.last, RecyclerViewScrollEdges(toStart: 500, toEnd: 2000 - 320 - 500))
    }

    func testTheSwiftUIListReportsBeforeItIsScrolled() {
        struct Row: Identifiable { let id: Int }
        var reported: RecyclerViewScrollEdges?
        let list = RecyclerView(data: (0..<30).map(Row.init), layout: .linear()) { _ in
            Color.red.frame(height: 50)
        }
        .verticalLayout(.matchParent)
        .onScrollEdges { reported = $0 }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let host = UIHostingController(rootView: list)
        window.rootViewController = host
        window.makeKeyAndVisible()

        XCTAssertTrue(waitUntil { (reported?.toEnd ?? 0) > 0 }, "a list longer than the screen has more below")
        XCTAssertEqual(reported?.toStart, 0)
        window.isHidden = true
    }

    func testRemovingTheCallbackStopsTheReports() {
        let fixture = makeFixture()
        var reports = 0
        fixture.list.onScrollEdgesChange = { _ in reports += 1 }
        fixture.list.layoutIfNeeded()
        fixture.list.onScrollEdgesChange = nil
        fixture.list.contentOffset = CGPoint(x: 0, y: 300)
        fixture.list.layoutIfNeeded()

        XCTAssertEqual(reports, 1)
    }
}
