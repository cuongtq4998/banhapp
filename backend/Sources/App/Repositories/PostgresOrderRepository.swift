import Foundation
import Fluent
import FluentSQL

/// The read side of `POST /v1/orders`; the transaction is in
/// `PostgresOrderRepository+Insert`. Parameterised SQL only: values never
/// become part of the statement text.
struct PostgresOrderRepository: OrderRepository {
    let database: any Database

    func loadReferenceData(shopID: UUID, productIDs: [UUID], slotID: UUID, districtID: UUID) async throws -> OrderReferenceData {
        let sql = try requireSQL()
        // Reuses the availability SQL, so the order and the date list read the same rules.
        let rules = try await PostgresAvailabilityRepository(database: database).loadRules(shopID: shopID)
        return try await translatingDatabaseErrors {
            let setting = try await sql.raw("SELECT min_qty FROM shop_setting WHERE shop_id = \(bind: shopID)")
                .first(decoding: MinQtyRow.self)
            guard let setting else { throw CatalogRepositoryError.shopNotFound }
            let products = try await sql.raw("""
                SELECT id, name, price_vnd, is_active FROM product
                WHERE shop_id = \(bind: shopID) AND id IN (\(binds: productIDs))
                """).all(decoding: ProductRow.self)
            let slot = try await sql.raw("""
                SELECT id, to_char(start_time, 'HH24:MI:SS') AS start_time,
                       to_char(end_time, 'HH24:MI:SS') AS end_time, is_active
                FROM delivery_slot WHERE shop_id = \(bind: shopID) AND id = \(bind: slotID)
                """).first(decoding: SlotRow.self)
            let district = try await sql.raw("""
                SELECT id, name, delivery_fee_vnd, is_active FROM district
                WHERE shop_id = \(bind: shopID) AND id = \(bind: districtID)
                """).first(decoding: DistrictRow.self)
            return OrderReferenceData(
                rules: rules, minQty: setting.minQty,
                products: Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0.toDomain()) }),
                slot: slot?.toDomain(), district: district?.toDomain()
            )
        }
    }

    func findOrder(shopID: UUID, idempotencyKey: UUID) async throws -> StoredOrder? {
        let sql = try requireSQL()
        return try await translatingDatabaseErrors { try await PostgresOrderQueries.findOrder(sql, shopID, idempotencyKey) }
    }

    func countOrders(shopID: UUID, phone: String, since: Date) async throws -> Int {
        let sql = try requireSQL()
        return try await translatingDatabaseErrors {
            let row = try await sql.raw("""
                SELECT count(*)::int AS total FROM customer_order
                WHERE shop_id = \(bind: shopID) AND customer_phone = \(bind: phone)
                  AND created_at >= \(bind: PostgresTimestamp.text(since))::timestamptz
                """).first(decoding: CountRow.self)
            return row?.total ?? 0
        }
    }

    func requireSQL() throws -> any SQLDatabase {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        return sql
    }
}

/// Instants cross the driver as ISO 8601 text with a cast, as dates do in
/// `PostgresAvailabilityRepository`, so no driver date conversion is involved.
enum PostgresTimestamp {
    static func text(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}

enum PostgresOrderQueries {
    /// `created_at` is formatted by the database to whole seconds in UTC, so a
    /// replay prints exactly what the first answer printed.
    static let createdAtText = "to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')"

    static func findOrder(_ sql: any SQLDatabase, _ shopID: UUID, _ key: UUID) async throws -> StoredOrder? {
        let row = try await sql.raw("""
            SELECT order_code, \(unsafeRaw: createdAtText) AS created_at, request_hash
            FROM customer_order WHERE shop_id = \(bind: shopID) AND idempotency_key = \(bind: key)
            """).first(decoding: StoredRow.self)
        return row.map { StoredOrder(placed: PlacedOrder(orderCode: $0.orderCode, createdAt: $0.createdAt), requestHash: $0.requestHash) }
    }
}

private struct MinQtyRow: Decodable {
    let minQty: Int
    private enum CodingKeys: String, CodingKey { case minQty = "min_qty" }
}

private struct CountRow: Decodable { let total: Int }

private struct StoredRow: Decodable {
    let orderCode: String
    let createdAt: String
    let requestHash: String
    private enum CodingKeys: String, CodingKey {
        case orderCode = "order_code"
        case createdAt = "created_at"
        case requestHash = "request_hash"
    }
}

private struct ProductRow: Decodable {
    let id: UUID
    let name: String
    let priceVND: Int
    let isActive: Bool
    private enum CodingKeys: String, CodingKey {
        case id, name
        case priceVND = "price_vnd"
        case isActive = "is_active"
    }
    func toDomain() -> OrderProductRecord { .init(id: id, name: name, priceVND: priceVND, isActive: isActive) }
}

private struct SlotRow: Decodable {
    let id: UUID
    let startTime: String
    let endTime: String
    let isActive: Bool
    private enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case isActive = "is_active"
    }
    func toDomain() -> OrderSlotRecord { .init(id: id, startTime: startTime, endTime: endTime, isActive: isActive) }
}

private struct DistrictRow: Decodable {
    let id: UUID
    let name: String
    let deliveryFeeVND: Int
    let isActive: Bool
    private enum CodingKeys: String, CodingKey {
        case id, name
        case deliveryFeeVND = "delivery_fee_vnd"
        case isActive = "is_active"
    }
    func toDomain() -> OrderDistrictRecord { .init(id: id, name: name, deliveryFeeVND: deliveryFeeVND, isActive: isActive) }
}
