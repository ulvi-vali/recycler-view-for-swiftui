import UIKit

/// Measurements of the window the app is showing.
enum WindowMetrics {
    /// The key window of the app's connected scenes, or the first window when none is key.
    static var keyWindow: UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    static var safeAreaInsets: UIEdgeInsets {
        keyWindow?.safeAreaInsets ?? .zero
    }

    static var screenBounds: CGRect {
        keyWindow?.screen.bounds ?? UIScreen.main.bounds
    }
}
