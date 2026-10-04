import SwiftUI
import UIKit

/// A line drawn between the rows of a linear ``RecyclerView``.
///
/// Set it with ``RecyclerView/separator(color:thickness:insets:drawAfterLast:)``. Lists have no
/// separators by default. Separators are drawn on top of the list without taking up space of their
/// own, so they never change how rows are measured or how tall a wrap-content list is.
///
/// In a vertical list a separator runs along the bottom of each row; in a horizontal list it runs
/// along the trailing edge. When the list's spacing leaves room for it, the separator is centred in
/// the gap between two rows; otherwise it lies along the inside of the row's edge, as in a table.
/// Grids have no separators.
public struct RecyclerViewSeparator: Equatable, Sendable {
    /// The colour of the line.
    public var color: Color
    /// The thickness of the line in points, or `nil` for a hairline one pixel thick on the screen
    /// the list is shown on.
    public var thickness: CGFloat?
    /// How far the line stops short of the row's edges. A vertical list uses the leading and
    /// trailing insets, a horizontal list the top and bottom ones.
    public var insets: EdgeInsets
    /// Whether a separator follows the last row too. Off by default, so separators only sit between
    /// rows.
    public var drawsAfterLast: Bool

    /// Creates a separator.
    ///
    /// - Parameters:
    ///   - color: The colour of the line. Defaults to the system separator colour.
    ///   - thickness: The thickness of the line in points, or `nil` for a hairline.
    ///   - insets: How far the line stops short of the row's edges.
    ///   - drawsAfterLast: Whether a separator follows the last row too.
    public init(
        color: Color = Color(UIColor.separator),
        thickness: CGFloat? = nil,
        insets: EdgeInsets = EdgeInsets(),
        drawsAfterLast: Bool = false
    ) {
        self.color = color
        self.thickness = thickness
        self.insets = insets
        self.drawsAfterLast = drawsAfterLast
    }

    /// The kind of the supplementary views that draw separators.
    static let elementKind = "RecyclerViewSeparator"

    /// The thickness in points on a screen with the given scale.
    func resolvedThickness(displayScale: CGFloat) -> CGFloat {
        if let thickness = thickness {
            return max(0, thickness)
        }
        return 1 / max(1, displayScale)
    }

    /// How far the separator's outer edge lies beyond the row's edge: centred in the gap between rows
    /// when the spacing has room for it, and along the inside of the row's edge otherwise.
    func offsetBeyondRow(spacing: CGFloat, thickness: CGFloat) -> CGFloat {
        spacing >= thickness ? (spacing + thickness) / 2 : 0
    }
}

/// The supplementary view that draws a ``RecyclerViewSeparator``.
@MainActor
final class SeparatorView: UICollectionReusableView {
    static let reuseIdentifier = "RecyclerViewSeparatorView"

    private var colorHost: UIHostingController<Color>?

    func configure(color: Color, isHidden hidden: Bool) {
        isHidden = hidden
        isUserInteractionEnabled = false

        if #available(iOS 14.0, *) {
            backgroundColor = UIColor(color)
            return
        }

        // Before iOS 14 a SwiftUI colour cannot be converted to a UIColor, so SwiftUI draws it.
        if let colorHost = colorHost {
            colorHost.rootView = color
            return
        }
        let colorHost = UIHostingController(rootView: color, ignoreSafeArea: true)
        colorHost.view.backgroundColor = .clear
        colorHost.view.frame = bounds
        colorHost.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(colorHost.view)
        self.colorHost = colorHost
    }
}
