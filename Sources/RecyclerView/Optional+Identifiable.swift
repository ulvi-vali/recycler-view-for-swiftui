// Lets an array of optionals be passed to RecyclerView, which suits placeholder rows shown while
// content loads. `nil` items have no identity of their own, so the adapter identifies them by
// position; see RecyclerViewAdapter.getItemIDString(for:at:).

#if compiler(>=6.0)
extension Optional: @retroactive Identifiable where Wrapped: Identifiable {
    public var id: Wrapped.ID? {
        switch self {
        case .some(let value):
            return value.id
        case .none:
            return nil
        }
    }
}
#else
extension Optional: Identifiable where Wrapped: Identifiable {
    public var id: Wrapped.ID? {
        switch self {
        case .some(let value):
            return value.id
        case .none:
            return nil
        }
    }
}
#endif
