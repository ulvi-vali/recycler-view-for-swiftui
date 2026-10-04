import UIKit

/// The deletions and insertions that turn one list of identities into another.
struct ListDiff: Equatable, Sendable {
    /// Positions in the old list to delete, in ascending order.
    let deletions: [IndexPath]
    /// Positions in the new list to insert, in ascending order.
    let insertions: [IndexPath]

    var isEmpty: Bool {
        deletions.isEmpty && insertions.isEmpty
    }

    init<ID: Hashable>(from old: [ID], to new: [ID], section: Int = 0) {
        var deletions: [IndexPath] = []
        var insertions: [IndexPath] = []

        for change in new.difference(from: old) {
            switch change {
            case .remove(let offset, _, _):
                deletions.append(IndexPath(item: offset, section: section))
            case .insert(let offset, _, _):
                insertions.append(IndexPath(item: offset, section: section))
            }
        }

        self.deletions = deletions.sorted()
        self.insertions = insertions.sorted()
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
