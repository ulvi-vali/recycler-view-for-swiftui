import XCTest
@testable import RecyclerView

final class ListDiffTests: XCTestCase {
    func testIdenticalListsProduceNoChanges() {
        XCTAssertTrue(ListDiff(from: [1, 2, 3], to: [1, 2, 3]).isEmpty)
    }

    func testInsertionsArePositionsInTheNewList() {
        let diff = ListDiff(from: [1, 3], to: [1, 2, 3, 4])
        XCTAssertEqual(diff.deletions, [])
        XCTAssertEqual(diff.insertions, [IndexPath(item: 1, section: 0), IndexPath(item: 3, section: 0)])
    }

    func testDeletionsArePositionsInTheOldList() {
        let diff = ListDiff(from: [1, 2, 3, 4], to: [2, 4])
        XCTAssertEqual(diff.deletions, [IndexPath(item: 0, section: 0), IndexPath(item: 2, section: 0)])
        XCTAssertEqual(diff.insertions, [])
    }

    func testApplyingTheDiffReproducesTheNewList() {
        let old = [1, 2, 3, 4, 5]
        let new = [2, 9, 4, 5, 7, 1]
        let diff = ListDiff(from: old, to: new)

        var result = old
        for indexPath in diff.deletions.reversed() {
            result.remove(at: indexPath.item)
        }
        for indexPath in diff.insertions {
            result.insert(new[indexPath.item], at: indexPath.item)
        }
        XCTAssertEqual(result, new)
    }
}
