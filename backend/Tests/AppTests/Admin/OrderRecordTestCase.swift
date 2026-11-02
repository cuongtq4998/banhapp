import XCTVapor
@testable import App

/// Seeding of the three change records, shared by the last change and fee entry tests.
class OrderRecordTestCase: OrderCorrectionTestCase {
    func addEvent(_ orderCode: String, from: String? = nil, to: String, actor: String?, at: Date) async throws {
        try await run("""
            INSERT INTO order_event (order_id, event_type, from_status, to_status, actor_type, actor_name, created_at)
            SELECT id, 'status_changed', \(bind: from)::text, \(bind: to), 'staff', \(bind: actor)::text, \(timestamp(at))
            FROM customer_order WHERE order_code = \(bind: orderCode)
            """)
    }

    func addDateChange(_ orderCode: String, name: String, at: Date) async throws {
        try await run("""
            INSERT INTO order_expected_date_change (order_id, old_date, new_date, changed_by_name, changed_at)
            SELECT id, \(bind: day(2))::date, \(bind: day(3))::date, \(bind: name), \(timestamp(at))
            FROM customer_order WHERE order_code = \(bind: orderCode)
            """)
    }

    func addFeeChange(_ orderCode: String, name: String, at: Date) async throws {
        try await run("""
            INSERT INTO order_fee_correction (order_id, old_fee_vnd, new_fee_vnd, changed_by_name, changed_at)
            SELECT id, 25000, 30000, \(bind: name), \(timestamp(at))
            FROM customer_order WHERE order_code = \(bind: orderCode)
            """)
    }

    func lastChange(_ phone: Phone, _ orderCode: String) async throws -> [String: Any] {
        let reply = try await detail(phone, orderCode)
        return try XCTUnwrap(reply.json["last_change"] as? [String: Any])
    }

    func started(_ date: String? = nil) async throws -> String {
        try await place(.init(status: "DeliveryStarted", expectedDate: date ?? day(2), finalFee: 25_000))
    }
}
