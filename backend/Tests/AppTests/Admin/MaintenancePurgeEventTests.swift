import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// Security events move to the archive; sessions leave after their grace.
final class MaintenancePurgeEventTests: AdminDatabaseTestCase {
    private let day = 86_400

    /// Inserts one event of a given age; the tag in `device_session_id` finds it again.
    private func addEvent(daysOld: Int, tag: UUID) async throws {
        try await run("""
            INSERT INTO security_event (at, event_type, device_session_id)
            VALUES (now() - make_interval(days => \(bind: daysOld)::int), 'sign_in', \(bind: tag))
            """)
    }

    private func events(_ table: String, _ tag: UUID) async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM \(unsafeRaw: table) WHERE device_session_id = \(bind: tag)")
    }

    private func assertRefused(_ query: SQLQueryString, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await run(query)
            XCTFail("statement was accepted", file: file, line: line)
        } catch {
            XCTAssertTrue(String(reflecting: error).contains("append-only"), "\(error)", file: file, line: line)
        }
    }

    func testOldEventIsArchivedAndYoungEventStays() async throws {
        let old = UUID(), young = UUID()
        try await addEvent(daysOld: 181, tag: old)
        try await addEvent(daysOld: 179, tag: young)
        let report = try await MaintenancePurge.run(on: app.db, now: Date(), policy: .standard)
        XCTAssertGreaterThanOrEqual(report.securityEvents, 1)
        let oldLeft = try await events("security_event", old)
        let oldArchived = try await events("security_event_archive", old)
        let youngLeft = try await events("security_event", young)
        let youngArchived = try await events("security_event_archive", young)
        XCTAssertEqual([oldLeft, oldArchived, youngLeft, youngArchived], [0, 1, 1, 0])
    }

    func testYoungEventCannotBeDeletedOrUpdated() async throws {
        let young = UUID(), old = UUID()
        try await addEvent(daysOld: 179, tag: young)
        try await addEvent(daysOld: 181, tag: old)
        await assertRefused("DELETE FROM security_event WHERE device_session_id = \(bind: young)")
        await assertRefused("UPDATE security_event SET platform = 'ios' WHERE device_session_id = \(bind: young)")
        await assertRefused("UPDATE security_event SET platform = 'ios' WHERE device_session_id = \(bind: old)")
        let left = try await events("security_event", young)
        XCTAssertEqual(left, 1)
    }

    func testArchiveRowsCannotBeUpdatedOrDeleted() async throws {
        let tag = UUID()
        try await addEvent(daysOld: 200, tag: tag)
        _ = try await MaintenancePurge.run(on: app.db, now: Date(), policy: .standard)
        await assertRefused("UPDATE security_event_archive SET platform = 'ios' WHERE device_session_id = \(bind: tag)")
        await assertRefused("DELETE FROM security_event_archive WHERE device_session_id = \(bind: tag)")
        let archived = try await events("security_event_archive", tag)
        XCTAssertEqual(archived, 1)
    }

    func testSqlAgeEqualsThePolicyAge() async throws {
        XCTAssertEqual(MaintenancePolicy.standard.securityEventAge, TimeInterval(180 * day))
        let rows = try await sql.raw("SELECT pg_get_functiondef('security_event_append_only'::regproc) AS def")
            .first()?.decode(column: "def", as: String.self)
        let definition = try XCTUnwrap(rows)
        XCTAssertTrue(definition.contains("'180 days'"), definition)
    }

    private func addSession(_ account: UUID, revokedDaysAgo: Int?, refreshExpiredDaysAgo: Int) async throws -> UUID {
        let id = UUID()
        let revoked = revokedDaysAgo.map { "now() - interval '\($0) days'" } ?? "NULL"
        let reason = revokedDaysAgo == nil ? "NULL" : "'signed_out'"
        try await run("""
            INSERT INTO device_session (id, account_id, installation_id, platform, device_name, sign_in_method,
                access_token_hash, access_expires_at, refresh_token_hash, refresh_expires_at, revoked_at, revoked_reason)
            VALUES (\(bind: id), \(bind: account), \(bind: UUID()), 'ios', 'Test phone', 'code',
                decode(repeat('01', 32), 'hex'), now(), decode(repeat('02', 32), 'hex'),
                now() - make_interval(days => \(bind: refreshExpiredDaysAgo)::int),
                \(unsafeRaw: revoked), \(unsafeRaw: reason))
            """)
        return id
    }

    func testSessionsLeaveThirtyDaysAfterRevokeOrRefreshExpiry() async throws {
        let account = try await addAccount(.staff).id
        let revokedOld = try await addSession(account, revokedDaysAgo: 31, refreshExpiredDaysAgo: -5)
        let revokedYoung = try await addSession(account, revokedDaysAgo: 29, refreshExpiredDaysAgo: -5)
        let expiredOld = try await addSession(account, revokedDaysAgo: nil, refreshExpiredDaysAgo: 31)
        let expiredYoung = try await addSession(account, revokedDaysAgo: nil, refreshExpiredDaysAgo: 29)
        _ = try await MaintenancePurge.run(on: app.db, now: Date(), policy: .standard)
        var left: [UUID] = []
        for id in [revokedOld, revokedYoung, expiredOld, expiredYoung] {
            let n = try await count("SELECT count(*)::int AS n FROM device_session WHERE id = \(bind: id)")
            if n == 1 { left.append(id) }
        }
        XCTAssertEqual(Set(left), [revokedYoung, expiredYoung])
    }
}
