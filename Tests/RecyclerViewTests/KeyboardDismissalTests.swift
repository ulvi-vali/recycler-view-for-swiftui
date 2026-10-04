import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

@MainActor
final class KeyboardDismissalTests: XCTestCase {
    private struct Fixture {
        let window: UIWindow
        let collectionView: UICollectionView
        let adapter: RecyclerViewAdapter<TestItem, Text>
        /// A text field inside the list, standing in for one in a row.
        let fieldInList: UITextField
        /// A text field next to the list, such as a search field or a composer.
        let fieldOutsideList: UITextField
    }

    private func makeFixture() -> Fixture {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 60, width: 320, height: 420), collectionViewLayout: UICollectionViewFlowLayout())
        let adapter = RecyclerViewAdapter<TestItem, Text>(collectionView: collectionView) { item in
            Text("Row \(item.id)")
        }
        rootViewController.view.addSubview(collectionView)

        let fieldInList = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        collectionView.addSubview(fieldInList)
        let fieldOutsideList = UITextField(frame: CGRect(x: 0, y: 10, width: 200, height: 40))
        rootViewController.view.addSubview(fieldOutsideList)

        return Fixture(
            window: window,
            collectionView: collectionView,
            adapter: adapter,
            fieldInList: fieldInList,
            fieldOutsideList: fieldOutsideList
        )
    }

    private func beginDragging(_ fixture: Fixture) {
        fixture.adapter.scrollViewWillBeginDragging(fixture.collectionView)
    }

    func testListScopeEndsEditingInsideTheList() throws {
        let fixture = makeFixture()
        fixture.adapter.keyboardDismissal = .list
        try XCTSkipUnless(fixture.fieldInList.becomeFirstResponder(), "The test window cannot host a first responder")

        beginDragging(fixture)
        XCTAssertFalse(fixture.fieldInList.isFirstResponder)
    }

    func testListScopeLeavesInputOutsideTheList() throws {
        let fixture = makeFixture()
        fixture.adapter.keyboardDismissal = .list
        try XCTSkipUnless(fixture.fieldOutsideList.becomeFirstResponder(), "The test window cannot host a first responder")

        beginDragging(fixture)
        XCTAssertTrue(fixture.fieldOutsideList.isFirstResponder)
    }

    func testWindowScopeEndsEditingAnywhereInTheWindow() throws {
        let fixture = makeFixture()
        fixture.adapter.keyboardDismissal = .window
        try XCTSkipUnless(fixture.fieldOutsideList.becomeFirstResponder(), "The test window cannot host a first responder")

        beginDragging(fixture)
        XCTAssertFalse(fixture.fieldOutsideList.isFirstResponder)
    }

    func testNoScopeLeavesTheKeyboardAlone() throws {
        let fixture = makeFixture()
        try XCTSkipUnless(fixture.fieldInList.becomeFirstResponder(), "The test window cannot host a first responder")

        beginDragging(fixture)
        XCTAssertTrue(fixture.fieldInList.isFirstResponder)
    }

    func testBooleanFormMapsToTheListScope() {
        let fixture = makeFixture()
        XCTAssertNil(fixture.adapter.keyboardDismissal)

        fixture.adapter.dismissesKeyboardOnScroll = true
        XCTAssertEqual(fixture.adapter.keyboardDismissal, .list)

        fixture.adapter.dismissesKeyboardOnScroll = false
        XCTAssertNil(fixture.adapter.keyboardDismissal)
    }

    func testModifierReachesTheAdapter() throws {
        func hostedAdapter<V: View>(_ view: V) throws -> (UIWindow, RecyclerViewAdapter<TestItem, Text>) {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
            let hostingController = UIHostingController(rootView: view)
            window.rootViewController = hostingController
            window.isHidden = false
            hostingController.view.layoutIfNeeded()
            let collectionView = try XCTUnwrap(hostingController.view.firstDescendant(ofType: UIRecyclerView.self))
            return (window, try XCTUnwrap(collectionView.dataSource as? RecyclerViewAdapter<TestItem, Text>))
        }

        let items = [TestItem(id: 1)]
        let (_, listScoped) = try hostedAdapter(RecyclerView(data: items) { Text("\($0.id)") }.dismissesKeyboardOnScroll())
        XCTAssertEqual(listScoped.keyboardDismissal, .list)

        let (_, windowScoped) = try hostedAdapter(RecyclerView(data: items) { Text("\($0.id)") }.dismissesKeyboardOnScroll(.window))
        XCTAssertEqual(windowScoped.keyboardDismissal, .window)

        let (_, off) = try hostedAdapter(RecyclerView(data: items) { Text("\($0.id)") }.dismissesKeyboardOnScroll(false))
        XCTAssertNil(off.keyboardDismissal)
    }
}
