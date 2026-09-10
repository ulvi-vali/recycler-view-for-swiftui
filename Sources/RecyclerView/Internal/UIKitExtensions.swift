import SwiftUI
import UIKit

extension UIView {
    /// The nearest view controller up the responder chain.
    var parentViewController: UIViewController? {
        var responder = next
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }
}

extension UIHostingController {
    /// Creates a hosting controller whose view can be made to ignore the safe area.
    convenience init(rootView: Content, ignoreSafeArea: Bool) {
        self.init(rootView: rootView)

        if ignoreSafeArea {
            disableSafeArea()
        }
    }

    /// Swaps the hosting view's class for a runtime subclass that reports zero safe-area insets.
    ///
    /// Used before iOS 16, where `UIHostingController` has no public way to ignore the safe area. The
    /// subclass is created once per hosting view class and reused.
    func disableSafeArea() {
        guard let viewClass = object_getClass(view) else { return }

        let subclassName = String(cString: class_getName(viewClass)).appending("_IgnoreSafeArea")
        if let subclass = NSClassFromString(subclassName) {
            object_setClass(view, subclass)
            return
        }

        guard let subclassNameUTF8 = (subclassName as NSString).utf8String,
              let subclass = objc_allocateClassPair(viewClass, subclassNameUTF8, 0)
        else { return }

        if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
            let safeAreaInsets: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in .zero }
            class_addMethod(
                subclass,
                #selector(getter: UIView.safeAreaInsets),
                imp_implementationWithBlock(safeAreaInsets),
                method_getTypeEncoding(method)
            )
        }

        objc_registerClassPair(subclass)
        object_setClass(view, subclass)
    }
}
