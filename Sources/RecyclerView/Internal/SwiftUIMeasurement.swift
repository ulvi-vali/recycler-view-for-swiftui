import SwiftUI
import UIKit

@MainActor
enum SwiftUIMeasurement {
    /// The height `view` takes at `width` when its height is left to its content, which is how a
    /// self-sizing ``ViewHolder`` sizes it.
    ///
    /// Proposing a fixed height instead goes wrong in both directions: a zero height truncates
    /// wrapping text to a single line, and an unbounded one lets a vertical `Spacer` grow without
    /// limit.
    static func fittingHeight<Content: View>(of view: Content, width: CGFloat) -> CGFloat {
        let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)

        if #available(iOS 16.0, *) {
            let contentView = UIHostingConfiguration { view }
                .margins(.all, 0)
                .makeContentView()
            return contentView.systemLayoutSizeFitting(
                target,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
        }

        let hostingController = UIHostingController(rootView: view, ignoreSafeArea: true)
        return hostingController.view.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }
}
