import XCTest
import Vapor
import Fluent
import FluentSQL
import NIOConcurrencyHelpers
@testable import AppUnderTest

/// Black-box base of the admin-orders QA tests: the real application on a loopback
/// port over a real PostgreSQL (skipped without DATABASE_MIGRATION_URL), every call
/// through HTTP. Own fake shop per test; data stays in the throwaway database.
/// Mail and push use the in-memory recording senders. Holds no test methods.
class AdminQABase: XCTestCase {
    var app: Application!
    var shopID = UUID()
    var clock = QAClock(Date())
    var mail = RecordingEmailSender()
    var pushSender = RecordingPushSender()
    var client = QAClient(port: 0)
    let logs = QALogCapture()
    var productID = UUID(), districtID = UUID(), slotID = UUID()
    var ownerEmail = "", ownerID = UUID()
    let codeAlphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    let pepper = String(repeating: "q", count: 32)

    /// The per-phone limit compares stored `created_at` (database clock) with the app clock, so its tests need the real time.
    var useRealClock: Bool { false }

    /// The deployment default is `info` (LOG_LEVEL, deployment/01).
    var logLevel: Logger.Level { .info }

    /// Override to change the order policy of a test class.
    var orderPolicy: OrderPolicy { OrderPolicy(perAddressPerHour: 1_000_000) }

    override func setUp() async throws {
        let url = ProcessInfo.processInfo.environment["DATABASE_MIGRATION_URL"] ?? ""
        try XCTSkipIf(url.isEmpty, "DATABASE_MIGRATION_URL not set; admin QA tests skipped")
        shopID = UUID()
        clock = useRealClock ? QAClock(Date()) : QAClock(Date(timeIntervalSince1970: 1_924_995_600 + TimeInterval(Int.random(in: 0..<20_000)) * 86_400))
        app = try await Application.make(.testing)
        var handler = QAHandler(capture: logs)
        handler.logLevel = logLevel
        app.logger = Logger(label: "qa") { _ in handler }
        let admin = AdminAuthConfig(pepper: pepper, emailProvider: .recording, emailMaxPerDay: 1_000_000)
        try await configure(app, config: AppConfig(
            stage: .local, port: 0, databaseURL: url, shopID: shopID, rateLimitReadPerMinute: 1_000_000,
            orders: orderPolicy, admin: admin, push: PushConfig(provider: .recording, apns: nil, fcm: nil)))
        for file in try MigrationFiles.load(from: QAPaths.migrations) { app.migrations.add(file) }
        try await app.autoMigrate()
        app.services.clock = clock
        app.services.mailRetryDelay = .zero
        app.services.pushRetryDelays = [.zero, .zero, .zero]
        mail = try XCTUnwrap(app.services.email as? RecordingEmailSender)
        pushSender = try XCTUnwrap(app.services.push as? RecordingPushSender)
        try await seedShop()
        try await app.server.start(address: .hostname("127.0.0.1", port: 0))
        client = QAClient(port: try XCTUnwrap(app.http.server.shared.localAddress?.port))
    }

    override func tearDown() async throws {
        if app != nil { await app.server.shutdown() }
        try await app?.asyncShutdown()
    }

    // MARK: database

    var sql: any SQLDatabase { app.db as! any SQLDatabase } // swiftlint:disable:this force_cast
    func run(_ query: SQLQueryString) async throws { try await sql.raw(query).run() }
    func count(_ query: SQLQueryString) async throws -> Int { try await sql.raw(query).first()?.decode(column: "n", as: Int.self) ?? -1 }

    func seedShop() async throws {
        try await run("INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact) VALUES (\(bind: shopID), 'QA shop', 'Hi', '+84900000000', 'zalo')")
        try await run("INSERT INTO shop_setting (shop_id, daily_limit, lead_days, min_qty, max_days_ahead, max_qty_per_cake) VALUES (\(bind: shopID), 100, 2, 2, 30, 99)")
        try await run("INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path) VALUES (\(bind: productID), \(bind: shopID), 'qa-cake', 'QA cake', 'x', 50000, 'images/banana.png')")
        try await run("INSERT INTO district (id, shop_id, name, delivery_fee_vnd) VALUES (\(bind: districtID), \(bind: shopID), 'QA district', 20000)")
        try await run("INSERT INTO delivery_slot (id, shop_id, start_time, end_time) VALUES (\(bind: slotID), \(bind: shopID), '08:00', '10:00')")
        (ownerID, ownerEmail) = try await addAccount("owner", "Chu Mau")
    }

    @discardableResult
    func addAccount(_ role: String, _ name: String, active: Bool = true, kind: String? = nil) async throws -> (UUID, String) {
        let id = UUID(), email = "qa.\(role).\(id.uuidString.prefix(8).lowercased())@example.com"
        try await run("INSERT INTO account (id, shop_id, role, email, display_name, is_active) VALUES (\(bind: id), \(bind: shopID), \(bind: role), \(bind: email), \(bind: name), \(bind: active))")
        return (id, email)
    }

    // MARK: sign-in over HTTP

