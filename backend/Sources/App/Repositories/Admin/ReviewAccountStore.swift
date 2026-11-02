import Foundation
import FluentSQL

private struct IDRow: Decodable { let id: UUID }
private struct KindRow: Decodable { let id: UUID; let kind: String }

/// Shop rows a demo order points at (it needs a real district, slot and cake).
struct DemoReferences: Sendable {
    let districtID: UUID
    let districtName: String
    let feeVND: Int
    let slotID: UUID
    let slotStart: String
    let slotEnd: String
    let productID: UUID
    let productName: String
    let priceVND: Int
}

struct DemoOrderSeed: Sendable {
    let code: String
    let date: String
    let status: OrderStatus
    let cakes: Int
    let customerName: String
    let customerPhone: String
}

/// SQL of the operator command `review-account on|off` (ADR-0027). It never
/// touches a real order: every statement on orders carries `is_demo`.
struct ReviewAccountStore: Sendable {
    let sql: any SQLDatabase

    /// The review account row for `email`, created if missing and switched on.
    /// Nil when the address already belongs to a normal account.
    func enableAccount(shopID: UUID, email: String) async throws -> UUID? {
        let existing = try await sql.raw("SELECT id, kind FROM account WHERE shop_id = \(bind: shopID) AND email = \(bind: email)")
            .first(decoding: KindRow.self)
        if let existing {
            guard existing.kind == "review" else { return nil }
            try await sql.raw("UPDATE account SET is_active = true, deactivated_at = NULL, updated_at = now() WHERE id = \(bind: existing.id)").run()
            return existing.id
        }
        return try await sql.raw("""
            INSERT INTO account (shop_id, role, kind, email, display_name)
            VALUES (\(bind: shopID), 'staff', 'review', \(bind: email), \(bind: ReviewAccountConfig.displayName)) RETURNING id
            """).first(decoding: IDRow.self)?.id
    }

    /// Everything the review account has: sessions, open codes, demo orders and
    /// their lines and history, and the switch (`is_active`) of all review
    /// accounts of the shop. The account row stays because the
    /// append-only `security_event` refers to it.
    func clear(shopID: UUID) async throws {
        try await sql.raw("""
            DELETE FROM device_session WHERE account_id IN (SELECT id FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review')
            """).run()
        try await sql.raw("""
            UPDATE auth_code SET consumed_at = now() WHERE consumed_at IS NULL
               AND account_id IN (SELECT id FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review')
            """).run()
        try await sql.raw("DELETE FROM order_event WHERE order_id IN (SELECT id FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo)").run()
        try await sql.raw("DELETE FROM customer_order_item WHERE order_id IN (SELECT id FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo)").run()
        try await sql.raw("DELETE FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo").run()
        try await sql.raw("""
            UPDATE account SET is_active = false, deactivated_at = now(), updated_at = now()
             WHERE shop_id = \(bind: shopID) AND kind = 'review' AND is_active
            """).run()
    }

    func references(shopID: UUID) async throws -> DemoReferences? {
        let district = try await sql.raw("SELECT id, name, delivery_fee_vnd FROM district WHERE shop_id = \(bind: shopID) AND is_active ORDER BY sort_order, created_at LIMIT 1").first()
        let slot = try await sql.raw("SELECT id, to_char(start_time, 'HH24:MI') AS s, to_char(end_time, 'HH24:MI') AS e FROM delivery_slot WHERE shop_id = \(bind: shopID) AND is_active ORDER BY sort_order, start_time LIMIT 1").first()
        let product = try await sql.raw("SELECT id, name, price_vnd FROM product WHERE shop_id = \(bind: shopID) AND is_active AND removed_at IS NULL ORDER BY sort_order, created_at LIMIT 1").first()
        guard let district, let slot, let product else { return nil }
        return DemoReferences(
            districtID: try district.decode(column: "id", as: UUID.self), districtName: try district.decode(column: "name", as: String.self),
            feeVND: try district.decode(column: "delivery_fee_vnd", as: Int.self),
            slotID: try slot.decode(column: "id", as: UUID.self), slotStart: try slot.decode(column: "s", as: String.self),
            slotEnd: try slot.decode(column: "e", as: String.self),
            productID: try product.decode(column: "id", as: UUID.self), productName: try product.decode(column: "name", as: String.self),
            priceVND: try product.decode(column: "price_vnd", as: Int.self)
        )
    }

    /// False when the order code is taken (the caller draws another).
    func insertDemoOrder(shopID: UUID, seed: DemoOrderSeed, refs: DemoReferences) async throws -> Bool {
        let id = UUID(), subtotal = refs.priceVND * seed.cakes
        let inserted = try await sql.raw("""
            INSERT INTO customer_order (
                id, shop_id, order_code, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes,
                customer_name, customer_phone, customer_address, note, idempotency_key, request_hash,
                client_platform, app_version, is_demo)
            VALUES (\(bind: id), \(bind: shopID), \(bind: seed.code), \(bind: seed.date)::date, \(bind: refs.slotID),
                \(bind: refs.slotStart)::time, \(bind: refs.slotEnd)::time, \(bind: refs.districtID), \(bind: refs.districtName),
                \(bind: refs.feeVND), \(bind: subtotal), \(bind: subtotal + refs.feeVND), \(bind: seed.cakes),
                \(bind: seed.customerName), \(bind: seed.customerPhone), 'Demo address, not a real place', 'Demo order',
                \(bind: UUID()), \(bind: String(repeating: "d", count: 64)), 'ios', '1.0.0', true)
            ON CONFLICT DO NOTHING RETURNING id
            """).first(decoding: IDRow.self)
        guard inserted != nil else { return false }
        try await sql.raw("""
            INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd)
            VALUES (\(bind: id), \(bind: refs.productID), \(bind: refs.productName), \(bind: refs.priceVND), \(bind: seed.cakes), \(bind: subtotal))
            """).run()
        try await sql.raw("INSERT INTO order_event (order_id, event_type, from_status, to_status, actor_type) VALUES (\(bind: id), 'created', NULL, \(bind: OrderStatus.received.rawValue), 'system')").run()
        if seed.status != .received {
            try await sql.raw("UPDATE customer_order SET status = \(bind: seed.status.rawValue) WHERE id = \(bind: id)").run()
        }
        return true
    }
}
