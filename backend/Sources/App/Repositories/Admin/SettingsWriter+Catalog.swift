import Foundation
import FluentSQL

/// District and slot writes. All run after `SettingsWriter.lock`.
extension SettingsWriter {
    func district(shopID: UUID, id: UUID) async throws -> DistrictView? {
        try await sql.raw("""
            SELECT id AS district_id, name, delivery_fee_vnd, is_active FROM district
            WHERE shop_id = \(bind: shopID) AND id = \(bind: id)
            """).first(decoding: DistrictView.self)
    }

    /// Names are unique ignoring letter case, active or not.
    func districtNameTaken(shopID: UUID, name: String, excluding id: UUID?) async throws -> Bool {
        try await sql.raw("""
            SELECT 1 AS one FROM district
            WHERE shop_id = \(bind: shopID) AND lower(name) = lower(\(bind: name)) AND id IS DISTINCT FROM \(bind: id)
            """).first() != nil
    }

    func otherActiveDistricts(shopID: UUID, besides id: UUID) async throws -> Int {
        try await sql.raw("SELECT count(*)::int AS n FROM district WHERE shop_id = \(bind: shopID) AND is_active AND id <> \(bind: id)")
            .first()?.decode(column: "n", as: Int.self) ?? 0
    }

    func insertDistrict(shopID: UUID, _ value: DistrictView, at now: Date) async throws {
        try await sql.raw("""
            INSERT INTO district (id, shop_id, name, delivery_fee_vnd, is_active, sort_order, created_at, updated_at)
            VALUES (\(bind: value.districtID), \(bind: shopID), \(bind: value.name), \(bind: value.deliveryFeeVND), \(bind: value.isActive),
                    (SELECT coalesce(max(sort_order), 0) + 1 FROM district WHERE shop_id = \(bind: shopID)), \(timestamp(now)), \(timestamp(now)))
            """).run()
    }

    func updateDistrict(_ value: DistrictView, at now: Date) async throws {
        try await sql.raw("""
            UPDATE district SET name = \(bind: value.name), delivery_fee_vnd = \(bind: value.deliveryFeeVND),
                is_active = \(bind: value.isActive), updated_at = \(timestamp(now))
            WHERE id = \(bind: value.districtID)
            """).run()
    }

    func slot(shopID: UUID, id: UUID) async throws -> SlotView? {
        try await sql.raw("""
            SELECT id AS slot_id, to_char(start_time, 'HH24:MI') AS start, to_char(end_time, 'HH24:MI') AS "end", is_active
            FROM delivery_slot WHERE shop_id = \(bind: shopID) AND id = \(bind: id)
            """).first(decoding: SlotView.self)
    }

    func slotPairTaken(shopID: UUID, start: String, end: String, excluding id: UUID?) async throws -> Bool {
        try await sql.raw("""
            SELECT 1 AS one FROM delivery_slot
            WHERE shop_id = \(bind: shopID) AND start_time = \(bind: start)::time AND end_time = \(bind: end)::time
              AND id IS DISTINCT FROM \(bind: id)
            """).first() != nil
    }

    func otherActiveSlots(shopID: UUID, besides id: UUID) async throws -> Int {
        try await sql.raw("SELECT count(*)::int AS n FROM delivery_slot WHERE shop_id = \(bind: shopID) AND is_active AND id <> \(bind: id)")
            .first()?.decode(column: "n", as: Int.self) ?? 0
    }

    func insertSlot(shopID: UUID, _ value: SlotView, at now: Date) async throws {
        try await sql.raw("""
            INSERT INTO delivery_slot (id, shop_id, start_time, end_time, is_active, created_at, updated_at)
            VALUES (\(bind: value.slotID), \(bind: shopID), \(bind: value.start)::time, \(bind: value.end)::time,
                    \(bind: value.isActive), \(timestamp(now)), \(timestamp(now)))
            """).run()
    }

    func updateSlot(_ value: SlotView, at now: Date) async throws {
        try await sql.raw("""
            UPDATE delivery_slot SET start_time = \(bind: value.start)::time, end_time = \(bind: value.end)::time,
                is_active = \(bind: value.isActive), updated_at = \(timestamp(now))
            WHERE id = \(bind: value.slotID)
            """).run()
    }

    /// The customer catalog sorts slots by `sort_order` first, so after a slot
    /// is added or moved the numbers follow the clock times.
    func renumberSlots(shopID: UUID, at now: Date) async throws {
        try await sql.raw("""
            UPDATE delivery_slot s SET sort_order = r.position, updated_at = \(timestamp(now))
            FROM (SELECT id, (row_number() OVER (ORDER BY start_time, end_time))::int AS position
                  FROM delivery_slot WHERE shop_id = \(bind: shopID)) r
            WHERE s.id = r.id AND s.sort_order <> r.position
            """).run()
    }
}