    func requestCode(_ email: String) async throws -> QAReply {
        let reply = try await client.send("POST", "v1/auth/code-requests", json: ["email": email])
        await app.services.background.drain()
        return reply
    }

    func signInReply(_ email: String, code: String, installation: UUID = UUID(), platform: String = "ios") async throws -> QAReply {
        let reply = try await client.send("POST", "v1/auth/sessions", json: [
            "email": email, "code": code, "installation_id": installation.uuidString, "device_name": "QA phone"], platform: platform)
        await app.services.background.drain()
        return reply
    }

    func signedIn(_ email: String, installation: UUID = UUID(), platform: String = "ios") async throws -> QAPhone {
        let requested = try await requestCode(email)
        XCTAssertEqual(requested.status, 202, requested.text)
        let code = try XCTUnwrap(mail.lastCode(to: email))
        let reply = try await signInReply(email, code: code, installation: installation, platform: platform)
        XCTAssertEqual(reply.status, 201, reply.text)
        clock.advance(31)
        return QAPhone(access: reply.string("access_token"), refresh: reply.string("refresh_token"), deviceID: reply.string("device_id"))
    }

    func owner() async throws -> QAPhone { try await signedIn(ownerEmail) }

    func staff(_ name: String = "Nhan Vien QA", active: Bool = true, platform: String = "ios") async throws -> (phone: QAPhone, id: UUID, email: String) {
        let (id, email) = try await addAccount("staff", name, active: active)
        return (try await signedIn(email, platform: platform), id, email)
    }

    // MARK: orders

    func randomCode() -> String { "BT-" + String((0..<6).map { _ in codeAlphabet.randomElement()! }) }

    /// Inserts a stored order by SQL (default: New, 2 cakes) and, for open orders, adds its cakes to day_load.
    @discardableResult
    func seedOrder(status: String = "New", cakes: Int = 2, date: String, phone: String = "+84900000010", name: String = "Tran Thi B",
                   placed: Date? = nil, reason: String? = nil, load: Bool = true) async throws -> String {
        let orderCode = randomCode(), id = UUID()
        let stamp = ISO8601DateFormatter().string(from: placed ?? clock.now().addingTimeInterval(-3_600))
        try await run("""
            INSERT INTO customer_order (id, shop_id, order_code, status, cancel_reason, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes, customer_name, customer_phone,
                customer_address, note, idempotency_key, request_hash, client_platform, app_version, created_at)
            VALUES (\(bind: id), \(bind: shopID), \(bind: orderCode), \(bind: status), \(bind: reason)::text, \(bind: date)::date, \(bind: slotID),
                '08:00', '10:00', \(bind: districtID), 'QA district', 20000, \(literal: cakes * 50_000), \(literal: cakes * 50_000 + 20_000), \(literal: cakes),
                \(bind: name), \(bind: phone), '1 QA Street', 'QA note', \(bind: UUID()), \(bind: String(repeating: "a", count: 64)), 'ios', '1.0.0',
                \(bind: stamp)::timestamptz)
            """)
        try await run("INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd) VALUES (\(bind: id), \(bind: productID), 'QA cake', 50000, \(literal: cakes), \(literal: cakes * 50_000))")
        if load && ["New", "Confirmed"].contains(status) { try await addLoad(date, cakes) }
        return orderCode
    }

    func addLoad(_ date: String, _ cakes: Int, limit: Int = 100) async throws {
        try await run("""
            INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(bind: shopID), \(bind: date)::date, \(literal: cakes), \(literal: limit))
            ON CONFLICT (shop_id, delivery_date) DO UPDATE SET cakes_accepted = day_load.cakes_accepted + \(literal: cakes)
            """)
    }

    func loaded(_ date: String) async throws -> Int {
        try await count("SELECT coalesce(sum(cakes_accepted), 0)::int AS n FROM day_load WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: date)::date")
    }

    func dayOffset(_ days: Int) -> String { app.services.calendar.adding(days: days, to: app.services.calendar.today()).description }

    /// Sendable handle for parallel tasks.
    var shopRef: QAShop { QAShop(client: client, productID: productID, slotID: slotID, districtID: districtID) }

    func customerOrder(date: String, cakes: Int = 2, phone: String = "0900000010", key: UUID = UUID(), note: String? = "QA note") async throws -> QAReply {
        try await shopRef.order(date: date, cakes: cakes, phone: phone, key: key, note: note)
    }

    func changeStatus(_ phone: QAPhone, _ code: String, from: String, to: String, reason: String? = nil) async throws -> QAReply {
        var body = ["expected_status": from, "to_status": to]
        if let reason { body["cancel_reason"] = reason }
        return try await client.send("POST", "v1/admin/orders/\(code)/status", token: phone.access, json: body)
    }
}

extension AdminQABase {
    /// `XCTAssertEqual` whose first argument may be `try await`; XCTest autoclosures cannot suspend.
    func aeq<T: Equatable>(_ actual: @autoclosure () async throws -> T, _ expected: @autoclosure () -> T,
                           _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws {
        let value = try await actual()
        XCTAssertEqual(value, expected(), message(), file: file, line: line)
    }
}
