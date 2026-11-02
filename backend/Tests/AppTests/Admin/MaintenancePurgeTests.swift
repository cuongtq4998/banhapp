import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// The purge on a real PostgreSQL: old rows go, young rows and orders stay.
final class MaintenancePurgeTests: AdminDatabaseTestCase {
    private func ageHours(_ hours: Int) -> String { "now() - interval '\(hours) hours'" }

    func testPurgeRemovesOnlyRowsPastTheirPeriod() async throws {
        let tag = UUID().uuidString.prefix(8).lowercased()
        let old = "old\(tag)@example.com", young = "young\(tag)@example.com"
        for (email, expiry) in [(old, 25), (young, 23)] {
            try await run("INSERT INTO auth_code (email, code_hmac, expires_at) VALUES (\(bind: email), decode(repeat('00', 32), 'hex'), \(unsafeRaw: ageHours(expiry)))")
        }
        let report = try await MaintenancePurge.run(on: app.db, now: Date(), policy: .standard)
        XCTAssertGreaterThanOrEqual(report.authCodes, 1)
        let left = try await count("SELECT count(*)::int AS n FROM auth_code WHERE email IN (\(bind: old), \(bind: young))")
        XCTAssertEqual(left, 1)
        let again = try await MaintenancePurge.run(on: app.db, now: Date(), policy: .standard)
        XCTAssertEqual(again.authCodes, 0, "second run finds nothing")
    }

    func testPurgeKeepsCustomerOrders() async throws {
        let before = try await count("SELECT count(*)::int AS n FROM customer_order")
        _ = try await MaintenancePurge.run(on: app.db, now: Date().addingTimeInterval(86_400 * 4_000), policy: .standard)
        let after = try await count("SELECT count(*)::int AS n FROM customer_order")
        XCTAssertEqual(before, after)
    }
}
