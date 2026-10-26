import BanhContracts

/// Destinations pushed on the navigation stack after S-2.
enum Route: Hashable {
    case products
    case productDetail(ResourceID)
    /// The order flow, from S-2 or S-4. The ordering slice passes the chosen cake (FR-4, AC-5).
    case order
}
