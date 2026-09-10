import SwiftUI
import UIKit

/// A collection view cell that displays a SwiftUI view.
///
/// On iOS 16 and later the view is hosted with `UIHostingConfiguration`. On earlier versions a
/// `UIHostingController` is embedded in the cell and reused each time the cell is bound.
public class ViewHolder<Content: View>: UICollectionViewCell {
    /// The identifier ``RecyclerViewAdapter`` registers and dequeues this cell with.
    public static var reuseIdentifier: String {
        String(describing: self)
    }

    private var hostingController: UIHostingController<Content>?
    private var itemID = "unknown"

    /// Displays `view` in the cell.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to display.
    ///   - itemID: A string identifying the item the view represents.
    ///   - parentViewController: The view controller containing the collection view. Before iOS 16
    ///     the cell's hosting controller is added to it as a child.
    public func bind(_ view: Content, itemID: String, parentViewController: UIViewController?) {
        self.itemID = itemID

        if #available(iOS 16.0, *) {
            contentConfiguration = UIHostingConfiguration {
                view
            }
            .margins(.all, 0)
            .background(Color.clear)
        } else if let hostingController = hostingController {
            hostingController.rootView = view
            hostingController.view.invalidateIntrinsicContentSize()
            hostingController.view.setNeedsLayout()
            hostingController.view.setNeedsUpdateConstraints()
            hostingController.view.layoutIfNeeded()
        } else {
            let hostingController = UIHostingController(rootView: view, ignoreSafeArea: true)
            self.hostingController = hostingController
            hostingController.view.backgroundColor = .clear
            hostingController.view.setNeedsUpdateConstraints()

            let hostedView: UIView = hostingController.view
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])

            if let parentViewController = parentViewController {
                parentViewController.addChild(hostingController)
                hostingController.didMove(toParent: parentViewController)
            }
        }
    }

    override public func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        guard #unavailable(iOS 16.0), let hostingController = hostingController else { return attributes }

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()

        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attributes.frame.size.height = ceil(size.height)
        return attributes
    }

    /// Cells never inherit the window's safe area.
    ///
    /// UIKit derives `safeAreaInsets` from how a view overlaps the window's safe area. When the list
    /// is drawn under the status bar (see ``RecyclerView/withoutStatusBar(_:)``), each cell picks up a
    /// top inset as it scrolls into that region, and `UIHostingConfiguration` honours it: the row
    /// grows by the height of the status bar and settles back, which reads as rows sliding while the
    /// list scrolls. The pre-iOS 16 path avoids the same problem by hosting its view with the safe
    /// area disabled.
    override public var safeAreaInsets: UIEdgeInsets {
        .zero
    }

    private var isReversed: Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if let collectionView = current as? UICollectionView {
                return collectionView.transform != .identity
            }
            responder = current.next
        }
        return false
    }

    override public func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        transform = isReversed ? CGAffineTransform(rotationAngle: .pi) : .identity
        CATransaction.commit()
    }

    override public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "transform" {
            return NSNull()
        }
        return super.action(for: layer, forKey: event)
    }

    deinit {
        if let hostingController = hostingController {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
        }
    }
}
