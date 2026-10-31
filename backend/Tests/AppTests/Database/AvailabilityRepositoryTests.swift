import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// Runs the real availability SQL against PostgreSQL with the sample seed;
/// skipped unless `DATABASE_MIGRATION_URL` is set (see `DatabaseTestCase`).
final class AvailabilityRepositoryTests: DatabaseTestCase {
    private static func applySeed(on sql: any SQLDatabase) async throws {
        let script = try String(contentsOf: TestPaths.seed, encoding: .utf8)
        for statement in SQLScriptSplitter.statements(in: script) {
            try await sql.raw(SQLQueryString(statement)).run()
        }
    }

    private static func repository(on sql: any SQLDatabase) throws -> PostgresAvailabilityRepository {
        PostgresAvailabilityRepository(database: try XCTUnwrap(sql as? any Database))
    }

    private static func insertLoad(_ date: String, accepted: Int, on sql: any SQLDatabase) async throws {
        try await sql.raw("""
            INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit)
            VALUES (\(bind: AppConfig.testShopID), \(bind: date)::date, \(bind: accepted), 100)
            """).run()
    }

    func testRulesCountOnlyActiveProducts() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            let repository = try Self.repository(on: sql)
            let all = try await repository.loadRules(shopID: AppConfig.testShopID)
            XCTAssertEqual(all.activeProductCount, 4)
            XCTAssertEqual(all.maxCakesPerOrder, all.maxQtyPerCake * 4)
            try await sql.raw("UPDATE product SET is_active = false WHERE slug = 'banana'").run()
            let fewer = try await repository.loadRules(shopID: AppConfig.testShopID)
            XCTAssertEqual(fewer.activeProductCount, 3)
        }
    }

    func testUnknownShopIsReported() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            do {
                _ = try await Self.repository(on: sql).loadRules(shopID: UUID())
                XCTFail("Expected shopNotFound")
            } catch let error as CatalogRepositoryError {
                XCTAssertEqual(error, .shopNotFound)
            }
        }
    }

    func testLoadsAreReturnedPerDateInsideTheRangeOnly() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            try await Self.insertLoad("2026-11-01", accepted: 5, on: sql)
            try await Self.insertLoad("2026-11-02", accepted: 10, on: sql)
            try await Self.insertLoad("2026-12-02", accepted: 20, on: sql)
            try await Self.insertLoad("2026-12-03", accepted: 30, on: sql)
            let loads = try await Self.repository(on: sql).loadAcceptedCakes(
                shopID: AppConfig.testShopID,
                from: AvailabilityTestData.date("2026-11-02"),
                through: AvailabilityTestData.date("2026-12-02")
            )
            XCTAssertEqual(loads, [
                AvailabilityTestData.date("2026-11-02"): 10,
                AvailabilityTestData.date("2026-12-02"): 20
            ])
        }
    }

    func testServiceOverRealSQLMatchesTheFixtureShape() async throws {
        try await withRolledBackTransaction { sql in
            try await Self.applySeed(on: sql)
            // The sample seed uses a smaller daily limit than the fixture; the transaction is rolled back.
            try await sql.raw("UPDATE shop_setting SET daily_limit = \(bind: AvailabilityTestData.rules.dailyLimit) WHERE shop_id = \(bind: AppConfig.testShopID)").run()
            for (date, accepted) in AvailabilityTestData.fixtureLoads {
                try await Self.insertLoad(date.description, accepted: accepted, on: sql)
            }
            let service = AvailabilityService(
                repository: try Self.repository(on: sql),
                calendar: ShopCalendar(clock: AvailabilityTestData.clock)
            )
            let response = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 3)
            let byDate = Dictionary(uniqueKeysWithValues: response.dates.map { ($0.date, $0.reason) })
            XCTAssertEqual(byDate["2026-11-03"], .tooSoon)
            XCTAssertNil(byDate["2026-11-04"] ?? nil)
            XCTAssertEqual(byDate["2026-11-05"], .full)
            XCTAssertEqual(byDate["2026-11-20"], .full)
        }
    }
}
