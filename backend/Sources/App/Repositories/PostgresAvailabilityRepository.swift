import Foundation
import Fluent
import FluentSQL

/// The SQL behind `GET /v1/availability`. Read-only and parameterised.
struct PostgresAvailabilityRepository: AvailabilityRepository {
    let database: any Database

    func loadRules(shopID: UUID) async throws -> AvailabilityRules {
        let sql = try requireSQL()
        return try await translatingDatabaseErrors {
            let row = try await sql.raw("""
                SELECT s.lead_days, s.max_days_ahead, s.daily_limit, s.max_qty_per_cake,
                       (SELECT count(*) FROM product p WHERE p.shop_id = s.shop_id AND p.is_active) AS active_products
                FROM shop_setting s WHERE s.shop_id = \(bind: shopID)
                """).first(decoding: RulesRow.self)
            guard let row else { throw CatalogRepositoryError.shopNotFound }
            return row.toDomain()
        }
    }

    // The date column is formatted by the database as `YYYY-MM-DD` and the
    // bounds are bound as text and cast, so no driver date type or time zone
    // conversion is involved: `delivery_date` is a plain calendar date.
    func loadAcceptedCakes(shopID: UUID, from: BusinessDate, through: BusinessDate) async throws -> [BusinessDate: Int] {
        let sql = try requireSQL()
        return try await translatingDatabaseErrors {
            let rows = try await sql.raw("""
                SELECT to_char(delivery_date, 'YYYY-MM-DD') AS delivery_date, cakes_accepted
                FROM day_load
                WHERE shop_id = \(bind: shopID)
                  AND delivery_date BETWEEN \(bind: from.description)::date AND \(bind: through.description)::date
                """).all(decoding: DayLoadRow.self)
            return try Dictionary(uniqueKeysWithValues: rows.map { try $0.toEntry() })
        }
    }

    private func requireSQL() throws -> any SQLDatabase {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        return sql
    }
}

private struct RulesRow: Decodable {
    let leadDays: Int
    let maxDaysAhead: Int
    let dailyLimit: Int
    let maxQtyPerCake: Int
    let activeProducts: Int

    private enum CodingKeys: String, CodingKey {
        case leadDays = "lead_days"
        case maxDaysAhead = "max_days_ahead"
        case dailyLimit = "daily_limit"
        case maxQtyPerCake = "max_qty_per_cake"
        case activeProducts = "active_products"
    }

    func toDomain() -> AvailabilityRules {
        AvailabilityRules(
            leadDays: leadDays, maxDaysAhead: maxDaysAhead, dailyLimit: dailyLimit,
            activeProductCount: activeProducts, maxQtyPerCake: maxQtyPerCake
        )
    }
}

private struct DayLoadRow: Decodable {
    let deliveryDate: String
    let cakesAccepted: Int

    private enum CodingKeys: String, CodingKey {
        case deliveryDate = "delivery_date"
        case cakesAccepted = "cakes_accepted"
    }

    /// A date the database formatted but we cannot parse would mean a schema
    /// mismatch, so it surfaces as a decoding error (`INTERNAL_ERROR`).
    func toEntry() throws -> (BusinessDate, Int) {
        guard let date = BusinessDate(isoString: deliveryDate) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.deliveryDate], debugDescription: "Not a date"))
        }
        return (date, cakesAccepted)
    }
}
