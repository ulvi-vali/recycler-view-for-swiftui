import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

/// Wrap-content lists measure against the space SwiftUI proposes, not against the window or screen.
@MainActor
final class WrapContentTests: XCTestCase {
    private let longText = String(repeating: "wrap ", count: 40)

    @MainActor
    private struct Hosted<Root: View> {
        let window: UIWindow
        let hostingController: UIHostingController<Root>

        func collectionView() throws -> UIRecyclerView {
            hostingController.view.layoutIfNeeded()
            return try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
        }
    }

    private func host<Root: View>(_ root: Root, width: CGFloat = 320, height: CGFloat = 800) -> Hosted<Root> {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        let hostingController = UIHostingController(rootView: root)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        return Hosted(window: window, hostingController: hostingController)
    }

    private func rows(_ count: Int) -> [TestItem] {
        (0..<count).map { TestItem(id: $0) }
    }

    /// Settles the list on its final height, which takes a second pass before iOS 16.
    private func settledHeight<Root: View>(of hosted: Hosted<Root>, expected: CGFloat) throws -> CGFloat {
        let collectionView = try hosted.collectionView()
        _ = waitUntil {
            hosted.hostingController.view.layoutIfNeeded()
            return abs(collectionView.frame.height - expected) < 0.5
        }
        return collectionView.frame.height
    }

    // MARK: - Proposed width

    func testListNarrowerThanTheWindowMeasuresRowsAtItsOwnWidth() throws {
        let text = longText
        let list = RecyclerView(data: rows(1)) { _ in
            Text(text)
        }
        let hosted = host(list.frame(width: 160))

        let expected = ceil(SwiftUIMeasurement.fittingHeight(of: Text(text), width: 160))
        let wide = ceil(SwiftUIMeasurement.fittingHeight(of: Text(text), width: 320))
        XCTAssertGreaterThan(expected, wide)
        XCTAssertEqual(try settledHeight(of: hosted, expected: expected), expected, accuracy: 0.5)
    }

    func testSpacingInsetsTheContentAndSeparatesRows() throws {
        let list = RecyclerView(data: rows(3), layout: .linear(spacing: 10)) { _ in
            Color.clear.frame(height: 50)
        }
        let hosted = host(list)
        XCTAssertEqual(try settledHeight(of: hosted, expected: 190), 190, accuracy: 0.5)
    }

    func testGridRowsAreMeasuredAtTheirColumnWidth() throws {
        let list = RecyclerView(data: rows(5), layout: .grid(spanCount: 2, spacing: 10)) { _ in
            Color.clear.frame(height: 50)
        }
        let hosted = host(list)
        XCTAssertEqual(try settledHeight(of: hosted, expected: 170), 170, accuracy: 0.5)
    }

    func testHorizontalListIsAsTallAsItsTallestItem() throws {
        let list = RecyclerView(data: rows(4), layout: .linear(orientation: .horizontal, spacing: 12)) { index, _ in
            Color.clear.frame(width: 140, height: index == 2 ? 120 : 90)
        }
        let hosted = host(list)
        XCTAssertEqual(try settledHeight(of: hosted, expected: 144), 144, accuracy: 0.5)
    }

    // MARK: - Proposed height

    func testProposedHeightCapsTheList() throws {
        let list = RecyclerView(data: rows(20)) { _ in
            Color.clear.frame(height: 50)
        }
        let hosted = host(VStack(spacing: 0) {
            Color.clear.frame(height: 100)
            list
        }, height: 400)
        let expected = availableHeight(in: hosted) - 100
        XCTAssertLessThan(expected, 1000)
        XCTAssertEqual(try settledHeight(of: hosted, expected: expected), expected, accuracy: 0.5)
    }

    /// The height SwiftUI proposes to the root view: the window less its safe area.
    private func availableHeight<Root: View>(in hosted: Hosted<Root>) -> CGFloat {
        hosted.hostingController.view.safeAreaLayoutGuide.layoutFrame.height
    }

    func testListInAScrollViewIsAsTallAsAllItsRows() throws {
        let list = RecyclerView(data: rows(20)) { _ in
            Color.clear.frame(height: 50)
        }
        let hosted = host(ScrollView { list }, height: 400)
        XCTAssertEqual(try settledHeight(of: hosted, expected: 1000), 1000, accuracy: 0.5)
    }

    func testEmptyListTakesNoHeight() throws {
        let list = RecyclerView(data: [TestItem]()) { _ in
            Color.clear.frame(height: 50)
        }
        let hosted = host(VStack(spacing: 0) {
            list
            Spacer()
        })
        XCTAssertEqual(try settledHeight(of: hosted, expected: 0), 0, accuracy: 0.5)
    }

    // MARK: - Before iOS 16

    func testLegacySizingMeasuresAtTheLaidOutWidth() throws {
        WrapContentSizing.forcesLegacySizing = true
        defer { WrapContentSizing.forcesLegacySizing = false }

        let text = longText
        let list = RecyclerView(data: rows(1)) { _ in
            Text(text)
        }
        let hosted = host(list.frame(width: 160))

        let expected = ceil(SwiftUIMeasurement.fittingHeight(of: Text(text), width: 160))
        XCTAssertEqual(try settledHeight(of: hosted, expected: expected), expected, accuracy: 0.5)
    }

    func testLegacySizingIsCappedByTheProposedHeight() throws {
        WrapContentSizing.forcesLegacySizing = true
        defer { WrapContentSizing.forcesLegacySizing = false }

        let list = RecyclerView(data: rows(20)) { _ in
            Color.clear.frame(height: 50)
        }
        let hosted = host(VStack(spacing: 0) {
            Color.clear.frame(height: 100)
            list
        }, height: 400)
        let expected = availableHeight(in: hosted) - 100
        XCTAssertEqual(try settledHeight(of: hosted, expected: expected), expected, accuracy: 0.5)
    }

    func testLegacySizingFollowsDataChanges() throws {
        WrapContentSizing.forcesLegacySizing = true
        defer { WrapContentSizing.forcesLegacySizing = false }

        func list(_ count: Int) -> RecyclerView<TestItem, some View> {
            RecyclerView(data: rows(count)) { _ in
                Color.clear.frame(height: 50)
            }
            .withAnimation(false)
        }
        let hosted = host(list(2))
        XCTAssertEqual(try settledHeight(of: hosted, expected: 100), 100, accuracy: 0.5)

        hosted.hostingController.rootView = list(4)
        XCTAssertEqual(try settledHeight(of: hosted, expected: 200), 200, accuracy: 0.5)
    }
}
