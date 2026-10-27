import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

final class DatabaseMigrationTests: DatabaseTestBase {

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

}
