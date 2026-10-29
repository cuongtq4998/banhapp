import BanhContracts

/// Destinations pushed on the navigation stack after S-2.
enum Route: Hashable {
    case products
    case productDetail(ResourceID)
    /// One step of the order flow, S-5 to S-8; `OrderCoordinator` builds them.
    case orderStep(OrderStep)
}
