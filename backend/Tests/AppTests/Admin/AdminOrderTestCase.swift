import XCTVapor
import Fluent
import FluentSQL
import Foundation
@testable import App

/// One row to insert with `AdminOrderTestCase.place`. Defaults: a New order of 2
/// cakes for 08:00 to 10:00, placed an hour ago, for a real (not demo) customer.
struct SeedOrder {
    var number = 0
    var status = "New"
    var date: String?
    var slot = "08:00"
    var placed: Date?
    var cakes = 2
    var name = "Tran Thi B"
    var phone = "+84900000010"
    var demo = false
    var reason: String?
}

/// Shared setup of the order endpoint tests: real routes, a real database, one
/// shop with two slots, a district and a cake, and signed-in staff and owner
/// phones. Dates are relative to the controlled clock (shop date = UTC+7).
class AdminOrderTestCase: AdminDatabaseTestCase {
    var districtID = UUID()
    var productID = UUID()
    var slotIDs: [String: UUID] = ["08:00": UUID(), "10:00": UUID()]
    var seeded = 0
    /// Codes are unique across the whole database, so each test starts at a random place.
    let codeBase = Int.random(in: 0..<100_000_000)

    override func setUp() async throws {
        try await super.setUp()
        try await run("INSERT INTO district (id, shop_id, name, delivery_fee_vnd) VALUES (\(bind: districtID), \(bind: shopID), 'Quan An Phu', 20000)")
        try await run("INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path) VALUES (\(bind: productID), \(bind: shopID), 'banh', 'Banh Mau', 'x', 50000, 'images/banana.png')")
        for (start, end) in [("08:00", "10:00"), ("10:00", "12:00")] {
            try await run("INSERT INTO delivery_slot (id, shop_id, start_time, end_time) VALUES (\(bind: slotIDs[start]!), \(bind: shopID), \(bind: start)::time, \(bind: end)::time)")
        }
    }

    var today: BusinessDate { app.services.calendar.today() }

    func day(_ offset: Int) -> String { app.services.calendar.adding(days: offset, to: today).description }

    /// Order code from a number: BT-AAAAAA, BT-AAAAAB, ... (valid alphabet).
    func code(_ number: Int) -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ"), base = alphabet.count
        var n = (codeBase + number) % Int(pow(Double(base), 6)), letters: [Character] = []
        for _ in 0..<6 { letters.append(alphabet[n % base]); n /= base }
        return "BT-" + String(letters.reversed())
    }

    /// Inserts an order and its one line, plus the day load of its cakes when it is open.
    @discardableResult
    func place(_ seed: SeedOrder = SeedOrder()) async throws -> String {
        seeded += 1
        let orderCode = code(seed.number == 0 ? seeded : seed.number)
        let id = UUID(), date = seed.date ?? day(3), placed = seed.placed ?? clock.now().addingTimeInterval(-3_600)
        let slot = try XCTUnwrap(slotIDs[seed.slot])
        try await run("""
            INSERT INTO customer_order (
                id, shop_id, order_code, status, cancel_reason, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes,
                customer_name, customer_phone, customer_address, note, idempotency_key, request_hash,
                client_platform, app_version, created_at, is_demo)
            VALUES (\(bind: id), \(bind: shopID), \(bind: orderCode), \(bind: seed.status), \(bind: seed.reason)::text,
                \(bind: date)::date, \(bind: slot), \(bind: seed.slot)::time, \(bind: seed.slot)::time + interval '2 hours',
                \(bind: districtID), 'Quan An Phu', 20000, \(literal: seed.cakes * 50_000), \(literal: seed.cakes * 50_000 + 20_000), \(literal: seed.cakes),
                \(bind: seed.name), \(bind: seed.phone), '1 Test Street', 'Ít đường', \(bind: UUID()), \(bind: String(repeating: "a", count: 64)),
                'ios', '1.0.0', \(timestamp(placed)), \(bind: seed.demo))
            """)
        try await run("INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd) VALUES (\(bind: id), \(bind: productID), 'Banh Mau', 50000, \(literal: seed.cakes), \(literal: seed.cakes * 50_000))")
        if ["New", "Confirmed"].contains(seed.status) { try await addLoad(date, seed.cakes) }
        return orderCode
    }

    func addLoad(_ date: String, _ cakes: Int) async throws {
        try await run("""
            INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit)
            VALUES (\(bind: shopID), \(bind: date)::date, \(literal: cakes), 100)
            ON CONFLICT (shop_id, delivery_date) DO UPDATE SET cakes_accepted = day_load.cakes_accepted + \(literal: cakes)
            """)
    }

    func loaded(_ date: String) async throws -> Int {
        try await count("SELECT coalesce(sum(cakes_accepted), 0)::int AS n FROM day_load WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: date)::date")
    }

    func status(of orderCode: String) async throws -> String {
        let row = try await sql.raw("SELECT status FROM customer_order WHERE order_code = \(bind: orderCode)").first()
        return try XCTUnwrap(row).decode(column: "status", as: String.self)
    }

    func events(of orderCode: String) async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id WHERE o.order_code = \(bind: orderCode) AND e.event_type = 'status_changed'")
    }

    /// A signed-in phone; the clock is first set so that sign-in ends at `now` when given.
    func phone(_ role: AccountRole, _ name: String = "Nhan Vien", now: Date? = nil) async throws -> Phone {
        if let now { clock.set(now.addingTimeInterval(-31)) }
        let account = try await addAccount(role, name)
        return try await signedIn(account.email)
    }

    // MARK: requests

    func list(_ phone: Phone, _ query: String = "") async throws -> Reply {
        try await authed(.GET, "v1/admin/orders" + (query.isEmpty ? "" : "?" + query), phone.access)
    }

    func listCodes(_ phone: Phone, _ query: String = "") async throws -> [String] {
        codes(try await list(phone, query))
    }

    func expectCodes(_ phone: Phone, _ query: String, _ expected: [String], file: StaticString = #filePath, line: UInt = #line) async throws {
        let actual = try await listCodes(phone, query)
        XCTAssertEqual(actual, expected, query, file: file, line: line)
    }

    func detail(_ phone: Phone, _ orderCode: String) async throws -> Reply {
        try await authed(.GET, "v1/admin/orders/\(orderCode)", phone.access)
    }

    func codes(_ reply: Reply) -> [String] {
        (reply.json["items"] as? [[String: Any]] ?? []).compactMap { $0["order_code"] as? String }
    }

    func change(_ phone: Phone, _ orderCode: String, _ json: String) async throws -> Reply {
        try await Self.change(app, phone, orderCode, json)
    }

    /// Static so parallel tasks can call it without capturing the test case.
    static func change(_ app: Application, _ phone: Phone, _ orderCode: String, _ json: String) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        let headers: HTTPHeaders = ["Authorization": "Bearer \(phone.access)", "X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": "application/json"]
        try await app.test(.POST, "v1/admin/orders/\(orderCode)/status", headers: headers, body: ByteBuffer(string: json), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    func move(_ from: String, _ to: String, reason: String? = nil) -> String {
        "{\"expected_status\":\"\(from)\",\"to_status\":\"\(to)\"" + (reason.map { ",\"cancel_reason\":\"\($0)\"" } ?? "") + "}"
    }
}

extension AdminOrderTestCase {
    func expectCodes(_ phone: Phone, _ expected: [String], file: StaticString = #filePath, line: UInt = #line) async throws {
        try await expectCodes(phone, "", expected, file: file, line: line)
    }
}
