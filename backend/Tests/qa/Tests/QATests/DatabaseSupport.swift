import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Statement helpers; a Sendable value so the transaction closures need no `self`.
struct Q: Sendable {
    struct N: Decodable { let n: Int }
    struct S: Decodable { let s: String? }
    func run(_ tx: any SQLDatabase, _ sql: String) async throws {
        try await tx.raw(SQLQueryString(sql)).run()
    }

    /// True when the statement was rejected; the failed statement is undone.
    func rejected(_ tx: any SQLDatabase, _ sql: String) async throws -> Bool {
        try await tx.raw("SAVEPOINT qa_sp").run()
        do {
            try await run(tx, sql)
            try await tx.raw("RELEASE SAVEPOINT qa_sp").run()
            return false
        } catch {
            try await tx.raw("ROLLBACK TO SAVEPOINT qa_sp").run()
            return true
        }
    }

    func count(_ tx: any SQLDatabase, _ sql: String) async throws -> Int {
        try await tx.raw(SQLQueryString(sql)).first(decoding: N.self)?.n ?? -1
    }

    func text(_ tx: any SQLDatabase, _ sql: String) async throws -> String? {
        try await tx.raw(SQLQueryString(sql)).first(decoding: S.self)?.s
    }

    enum Ids {
        static let shop = "'aaaaaaaa-0000-4000-8000-000000000001'"
        static let product = "'aaaaaaaa-0000-4000-8000-000000000011'"
        static let district = "'aaaaaaaa-0000-4000-8000-000000000021'"
        static let slot = "'aaaaaaaa-0000-4000-8000-000000000031'"
        static let order = "'aaaaaaaa-0000-4000-8000-0000000000a1'"
        static let key = "'aaaaaaaa-0000-4000-8000-0000000000b1'"
    }

    func insertShopGraph(_ tx: any SQLDatabase, capacity: Int = 10, accepted: Int = 0, date: String = "2030-01-10", withDayLoad: Bool = true) async throws {
        try await run(tx, """
        INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact, is_sample)
        VALUES (\(Ids.shop), 'QA shop', 'QA greeting', '+84123456789', '84123456789', true)
        """)
        try await run(tx, "INSERT INTO shop_setting (shop_id, daily_limit, is_sample) VALUES (\(Ids.shop), \(capacity), true)")
        try await run(tx, """
        INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path, is_sample)
        VALUES (\(Ids.product), \(Ids.shop), 'qa-cake', 'QA cake', 'QA description', 50000, 'images/qa.png', true)
        """)
        try await run(tx, "INSERT INTO district (id, shop_id, name, delivery_fee_vnd, is_sample) VALUES (\(Ids.district), \(Ids.shop), 'QA district', 20000, true)")
        try await run(tx, "INSERT INTO delivery_slot (id, shop_id, start_time, end_time, is_sample) VALUES (\(Ids.slot), \(Ids.shop), '08:00', '10:00', true)")
        if withDayLoad {
            try await run(tx, "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '\(date)', \(accepted), \(capacity))")
        }
    }

    func orderInsert(id: String = Ids.order, key: String = Ids.key, code: String = "'BT-ABC234'", cakes: Int = 2,
                             date: String = "2030-01-10", status: String = "New",
                             phone: String = "+84901234567", subtotal: Int? = nil, total: Int? = nil) -> String {
        let sub = subtotal ?? cakes * 50000
        return """
        INSERT INTO customer_order (id, shop_id, order_code, status, delivery_date, slot_id, slot_start_time, slot_end_time,
            district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes, customer_name,
            customer_phone, customer_address, idempotency_key, request_hash, client_platform, app_version)
        VALUES (\(id), \(Ids.shop), \(code), '\(status)', '\(date)', \(Ids.slot), '08:00', '10:00',
            \(Ids.district), 'QA district', 20000, \(sub), \(total ?? sub + 20000), \(cakes), 'QA Customer',
            '\(phone)', '1 QA street', \(key), '\(String(repeating: "a", count: 64))', 'ios', '1.0.0')
        """
    }


    func expectRejected(_ tx: any SQLDatabase, _ sql: String, _ label: String = "", line: UInt = #line) async throws {
        let r = try await rejected(tx, sql)
        XCTAssertTrue(r, "should be rejected: \(label) \(sql.prefix(80))", line: line)
    }
    func expectCount(_ tx: any SQLDatabase, _ sql: String, _ expected: Int, line: UInt = #line) async throws {
        let r = try await count(tx, sql)
        XCTAssertEqual(r, expected, sql.prefix(100).description, line: line)
    }
    func expectText(_ tx: any SQLDatabase, _ sql: String, _ expected: String, line: UInt = #line) async throws {
        let r = try await text(tx, sql)
        XCTAssertEqual(r, expected, sql.prefix(100).description, line: line)
    }
}

let q = Q()
typealias Ids = Q.Ids
