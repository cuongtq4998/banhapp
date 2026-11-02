import Fluent
import FluentSQL
import Foundation

/// Rows deleted by one run.
struct PurgeReport: Equatable, Sendable {
    let authCodes: Int
    let sessions: Int
    let securityEvents: Int
}

/// One statement per table: atomic, so two instances never conflict.
/// Security events are copied to the archive by the same statement.
enum MaintenancePurge {
    /// Deletes the expired rows and returns how many went; callable without the scheduler.
    static func run(on database: any Database, now: Date, policy: MaintenancePolicy) async throws -> PurgeReport {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        let cutoffs = policy.cutoffs(now: now)
        return PurgeReport(
            authCodes: try await count(sql, """
                WITH d AS (DELETE FROM auth_code WHERE expires_at < \(bind: cutoffs.authCodeExpiredBefore) RETURNING 1)
                SELECT count(*)::int AS n FROM d
                """),
            sessions: try await count(sql, """
                WITH d AS (DELETE FROM device_session
                    WHERE revoked_at < \(bind: cutoffs.sessionEndedBefore)
                       OR refresh_expires_at < \(bind: cutoffs.sessionEndedBefore) RETURNING 1)
                SELECT count(*)::int AS n FROM d
                """),
            securityEvents: try await count(sql, """
                WITH moved AS (DELETE FROM security_event WHERE at < \(bind: cutoffs.securityEventBefore) RETURNING *),
                archived AS (
                    INSERT INTO security_event_archive (id, at, event_type, account_id, device_session_id, platform)
                    SELECT id, at, event_type, account_id, device_session_id, platform FROM moved
                    RETURNING 1)
                SELECT count(*)::int AS n FROM archived
                """)
        )
    }

    private struct Row: Decodable { let n: Int }

    private static func count(_ sql: any SQLDatabase, _ query: SQLQueryString) async throws -> Int {
        try await sql.raw(query).first(decoding: Row.self)?.n ?? 0
    }
}
