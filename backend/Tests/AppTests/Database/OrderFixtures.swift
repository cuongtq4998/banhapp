import Foundation
import FluentSQL
import XCTest
@testable import App

/// Rows needed to exercise the order triggers. All values are fake.
struct OrderFixture {
    let shopID: UUID
    let orderID: UUID
    let deliveryDate: String
    let totalCakes: Int
    let capacityLimit: Int

    static let fakePhone = "+84912345678"

    /// Inserts a shop, slot, district, a `day_load` row already holding the
    /// order's cakes, and one `New` order.
    static func insert(
        on sql: any SQLDatabase,
        totalCakes: Int = 6,
        capacityLimit: Int = 20,
        deliveryDate: String = "2030-01-15"
    ) async throws -> OrderFixture {
        let shopID = UUID()
        let slotID = UUID()
        let districtID = UUID()
        let orderID = UUID()
        let code = RandomOrderCodeGenerator().makeCode()
        let unitPrice = 100_000
        let fee = 20_000

        try await sql.raw("""
            INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact, is_sample)
            VALUES (\(bind: shopID), 'Test shop', 'Hello', '+84900000000', 'zalo-test', true)
            """).run()
        try await sql.raw("""
            INSERT INTO delivery_slot (id, shop_id, start_time, end_time, is_sample)
            VALUES (\(bind: slotID), \(bind: shopID), '08:00', '10:00', true)
            """).run()
        try await sql.raw("""
            INSERT INTO district (id, shop_id, name, delivery_fee_vnd, is_sample)
            VALUES (\(bind: districtID), \(bind: shopID), 'Test district', \(literal: fee), true)
            """).run()
        try await sql.raw("""
            INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit)
            VALUES (\(bind: shopID), \(bind: deliveryDate)::date, \(literal: totalCakes), \(literal: capacityLimit))
            """).run()
        try await sql.raw("""
            INSERT INTO customer_order (
                id, shop_id, order_code, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes,
                customer_name, customer_phone, customer_address, idempotency_key, request_hash,
                client_platform, app_version)
            VALUES (
                \(bind: orderID), \(bind: shopID), \(bind: code), \(bind: deliveryDate)::date, \(bind: slotID),
                '08:00', '10:00', \(bind: districtID), 'Test district', \(literal: fee),
                \(literal: unitPrice * totalCakes), \(literal: unitPrice * totalCakes + fee), \(literal: totalCakes),
                'Test Customer', \(literal: fakePhone), '1 Test Street', \(bind: UUID()), \(bind: String(repeating: "a", count: 64)),
                'ios', '1.0.0')
            """).run()
        return OrderFixture(
            shopID: shopID, orderID: orderID, deliveryDate: deliveryDate,
            totalCakes: totalCakes, capacityLimit: capacityLimit
        )
    }

    func setStatus(_ status: String, on sql: any SQLDatabase) async throws {
        try await sql.raw("UPDATE customer_order SET status = \(bind: status) WHERE id = \(bind: orderID)").run()
    }

    func cakesAccepted(on sql: any SQLDatabase) async throws -> Int {
        let row = try await sql.raw("""
            SELECT cakes_accepted FROM day_load
            WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: deliveryDate)::date
            """).first()
        return try XCTUnwrap(row).decode(column: "cakes_accepted", as: Int.self)
    }

    struct Event: Equatable {
        let fromStatus: String?
        let toStatus: String
        let actorType: String
        let actorID: UUID?
    }

    func events(on sql: any SQLDatabase) async throws -> [Event] {
        let rows = try await sql.raw("""
            SELECT from_status, to_status, actor_type, actor_id FROM order_event
            WHERE order_id = \(bind: orderID) ORDER BY id
            """).all()
        return try rows.map { row in
            Event(
                fromStatus: try row.decode(column: "from_status", as: String?.self),
                toStatus: try row.decode(column: "to_status", as: String.self),
                actorType: try row.decode(column: "actor_type", as: String.self),
                actorID: try row.decode(column: "actor_id", as: UUID?.self)
            )
        }
    }
}

/// Inside one transaction a failed statement aborts everything after it, so
/// each statement that must fail runs under a savepoint that is rolled back.
func assertRejected(
    by sql: any SQLDatabase,
    _ statement: SQLQueryString,
    file: StaticString = #filePath,
    line: UInt = #line
) async throws {
    try await sql.raw("SAVEPOINT expect_failure").run()
    do {
        try await sql.raw(statement).run()
        XCTFail("statement was accepted but must be rejected", file: file, line: line)
        try await sql.raw("RELEASE SAVEPOINT expect_failure").run()
    } catch {
        try await sql.raw("ROLLBACK TO SAVEPOINT expect_failure").run()
    }
}
