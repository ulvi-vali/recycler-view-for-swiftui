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

    /// The size `view` takes when both its width and height are left to its content: its ideal size.
    ///
    /// Items in a horizontal list size themselves this way along the scroll axis, so their ideal
    /// height is the height the list needs to show them unclipped.
    static func idealSize<Content: View>(of view: Content) -> CGSize {
        let target = UIView.layoutFittingCompressedSize

        if #available(iOS 16.0, *) {
            let contentView = UIHostingConfiguration { view }
                .margins(.all, 0)
                .makeContentView()
            return contentView.systemLayoutSizeFitting(
                target,
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .fittingSizeLevel
            )
        }

        let hostingController = UIHostingController(rootView: view, ignoreSafeArea: true)
        return hostingController.view.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
    }
}
