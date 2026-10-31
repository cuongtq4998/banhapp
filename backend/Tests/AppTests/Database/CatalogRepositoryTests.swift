import XCTVapor
import Logging
import Fluent
import FluentSQL
import BanhContracts
@testable import App

/// Runs the real SQL against PostgreSQL with the sample seed; skipped unless
/// `DATABASE_MIGRATION_URL` is set (see `DatabaseTestCase`).
final class CatalogRepositoryTests: DatabaseTestCase {
    private static func applySeed(on sql: any SQLDatabase) async throws {
        let script = try String(contentsOf: TestPaths.seed, encoding: .utf8)
        for statement in SQLScriptSplitter.statements(in: script) {
            try await sql.raw(SQLQueryString(statement)).run()
        }
    }

    private static func repository(on sql: any SQLDatabase) throws -> PostgresCatalogRepository {
        PostgresCatalogRepository(database: try XCTUnwrap(sql as? any Database))
    }

    func testSeededShopMatchesTheSharedFixture() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            let service = CatalogService(
                repository: try Self.repository(on: sql),
                calendar: ShopCalendar(clock: CatalogTestData.fixtureClock),
                assets: CatalogTestData.assets,
                logger: Logger(label: "test")
            )
            let catalog = try await service.makeCatalog(shopID: AppConfig.testShopID)
            XCTAssertEqual(catalog, try CatalogTestData.fixture("catalog-ok.json"))
        }
    }

    func testInactiveRowsAreLeftOut() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            try await sql.raw("UPDATE product SET is_active = false WHERE slug = 'banana'").run()
            try await sql.raw("UPDATE district SET is_active = false WHERE name = 'Quận 1'").run()
            try await sql.raw("UPDATE delivery_slot SET is_active = false WHERE sort_order = 1").run()
            let snapshot = try await Self.repository(on: sql).loadCatalog(shopID: AppConfig.testShopID)
            XCTAssertEqual(snapshot.products.count, 3)
            XCTAssertFalse(snapshot.products.contains { $0.slug == "banana" })
            XCTAssertEqual(snapshot.districts.count, 4)
            XCTAssertEqual(snapshot.slots.map(\.start), ["10:00", "14:00", "16:00"])
        }
    }

    func testRowsFollowSortOrderNotInsertionOrder() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            try await sql.raw("UPDATE product SET sort_order = 0 WHERE slug = 'mung-bean-egg-yolk-pork-fat'").run()
            let snapshot = try await Self.repository(on: sql).loadCatalog(shopID: AppConfig.testShopID)
            XCTAssertEqual(snapshot.products.first?.slug, "mung-bean-egg-yolk-pork-fat")
        }
    }

    func testOtherShopsRowsAreNotReturned() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            let otherShop = CatalogTestData.uuid("99")
            try await sql.raw("""
                INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact, is_sample)
                VALUES (\(bind: otherShop), 'Other', 'Other greeting', '+84123456780', '84123456780', true)
                """).run()
            try await sql.raw("""
                INSERT INTO shop_setting (shop_id, daily_limit, is_sample) VALUES (\(bind: otherShop), 10, true)
                """).run()
            let snapshot = try await Self.repository(on: sql).loadCatalog(shopID: otherShop)
            XCTAssertEqual(snapshot.shop.name, "Other")
            XCTAssertTrue(snapshot.products.isEmpty)
            XCTAssertTrue(snapshot.districts.isEmpty)
            XCTAssertTrue(snapshot.slots.isEmpty)
        }
    }

    func testUnknownShopThrowsShopNotFound() async throws {
        try await withRolledBackTransaction { sql in
            do {
                _ = try await Self.repository(on: sql).loadCatalog(shopID: CatalogTestData.uuid("98"))
                XCTFail("expected shopNotFound")
            } catch {
                XCTAssertEqual(error as? CatalogRepositoryError, .shopNotFound)
            }
        }
    }

    func testBrokenSQLStaysAnInternalErrorAndIsNotAnOutage() async throws {
        try await withRolledBackTransaction { sql in
            do {
                _ = try await translatingDatabaseErrors { try await sql.raw("SELECT * FROM table_that_does_not_exist").all() }
                XCTFail("expected an error")
            } catch {
                XCTAssertNil(error as? APIError, "a rejected statement is our defect, not an outage")
            }
        }
    }
}
