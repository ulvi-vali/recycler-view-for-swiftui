import CoreGraphics

enum RecyclerViewDefaults {
    /// The page size used when pagination is enabled without one.
    static let pageSize = 50
    /// The next page is requested once an item this close to the end is displayed.
    static let loadMoreTriggerDistance = 5
    /// Displaying an item this far from the end re-arms pagination.
    static let loadMoreResetDistance = 10
    /// The height rows are estimated at before they size themselves.
    static let estimatedItemHeight: CGFloat = 110
    /// The width items in a horizontal list are estimated at before they size themselves.
    static let estimatedItemWidth: CGFloat = 150
    /// The width columns in a horizontal grid are estimated at before they size themselves.
    static let estimatedGridColumnWidth: CGFloat = 100
}
