import SwiftUI
import UIKit
import XCTest
@testable import RecyclerView

struct TestItem: Identifiable, Equatable {
    let id: Int
    var title = ""
}

extension UIView {
    func firstDescendant<T: UIView>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        for subview in subviews {
            if let match = subview.firstDescendant(ofType: type) {
                return match
            }
        }
        return nil
    }
}

/// Runs the main run loop until `condition` holds or `timeout` passes, giving work dispatched to the
/// main queue a chance to run.
@MainActor
func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    return condition()
}
