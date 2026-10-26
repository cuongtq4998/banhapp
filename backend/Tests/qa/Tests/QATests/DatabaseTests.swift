import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Database-level tests (TC-59, TC-60, TC-61, TC-66, TC-70 plus migration and
/// seed behaviour). They need a PostgreSQL 14+ and skip unless
/// DATABASE_MIGRATION_URL is set (a throwaway database; the role needs DDL
/// rights). Every data test runs inside a transaction that is rolled back, so
/// nothing remains except the migrated schema.
/// Statement helpers; a Sendable value so the transaction closures need no `self`.
private struct Q: Sendable {
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
private let q = Q()
private typealias Ids = Q.Ids

final class DatabaseTests: XCTestCase {
    private var app: Application!
    private var db: any Database { app.db }

    private struct Rollback: Error {}

    override func setUp() async throws {
        guard let url = ProcessInfo.processInfo.environment["DATABASE_MIGRATION_URL"], !url.isEmpty else {
            throw XCTSkip("DATABASE_MIGRATION_URL not set; database-level tests skipped")
        }
        app = try await Application.make(.testing)
        let config = AppConfig(stage: .local, port: 8080, databaseURL: url, databaseMigrationURL: url)
        try await configure(app, config: config, migrationFiles: MigrationFiles.load(from: QAPaths.migrations))
        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        if let app { try await app.asyncShutdown() }
    }

    private func inRollback(_ body: @escaping @Sendable (any SQLDatabase) async throws -> Void) async throws {
        do {
            try await db.transaction { tx in
                try await body(tx as! any SQLDatabase)
                throw Rollback()
            }
        } catch is Rollback {}
    }


    // MARK: migration and seed

    func testMigrationRerunIsNoOpAndSchemaIsComplete() async throws {
        try await app.autoMigrate() // second run
        try await app.autoMigrate() // third run
        try await inRollback { tx in
            let tables = try await q.count(tx, """
            SELECT count(*)::int AS n FROM pg_tables WHERE schemaname = current_schema()
            AND tablename IN ('shop','shop_setting','product','district','delivery_slot','day_load','customer_order','customer_order_item','order_event')
            """)
            XCTAssertEqual(tables, 9)
            let applied = try await q.count(tx, "SELECT count(*)::int AS n FROM _fluent_migrations WHERE name = '0001_init.sql'")
            XCTAssertEqual(applied, 1)
            let triggers = try await q.count(tx, "SELECT count(*)::int AS n FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'customer_order_%' OR tgname = 'order_event_append_only'")
            XCTAssertEqual(triggers, 4)
        }
    }

    func testRevertIsRefused() async throws {
        let file = try XCTUnwrap(MigrationFiles.load(from: QAPaths.migrations).first)
        do { try await file.revert(on: db); XCTFail("revert must throw") } catch is SQLFileMigration.ForwardOnlyError {}
    }

    func testFailingMigrationLeavesNothingBehind() async throws {
        let bad = SQLFileMigration(fileName: "9999_qa_bad.sql", statements: ["CREATE TABLE qa_half_applied (a int)", "SELEKT 1"])
        do { try await bad.prepare(on: db); XCTFail("must throw") } catch {}
        try await inRollback { tx in
            let n = try await q.count(tx, "SELECT count(*)::int AS n FROM pg_tables WHERE tablename = 'qa_half_applied'")
            XCTAssertEqual(n, 0, "DDL of a failed file must roll back as a whole")
        }
    }

    func testSeedIsIdempotentAndEverythingIsSample() async throws {
        let statements = SQLScriptSplitter.statements(in: try String(contentsOf: QAPaths.seed, encoding: .utf8))
        try await inRollback { tx in
            // Work on an empty graph: remove nothing, count rows that exist before and after two runs.
            for _ in 0..<2 { for s in statements { try await q.run(tx, s) } }
            let after2 = try await q.count(tx, "SELECT (SELECT count(*) FROM shop) + (SELECT count(*) FROM product) + (SELECT count(*) FROM district) + (SELECT count(*) FROM delivery_slot) + (SELECT count(*) FROM shop_setting) AS n")
            for s in statements { try await q.run(tx, s) }
            let after3 = try await q.count(tx, "SELECT (SELECT count(*) FROM shop) + (SELECT count(*) FROM product) + (SELECT count(*) FROM district) + (SELECT count(*) FROM delivery_slot) + (SELECT count(*) FROM shop_setting) AS n")
            XCTAssertEqual(after2, after3)
            let sampleShop = try await q.count(tx, "SELECT count(*)::int AS n FROM shop WHERE id = '00000000-0000-4000-8000-000000000001'")
            XCTAssertEqual(sampleShop, 1)
            let products = try await q.count(tx, "SELECT count(*)::int AS n FROM product WHERE shop_id = '00000000-0000-4000-8000-000000000001'")
            XCTAssertEqual(products, 4)
        }
    }

    func testSeedRowsAreAllMarkedSample() async throws {
        let statements = SQLScriptSplitter.statements(in: try String(contentsOf: QAPaths.seed, encoding: .utf8))
        try await inRollback { tx in
            for s in statements { try await q.run(tx, s) }
            let seedShop = "'00000000-0000-4000-8000-000000000001'"
            let flagged = try await q.count(tx, """
            SELECT ((SELECT count(*) FROM shop WHERE id = \(seedShop) AND NOT is_sample)
                  + (SELECT count(*) FROM shop_setting WHERE shop_id = \(seedShop) AND NOT is_sample)
                  + (SELECT count(*) FROM product WHERE shop_id = \(seedShop) AND NOT is_sample)
                  + (SELECT count(*) FROM district WHERE shop_id = \(seedShop) AND NOT is_sample)
                  + (SELECT count(*) FROM delivery_slot WHERE shop_id = \(seedShop) AND NOT is_sample))::int AS n
            """)
            XCTAssertEqual(flagged, 0)
        }
    }

    // MARK: TC-59, TC-60, TC-61

    func testCancelReleasesCapacityOnceAndWritesEvent() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 10)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT cakes_accepted AS n FROM day_load WHERE shop_id = \(Ids.shop)", 8)
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE order_id = \(Ids.order) AND to_status = 'Cancelled' AND from_status = 'New' AND actor_type = 'system'", 1)
            // Second cancel: final state; whatever the DB does, capacity must not drop twice and no second event.
            _ = try await q.rejected(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT cakes_accepted AS n FROM day_load WHERE shop_id = \(Ids.shop)", 8)
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE order_id = \(Ids.order)", 1)
        }
    }

    func testStatusTransitionMatrix() async throws {
        let valid = [("New", "Confirmed"), ("New", "Cancelled"), ("Confirmed", "Completed"), ("Confirmed", "Cancelled")]
        let invalid = [("New", "Completed"), ("Confirmed", "New"), ("Completed", "New"), ("Completed", "Confirmed"),
                       ("Completed", "Cancelled"), ("Cancelled", "New"), ("Cancelled", "Confirmed"), ("Cancelled", "Completed")]
        for (from, to) in valid + invalid {
            let expectOK = valid.contains { $0 == (from, to) }
            try await inRollback { tx in
                // Capacity row large enough so a cancel never trips the CHECK.
                try await q.insertShopGraph(tx, accepted: 4)
                try await q.run(tx, q.orderInsert(cakes: 2, status: from))
                let wasRejected = try await q.rejected(tx, "UPDATE customer_order SET status = '\(to)' WHERE id = \(Ids.order)")
                XCTAssertEqual(wasRejected, !expectOK, "\(from) -> \(to)")
                let now = try await q.text(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)")
                XCTAssertEqual(now, expectOK ? to : from, "\(from) -> \(to)")
            }
        }
    }

    func testCompletionAndConfirmationDoNotTouchCapacity() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 4)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET status = 'Confirmed' WHERE id = \(Ids.order)")
            try await q.run(tx, "UPDATE customer_order SET status = 'Completed' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT cakes_accepted AS n FROM day_load WHERE shop_id = \(Ids.shop)", 4)
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE order_id = \(Ids.order)", 2)
        }
    }

    func testActorSettingsAreRecordedInTheEvent() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "SELECT set_config('app.actor_type', 'staff', true), set_config('app.actor_id', 'aaaaaaaa-0000-4000-8000-0000000000c1', true)")
            try await q.run(tx, "UPDATE customer_order SET status = 'Confirmed' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE actor_type = 'staff' AND actor_id = 'aaaaaaaa-0000-4000-8000-0000000000c1'", 1)
        }
    }

    func testBogusActorTypeFailsTheUpdateAtomically() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "SELECT set_config('app.actor_type', 'hacker', true)")
            try await q.expectRejected(tx, "UPDATE customer_order SET status = 'Confirmed' WHERE id = \(Ids.order)")
            try await q.expectText(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)", "New")
        }
    }

    func testCancelWithMissingDayLoadRowDoesNotFail() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, withDayLoad: false)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectText(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)", "Cancelled")
        }
    }

    func testCancelThatWouldMakeCounterNegativeIsBlockedAndAtomic() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 1) // inconsistent: order has 2 cakes
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.expectRejected(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectText(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)", "New")
        }
    }

    func testReconciliationHoldsAfterCancels() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 5)
            try await q.run(tx, q.orderInsert(id: Ids.order, key: Ids.key, code: "'BT-ABC234'", cakes: 2))
            try await q.run(tx, q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a2'", key: "'aaaaaaaa-0000-4000-8000-0000000000b2'", code: "'BT-ABC235'", cakes: 3))
            try await q.run(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            let mismatch = try await q.count(tx, """
            SELECT count(*)::int AS n FROM day_load d WHERE d.shop_id = \(Ids.shop) AND d.cakes_accepted <>
              COALESCE((SELECT sum(total_cakes) FROM customer_order o WHERE o.shop_id = d.shop_id AND o.delivery_date = d.delivery_date AND o.status <> 'Cancelled'), 0)
            """)
            XCTAssertEqual(mismatch, 0)
        }
    }

    // MARK: immutability and audit trail (TC-60, TC-70)

    func testSnapshotColumnsAreImmutable() async throws {
        let updates = ["total_cakes = 3", "total_vnd = 1", "items_subtotal_vnd = 1", "delivery_fee_vnd = 1", "delivery_date = '2030-02-01'",
                       "order_code = 'BT-ZZZZZZ'", "slot_start_time = '09:00'", "district_name = 'x'", "created_at = now() - interval '1 day'",
                       "idempotency_key = 'aaaaaaaa-0000-4000-8000-0000000000b9'", "request_hash = '\(String(repeating: "b", count: 64))'",
                       "client_platform = 'android'", "app_version = '9'"]
        for update in updates {
            try await inRollback { tx in
                try await q.insertShopGraph(tx, accepted: 2)
                try await q.run(tx, q.orderInsert(cakes: 2))
                let wasRejected = try await q.rejected(tx, "UPDATE customer_order SET \(update) WHERE id = \(Ids.order)")
                XCTAssertTrue(wasRejected, update)
            }
        }
    }

    func testPaymentStatusStaysMutable() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET payment_status = 'paid' WHERE id = \(Ids.order)")
        }
    }

    func testPersonalColumnsChangeOnlyThroughPurge() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.expectRejected(tx, "UPDATE customer_order SET customer_name = 'Other' WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "UPDATE customer_order SET note = 'x' WHERE id = \(Ids.order)")
            // Purge: blank personal columns and set the marker in one statement.
            try await q.run(tx, "UPDATE customer_order SET customer_name = '', customer_phone = '', customer_address = '', note = NULL, pii_purged_at = now() WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "UPDATE customer_order SET pii_purged_at = NULL WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "UPDATE customer_order SET pii_purged_at = now() + interval '1 day' WHERE id = \(Ids.order)")
            // After the purge the personal columns are no longer guarded by the trigger; record behaviour only.
            _ = try await q.rejected(tx, "UPDATE customer_order SET customer_name = 'Late edit' WHERE id = \(Ids.order)")
        }
    }

    func testBlankPersonalDataWithoutPurgeMarkerIsRejected() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.expectRejected(tx, q.orderInsert(cakes: 2).replacingOccurrences(of: "'QA Customer'", with: "''"))
        }
    }

    func testOrderEventIsAppendOnly() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "INSERT INTO order_event (order_id, event_type, to_status, actor_type) VALUES (\(Ids.order), 'created', 'New', 'customer')")
            try await q.expectRejected(tx, "UPDATE order_event SET to_status = 'Cancelled' WHERE order_id = \(Ids.order)")
            try await q.expectRejected(tx, "DELETE FROM order_event WHERE order_id = \(Ids.order)")
            try await q.expectRejected(tx, "INSERT INTO order_event (order_id, event_type, to_status, actor_type) VALUES (\(Ids.order), 'deleted', 'New', 'customer')")
            try await q.expectRejected(tx, "INSERT INTO order_event (order_id, event_type, to_status, actor_type) VALUES (\(Ids.order), 'created', 'New', 'robot')")
        }
    }

    func testCheckConstraintsRejectBadRows() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            let bad: [(String, String)] = [
                ("day_load over limit", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-02-01', 11, 10)"),
                ("day_load negative", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-02-02', -1, 10)"),
                ("day_load zero limit", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-02-03', 0, 0)"),
                ("day_load duplicate date", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-01-10', 0, 10)"),
                ("total not sum", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a3'", key: "'aaaaaaaa-0000-4000-8000-0000000000b3'", code: "'BT-ABC236'", subtotal: 100000, total: 1)),
                ("code with excluded letter O", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a4'", key: "'aaaaaaaa-0000-4000-8000-0000000000b4'", code: "'BT-ABCO34'")),
                ("code with digit 1", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a5'", key: "'aaaaaaaa-0000-4000-8000-0000000000b5'", code: "'BT-ABC134'")),
                ("code lower case", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a6'", key: "'aaaaaaaa-0000-4000-8000-0000000000b6'", code: "'BT-abc234'")),
                ("code too short", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a7'", key: "'aaaaaaaa-0000-4000-8000-0000000000b7'", code: "'BT-ABC23'")),
                ("phone not +84", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a8'", key: "'aaaaaaaa-0000-4000-8000-0000000000b8'", code: "'BT-ABC237'", phone: "0901234567")),
                ("phone prefix 84 2", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a9'", key: "'aaaaaaaa-0000-4000-8000-0000000000b9'", code: "'BT-ABC238'", phone: "+84201234567")),
                ("zero cakes", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000aa'", key: "'aaaaaaaa-0000-4000-8000-0000000000ba'", code: "'BT-ABC239'", cakes: 0, subtotal: 0, total: 20000)),
                ("bad status", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000ab'", key: "'aaaaaaaa-0000-4000-8000-0000000000bb'", code: "'BT-ABC23A'", status: "Done")),
                ("slot end before start", "INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(Ids.shop), '12:00', '11:00')"),
                ("slot equal times", "INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(Ids.shop), '12:00', '12:00')"),
                ("duplicate slot", "INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(Ids.shop), '08:00', '10:00')"),
                ("duplicate district name", "INSERT INTO district (shop_id, name, delivery_fee_vnd) VALUES (\(Ids.shop), 'QA district', 1)"),
                ("negative fee", "INSERT INTO district (shop_id, name, delivery_fee_vnd) VALUES (\(Ids.shop), 'Other', -1)"),
                ("duplicate slug", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'qa-cake', 'n', 'd', 1, 'i')"),
                ("slug upper case", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'QA', 'n', 'd', 1, 'i')"),
                ("negative price", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'neg', 'n', 'd', -1, 'i')"),
                ("empty product name", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'emp', '', 'd', 1, 'i')"),
                ("setting max_days_ahead below lead", "INSERT INTO shop_setting (shop_id, daily_limit, lead_days, max_days_ahead) VALUES (\(Ids.shop), 5, 5, 1)"),
                ("second setting row", "INSERT INTO shop_setting (shop_id, daily_limit) VALUES (\(Ids.shop), 5)"),
                ("shop phone not E.164", "INSERT INTO shop (name, greeting, phone_contact, zalo_contact) VALUES ('n', 'g', '0123456789', '84123456789')"),
                ("unknown shop FK", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES ('aaaaaaaa-0000-4000-8000-0000000000ff', 'fk', 'n', 'd', 1, 'i')")
            ]
            for (label, sql) in bad {
                let wasRejected = try await q.rejected(tx, sql)
                XCTAssertTrue(wasRejected, label)
            }
        }
    }

    func testIdempotencyKeyAndOrderCodeAreUnique() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 4)
            try await q.run(tx, q.orderInsert(cakes: 2))
            let sameKey = q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a2'", code: "'BT-ABC235'", cakes: 2)
            try await q.expectRejected(tx, sameKey)
            let sameCode = q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a3'", key: "'aaaaaaaa-0000-4000-8000-0000000000b3'", cakes: 2)
            try await q.expectRejected(tx, sameCode)
        }
    }

    func testItemChecksAndRestrictiveForeignKeys() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            let item = { (qty: Int, line: Int) in "INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd) VALUES (\(Ids.order), \(Ids.product), 'QA cake', 50000, \(qty), \(line))" }
            try await q.expectRejected(tx, item(0, 0))
            try await q.expectRejected(tx, item(100, 5_000_000))
            try await q.expectRejected(tx, item(2, 1))
            try await q.run(tx, item(2, 100_000))
            try await q.expectRejected(tx, item(2, 100_000), "one line per product")
            try await q.expectRejected(tx, "DELETE FROM product WHERE id = \(Ids.product)")
            try await q.expectRejected(tx, "DELETE FROM customer_order WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "DELETE FROM shop WHERE id = \(Ids.shop)")
        }
    }
}
