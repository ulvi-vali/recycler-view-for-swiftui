import UIKit

/// The deletions and insertions that turn one list of identities into another.
struct ListDiff: Equatable {
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
}
