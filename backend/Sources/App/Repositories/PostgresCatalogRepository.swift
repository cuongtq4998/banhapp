import Foundation
import Fluent
import FluentSQL
import BanhContracts

/// The SQL behind `GET /v1/catalog`. Read-only, parameterised, one query per
/// table: five small statements are simpler than a join that repeats the shop
/// columns on every row, and a read that straddles an owner edit is harmless
/// because the response is hashed into its `ETag` as a whole.
struct PostgresCatalogRepository: CatalogRepository {
    let database: any Database

    func loadCatalog(shopID: UUID) async throws -> CatalogSnapshot {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        // Sequential on purpose: concurrent queries would each take a pool
        // connection, and the pool is small on the free database plan.
        return try await translatingDatabaseErrors {
            CatalogSnapshot(
                shop: try await Self.fetchShop(shopID, on: sql),
                ordering: try await Self.fetchOrdering(shopID, on: sql),
                products: try await Self.fetchProducts(shopID, on: sql),
                districts: try await Self.fetchDistricts(shopID, on: sql),
                slots: try await Self.fetchSlots(shopID, on: sql)
            )
        }
    }

    private static func fetchShop(_ shopID: UUID, on sql: any SQLDatabase) async throws -> CatalogShop {
        let row = try await sql.raw("""
            SELECT name, greeting, phone_contact, zalo_contact FROM shop WHERE id = \(bind: shopID)
            """).first(decoding: ShopRow.self)
        guard let row else { throw CatalogRepositoryError.shopNotFound }
        return row.toContract()
    }

    private static func fetchOrdering(_ shopID: UUID, on sql: any SQLDatabase) async throws -> OrderingParameters {
        let row = try await sql.raw("""
            SELECT min_qty, lead_days, max_days_ahead, max_qty_per_cake
            FROM shop_setting WHERE shop_id = \(bind: shopID)
            """).first(decoding: OrderingRow.self)
        guard let row else { throw CatalogRepositoryError.shopNotFound }
        return row.toDomain()
    }

    // The id is the last sort key so equal `sort_order` values still give a
    // stable order, and therefore a stable ETag.
    private static func fetchProducts(_ shopID: UUID, on sql: any SQLDatabase) async throws -> [ProductRecord] {
        try await sql.raw("""
            SELECT id, slug, name, description, price_vnd, image_path FROM product
            WHERE shop_id = \(bind: shopID) AND is_active
            ORDER BY sort_order, id
            """).all(decoding: ProductRow.self).map { $0.toDomain() }
    }

    private static func fetchDistricts(_ shopID: UUID, on sql: any SQLDatabase) async throws -> [CatalogDistrict] {
        try await sql.raw("""
            SELECT id, name, delivery_fee_vnd FROM district
            WHERE shop_id = \(bind: shopID) AND is_active
            ORDER BY sort_order, id
            """).all(decoding: DistrictRow.self).map { $0.toContract() }
    }

    // The database formats the times as `HH:MM`, which is the wire form, so no
    // client or Swift date type is involved.
    private static func fetchSlots(_ shopID: UUID, on sql: any SQLDatabase) async throws -> [CatalogSlot] {
        try await sql.raw("""
            SELECT id, to_char(start_time, 'HH24:MI') AS start_time, to_char(end_time, 'HH24:MI') AS end_time
            FROM delivery_slot
            WHERE shop_id = \(bind: shopID) AND is_active
            ORDER BY sort_order, start_time, id
            """).all(decoding: SlotRow.self).map { $0.toContract() }
    }
}

// Row shapes: private, because column names are an implementation detail of
// this file.

private struct ShopRow: Decodable {
    let name: String
    let greeting: String
    let phoneContact: String
    let zaloContact: String

    private enum CodingKeys: String, CodingKey {
        case name, greeting
        case phoneContact = "phone_contact"
        case zaloContact = "zalo_contact"
    }

    func toContract() -> CatalogShop {
        CatalogShop(name: name, greeting: greeting, phoneContact: phoneContact, zaloContact: zaloContact)
    }
}

private struct OrderingRow: Decodable {
    let minQty: Int
    let leadDays: Int
    let maxDaysAhead: Int
    let maxQtyPerCake: Int

    private enum CodingKeys: String, CodingKey {
        case minQty = "min_qty"
        case leadDays = "lead_days"
        case maxDaysAhead = "max_days_ahead"
        case maxQtyPerCake = "max_qty_per_cake"
    }

    func toDomain() -> OrderingParameters {
        OrderingParameters(minQty: minQty, leadDays: leadDays, maxDaysAhead: maxDaysAhead, maxQtyPerCake: maxQtyPerCake)
    }
}

private struct ProductRow: Decodable {
    let id: UUID
    let slug: String
    let name: String
    let description: String
    let priceVND: Int
    let imagePath: String

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, description
        case priceVND = "price_vnd"
        case imagePath = "image_path"
    }

    func toDomain() -> ProductRecord {
        ProductRecord(id: id, slug: slug, name: name, description: description, priceVND: priceVND, imagePath: imagePath)
    }
}

private struct DistrictRow: Decodable {
    let id: UUID
    let name: String
    let deliveryFeeVND: Int

    private enum CodingKeys: String, CodingKey {
        case id, name
        case deliveryFeeVND = "delivery_fee_vnd"
    }

    func toContract() -> CatalogDistrict {
        CatalogDistrict(districtID: ResourceID(id), name: name, deliveryFeeVND: deliveryFeeVND)
    }
}

private struct SlotRow: Decodable {
    let id: UUID
    let startTime: String
    let endTime: String

    private enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
    }

    func toContract() -> CatalogSlot {
        CatalogSlot(slotID: ResourceID(id), start: startTime, end: endTime)
    }
}
