import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// A scratch database that has migrations 0001 to 0007, so a test can insert
/// rows in the old statuses and then apply 0008. Skipped without
/// `DATABASE_MIGRATION_URL`. The database is dropped at the end of each test.
class OrderProcessMigrationCase: XCTestCase {
    static let target = "0008_order_process.sql"
    private static let scratchID = DatabaseID(string: "order_process_scratch")

    var app: Application!
    private var scratchName = ""
    let shop = UUID(), district = UUID(), slot = UUID()

    override func setUp() async throws {
        let url = ProcessInfo.processInfo.environment[AppConfig.Key.databaseMigrationURL] ?? ""
        try XCTSkipIf(url.isEmpty, "\(AppConfig.Key.databaseMigrationURL) is not set; database tests skipped")
        app = try await Application.make(.testing)
        app.databases.use(try .postgres(url: url), as: .psql)
        scratchName = "order_process_" + UUID().uuidString.prefix(8).lowercased()
        try await (app.db as? any SQLDatabase)?.raw(SQLQueryString("CREATE DATABASE \(scratchName)")).run()
        guard var parts = URLComponents(string: url) else { throw Abort(.internalServerError) }
        parts.path = "/" + scratchName
        app.databases.use(try .postgres(url: parts.string ?? url), as: Self.scratchID)
        try await apply { $0 != Self.target }
        try await seedShop()
    }

    override func tearDown() async throws {
        guard let app else { return }
        // FORCE closes the scratch pool's connections that are still open.
        try? await (app.db as? any SQLDatabase)?.raw(SQLQueryString("DROP DATABASE IF EXISTS \(scratchName) WITH (FORCE)")).run()
        try await app.asyncShutdown()
    }

    var sql: any SQLDatabase { app.db(Self.scratchID) as! any SQLDatabase } // swiftlint:disable:this force_cast

    /// Applies the real migration files named by the filter (Fluent skips applied ones).
    func apply(_ accept: @escaping (String) -> Bool) async throws {
        let files = try MigrationFiles.load(from: TestPaths.migrations).filter { accept($0.fileName) }
        for file in files { app.migrations.add(file, to: Self.scratchID) }
        try await app.autoMigrate()
    }

    func applyTarget() async throws { try await apply { $0 == Self.target } }

    func run(_ statement: String) async throws { try await sql.raw(SQLQueryString(statement)).run() }

    func rows(_ query: String) async throws -> [any SQLRow] { try await sql.raw(SQLQueryString(query)).all() }

    func number(_ query: String) async throws -> Int {
        try await sql.raw(SQLQueryString(query)).first()?.decode(column: "n", as: Int.self) ?? -1
    }

    func text(_ query: String) async throws -> String {
        try await sql.raw(SQLQueryString(query)).first()?.decode(column: "t", as: String.self) ?? ""
    }

    /// The statement is refused with a check violation (23514), as the triggers and checks raise.
    func refused(_ statement: String, _ message: String) async throws {
        do {
            try await run(statement)
            XCTFail("accepted: \(message)")
        } catch {
            XCTAssertTrue(String(reflecting: error).contains("sqlState: 23514"), "\(message): \(error)")
        }
    }

    private func seedShop() async throws {
        try await run("INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact) VALUES ('\(shop)', 'Test', 'Hi', '+84900000000', 'zalo')")
        try await run("INSERT INTO district (id, shop_id, name, delivery_fee_vnd) VALUES ('\(district)', '\(shop)', 'Quan An Phu', 20000)")
        try await run("INSERT INTO delivery_slot (id, shop_id, start_time, end_time) VALUES ('\(slot)', '\(shop)', '08:00', '10:00')")
    }

    /// Inserts an order in its first state; `code` is the 6 letter part of BT-XXXXXX.
    func insertOrder(_ code: String, status: String, cakes: Int = 2, date: String = "2030-01-10") async throws {
        try await run("""
            INSERT INTO customer_order (id, shop_id, order_code, status, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes,
                customer_name, customer_phone, customer_address, idempotency_key, request_hash, client_platform, app_version)
            VALUES (gen_random_uuid(), '\(shop)', 'BT-\(code)', '\(status)', '\(date)', '\(slot)', '08:00', '10:00',
                '\(district)', 'Quan An Phu', 20000, \(cakes * 50_000), \(cakes * 50_000 + 20_000), \(cakes),
                'Tran Thi B', '+84900000010', '1 Test Street', gen_random_uuid(), '\(String(repeating: "a", count: 64))', 'ios', '1.0.0')
            """)
    }

    func setStatus(_ code: String, _ set: String) async throws {
        try await run("UPDATE customer_order SET \(set) WHERE order_code = 'BT-\(code)'")
    }

    func status(_ code: String) async throws -> String {
        try await text("SELECT status AS t FROM customer_order WHERE order_code = 'BT-\(code)'")
    }
}
