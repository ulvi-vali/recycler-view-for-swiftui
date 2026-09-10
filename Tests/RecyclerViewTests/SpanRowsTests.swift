import XCTest
@testable import RecyclerView

final class SpanRowsTests: XCTestCase {
    func testSingleSpanItemsFillEachRow() {
        let rows = SpanRows.build(count: 5, spanCount: 2) { _ in 1 }
        XCTAssertEqual(rows, [[0, 1], [2, 3], [4]])
    }

    func testFullWidthItemsTakeARowOfTheirOwn() {
        let spans = [2, 1, 1, 2, 1]
        let rows = SpanRows.build(count: spans.count, spanCount: 2) { spans[$0] }
        XCTAssertEqual(rows, [[0], [1, 2], [3], [4]])
    }

    func testItemThatDoesNotFitStartsANewRow() {
        let spans = [1, 2, 1]
        let rows = SpanRows.build(count: spans.count, spanCount: 2) { spans[$0] }
        XCTAssertEqual(rows, [[0], [1], [2]])
    }

    func testSpansAreClampedToTheColumnCount() {
        let spans = [0, 5, -3, 2]
        let rows = SpanRows.build(count: spans.count, spanCount: 3) { spans[$0] }
        XCTAssertEqual(rows, [[0], [1], [2, 3]])
    }

    func testNoItemsMakeNoRows() {
        XCTAssertEqual(SpanRows.build(count: 0, spanCount: 2) { _ in 1 }, [])
    }

    func testColumnCountBelowOneIsTreatedAsOne() {
        XCTAssertEqual(SpanRows.build(count: 3, spanCount: 0) { _ in 1 }, [[0], [1], [2]])
    }
}
