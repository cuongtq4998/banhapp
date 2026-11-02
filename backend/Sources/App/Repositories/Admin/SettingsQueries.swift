import Foundation
import FluentSQL

/// Reads of the owner settings screen. Rows decode into the view types.
struct SettingsQueries: Sendable {
    let sql: any SQLDatabase

    func shop(id: UUID) async throws -> ShopSection? {
        try await sql.raw("""
            SELECT name, greeting, phone_contact, zalo_contact FROM shop WHERE id = \(bind: id)
            """).first(decoding: ShopSection.self)
    }

    func ordering(shopID: UUID) async throws -> OrderingSection? {
        try await sql.raw("""
            SELECT daily_limit, lead_days, min_qty, max_days_ahead FROM shop_setting WHERE shop_id = \(bind: shopID)
            """).first(decoding: OrderingSection.self)
    }

    /// Dates from `today` on that hold more cakes than `limit` (day_load only).
    func overLimit(shopID: UUID, today: String, limit: Int) async throws -> [OverLimitDate] {
        try await sql.raw("""
            SELECT to_char(delivery_date, 'YYYY-MM-DD') AS date, cakes_accepted FROM day_load
            WHERE shop_id = \(bind: shopID) AND delivery_date >= \(bind: today)::date AND cakes_accepted > \(bind: limit)
            ORDER BY delivery_date
            """).all(decoding: OverLimitDate.self)
    }

    /// Cakes that are not removed, in shelf order (api/07 10.13).
    func cakes(shopID: UUID, assets: AssetURLBuilder) async throws -> [CakeView] {
        try await sql.raw("\(CakeRow.select) WHERE p.shop_id = \(bind: shopID) AND p.removed_at IS NULL ORDER BY p.sort_order, p.id")
            .all(decoding: CakeRow.self).map { $0.view(assets) }
    }

    func cake(shopID: UUID, id: UUID, assets: AssetURLBuilder) async throws -> CakeView? {
        try await sql.raw("\(CakeRow.select) WHERE p.shop_id = \(bind: shopID) AND p.id = \(bind: id) AND p.removed_at IS NULL")
            .first(decoding: CakeRow.self).map { $0.view(assets) }
    }

    func districts(shopID: UUID) async throws -> [DistrictView] {
        try await sql.raw("""
            SELECT id AS district_id, name, delivery_fee_vnd, is_active FROM district
            WHERE shop_id = \(bind: shopID) ORDER BY sort_order, id
            """).all(decoding: DistrictView.self)
    }

    func slots(shopID: UUID) async throws -> [SlotView] {
        try await sql.raw("""
            SELECT id AS slot_id, to_char(start_time, 'HH24:MI') AS start, to_char(end_time, 'HH24:MI') AS "end", is_active
            FROM delivery_slot WHERE shop_id = \(bind: shopID) ORDER BY start_time, end_time, id
            """).all(decoding: SlotView.self)
    }
}
