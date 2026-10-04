import UIKit

/// The deletions, insertions and moves that turn one list of identities into another.
///
/// The positions follow the rules of `UICollectionView.performBatchUpdates(_:completion:)`:
/// deletions and the sources of moves are positions in the old list, insertions and the destinations
/// of moves are positions in the new list. No position is both deleted and moved, and none is both
/// inserted and moved to, so the three can be applied in one batch.
struct ListDiff: Equatable, Sendable {
    /// An item that keeps its identity but changes position.
    struct Move: Equatable, Sendable {
        /// The item's position in the old list.
        let from: IndexPath
        /// The item's position in the new list.
        let to: IndexPath
    }

    /// Positions in the old list to delete, in ascending order.
    let deletions: [IndexPath]
    /// Positions in the new list to insert, in ascending order.
    let insertions: [IndexPath]
    /// Items to move, in ascending order of their old position.
    let moves: [Move]

    var isEmpty: Bool {
        deletions.isEmpty && insertions.isEmpty && moves.isEmpty
    }

    init<ID: Hashable>(from old: [ID], to new: [ID], section: Int = 0) {
        var deletions: [IndexPath] = []
        var insertions: [IndexPath] = []
        var moves: [Move] = []

        // A removal and an insertion of the same identity are paired into a move, which keeps the
        // item's cell instead of deleting it and creating another.
        for change in new.difference(from: old).inferringMoves() {
            switch change {
            case .remove(let offset, _, let newOffset):
                if let newOffset = newOffset {
                    moves.append(Move(from: IndexPath(item: offset, section: section), to: IndexPath(item: newOffset, section: section)))
                } else {
                    deletions.append(IndexPath(item: offset, section: section))
                }
            case .insert(let offset, _, let oldOffset):
                // The insertion half of a move was recorded with its removal.
                if oldOffset == nil {
                    insertions.append(IndexPath(item: offset, section: section))
                }
            }
        }

        self.deletions = deletions.sorted()
        self.insertions = insertions.sorted()
        self.moves = moves.sorted { $0.from < $1.from }
    }

    /// Replaces each distinct identity in two lists with a small integer.
    ///
    /// Item identities can be of any `Hashable` type, which need not be `Sendable`. Tokens are, so the
    /// two token lists can be diffed on another queue: they differ exactly where the identities do.
    static func tokens<ID: Hashable>(from old: [ID], to new: [ID]) -> (old: [Int], new: [Int]) {
        var tokens: [ID: Int] = [:]
        tokens.reserveCapacity(old.count + new.count)

        func token(for id: ID) -> Int {
            if let token = tokens[id] {
                return token
            }
            let token = tokens.count
            tokens[id] = token
            return token
        }

        return (old.map(token(for:)), new.map(token(for:)))
    }
}
