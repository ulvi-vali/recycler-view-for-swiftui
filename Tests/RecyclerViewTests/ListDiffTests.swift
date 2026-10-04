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
        XCTAssertEqual(applyAsBatchUpdate(ListDiff(from: old, to: new), to: old, inserting: new), new)
    }

    // MARK: - Moves

    func testReorderingIsAppliedAsMovesOnly() {
        let diff = ListDiff(from: [1, 2, 3, 4], to: [4, 1, 2, 3])
        XCTAssertEqual(diff.deletions, [])
        XCTAssertEqual(diff.insertions, [])
        XCTAssertEqual(diff.moves, [move(3, 0)])
        XCTAssertFalse(diff.isEmpty)
    }

    func testSwappingTwoItems() {
        let old = [1, 2, 3, 4]
        let new = [1, 4, 3, 2]
        let diff = ListDiff(from: old, to: new)
        XCTAssertEqual(diff.deletions, [])
        XCTAssertEqual(diff.insertions, [])
        XCTAssertFalse(diff.moves.isEmpty)
        XCTAssertEqual(applyAsBatchUpdate(diff, to: old, inserting: new), new)
    }

    func testMoveWithInsertion() {
        let old = [1, 2, 3]
        let new = [3, 1, 9, 2]
        let diff = ListDiff(from: old, to: new)
        XCTAssertEqual(diff.deletions, [])
        XCTAssertEqual(diff.insertions, [IndexPath(item: 2, section: 0)])
        XCTAssertEqual(diff.moves, [move(2, 0)])
        XCTAssertEqual(applyAsBatchUpdate(diff, to: old, inserting: new), new)
    }

    func testMoveWithDeletion() {
        let old = [1, 2, 3, 4]
        let new = [4, 1, 3]
        let diff = ListDiff(from: old, to: new)
        XCTAssertEqual(diff.deletions, [IndexPath(item: 1, section: 0)])
        XCTAssertEqual(diff.insertions, [])
        XCTAssertEqual(diff.moves, [move(3, 0)])
        XCTAssertEqual(applyAsBatchUpdate(diff, to: old, inserting: new), new)
    }

    func testRandomEditsFollowTheBatchUpdateRules() {
        var generator = SeededGenerator(seed: 42)
        for _ in 0..<300 {
            let old = Array((0..<Int.random(in: 0...12, using: &generator)).shuffled(using: &generator))
            var new = old.filter { _ in Int.random(in: 0..<4, using: &generator) > 0 }
            new.append(contentsOf: (100..<100 + Int.random(in: 0...4, using: &generator)))
            new.shuffle(using: &generator)

            let diff = ListDiff(from: old, to: new)
            let moveSources = Set(diff.moves.map(\.from))
            let moveDestinations = Set(diff.moves.map(\.to))
            XCTAssertTrue(moveSources.isDisjoint(with: diff.deletions), "\(old) -> \(new)")
            XCTAssertTrue(moveDestinations.isDisjoint(with: diff.insertions), "\(old) -> \(new)")
            XCTAssertEqual(applyAsBatchUpdate(diff, to: old, inserting: new), new, "\(old) -> \(new)")
        }
    }

    // MARK: - Helpers

    private func move(_ from: Int, _ to: Int) -> ListDiff.Move {
        ListDiff.Move(from: IndexPath(item: from, section: 0), to: IndexPath(item: to, section: 0))
    }

    /// Applies a diff the way `performBatchUpdates` does: deletions and move sources leave the old
    /// list, insertions and move destinations take their positions in the new one, and every other
    /// item keeps its relative order in the remaining positions.
    private func applyAsBatchUpdate(_ diff: ListDiff, to old: [Int], inserting new: [Int]) -> [Int] {
        let leaving = Set(diff.deletions.map(\.item)).union(diff.moves.map(\.from.item))
        var staying = old.enumerated().filter { !leaving.contains($0.offset) }.map(\.element)[...]

        var result = [Int?](repeating: nil, count: new.count)
        for indexPath in diff.insertions {
            result[indexPath.item] = new[indexPath.item]
        }
        for move in diff.moves {
            result[move.to.item] = old[move.from.item]
        }
        for index in result.indices where result[index] == nil {
            result[index] = staying.popFirst()
        }
        XCTAssertTrue(staying.isEmpty, "Items left over after the update")
        return result.compactMap { $0 }
    }

    // MARK: - Tokens

    func testTokensStandInForEachDistinctIdentity() {
        let tokens = ListDiff.tokens(from: ["a", "b", "c"], to: ["c", "d", "a"])
        XCTAssertEqual(tokens.old, [0, 1, 2])
        XCTAssertEqual(tokens.new, [2, 3, 0])
    }

    func testDiffingTokensMatchesDiffingIdentities() {
        let old = ["x", "y", "z", "w"]
        let new = ["y", "q", "w", "x"]
        let tokens = ListDiff.tokens(from: old, to: new)
        XCTAssertEqual(ListDiff(from: tokens.old, to: tokens.new), ListDiff(from: old, to: new))
    }
}
