import UIKit

/// Measurements of the window the app is showing.
///
/// Only a fallback for a list that is not yet in a window: once it is, the list reads the insets of
/// its own window.
@MainActor
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
}
