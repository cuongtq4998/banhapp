import Foundation
import BanhContracts

/// What the catalogue repository reads: the tables behind `GET /v1/catalog`.
///
/// Shop contact, districts and slots are already in their contract shape, so
/// they are reused as they are. Products carry the stored image path (the
/// service turns it into a URL), and the ordering parameters lack the note
/// length, which is an input-safety bound and not a table column (ADR-0013).
struct CatalogSnapshot: Equatable, Sendable {
    let shop: CatalogShop
    let ordering: OrderingParameters
    let products: [ProductRecord]
    let districts: [CatalogDistrict]
    let slots: [CatalogSlot]
}

/// The columns of `shop_setting` that customers may see. The daily limit is
/// deliberately not here (api.md 4.1: never shown to customers).
struct OrderingParameters: Equatable, Sendable {
    let minQty: Int
    let leadDays: Int
    let maxDaysAhead: Int
    let maxQtyPerCake: Int
}

struct ProductRecord: Equatable, Sendable {
    let id: UUID
    let slug: String
    let name: String
    let description: String
    let priceVND: Int
    /// Relative to the assets directory, for example `images/banana.png`.
    let imagePath: String
}
