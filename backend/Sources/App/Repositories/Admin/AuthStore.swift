import Foundation
import Fluent
import FluentSQL

enum AccountRole: String, Decodable, Sendable {
    case owner
    case staff
}

/// What a request needs to know about a session and its account.
struct AdminSessionRecord: Decodable, Sendable {
    let sessionID: UUID
    let accountID: UUID
    let role: AccountRole
    let isReview: Bool
    let displayName: String
    let accessHash: Data
    let accessExpiresAt: Date
    let refreshExpiresAt: Date
    let isRevoked: Bool
    let accountActive: Bool

    init(
        sessionID: UUID, accountID: UUID, role: AccountRole, isReview: Bool, displayName: String, accessHash: Data,
        accessExpiresAt: Date, refreshExpiresAt: Date, isRevoked: Bool, accountActive: Bool
    ) {
        self.sessionID = sessionID; self.accountID = accountID; self.role = role; self.isReview = isReview
        self.displayName = displayName; self.accessHash = accessHash; self.accessExpiresAt = accessExpiresAt
        self.refreshExpiresAt = refreshExpiresAt; self.isRevoked = isRevoked; self.accountActive = accountActive
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", accountID = "account_id", role, isReview = "is_review"
        case displayName = "display_name", accessHash = "access_hash"
        case accessExpiresAt = "access_expires_at", refreshExpiresAt = "refresh_expires_at"
        case isRevoked = "is_revoked", accountActive = "account_active"
    }
}

/// Finds a session by the id inside its access token; fakeable in tests.
protocol AdminSessionLookup: Sendable {
    func findSession(id: UUID) async throws -> AdminSessionRecord?
}

/// Timestamps cross the driver as ISO text with a cast (see `PostgresTimestamp`).
func timestamp(_ date: Date) -> SQLQueryString {
    "\(bind: PostgresTimestamp.text(date))::timestamptz"
}

/// SQL of sign-in and sessions. Rules live in the services; a transaction here
/// is one unit of work, and outcomes that must be kept (a wrong entry, a
/// revoked session) are returned, not thrown, so the commit happens.
struct AuthStore: AdminSessionLookup {
    let database: any Database

    func transaction<T: Sendable>(_ work: @escaping @Sendable (AuthTransaction) async throws -> T) async throws -> T {
        try await translatingDatabaseErrors {
            try await database.transaction { handle in
                guard let sql = handle as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
                return try await work(AuthTransaction(sql: sql))
            }
        }
    }

    func findSession(id: UUID) async throws -> AdminSessionRecord? {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        return try await translatingDatabaseErrors {
            try await sql.raw("""
                SELECT s.id AS session_id, s.account_id, a.role, (a.kind = 'review') AS is_review,
                       a.display_name, s.access_token_hash AS access_hash, s.access_expires_at,
                       s.refresh_expires_at, (s.revoked_at IS NOT NULL) AS is_revoked,
                       a.is_active AS account_active
                  FROM device_session s JOIN account a ON a.id = s.account_id
                 WHERE s.id = \(bind: id)
                """).first(decoding: AdminSessionRecord.self)
        }
    }

    /// Counts toward nothing; only tells the daily statistics the mail left.
    func markMailSent(codeID: UUID, at instant: Date) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("UPDATE auth_code SET mail_sent_at = \(timestamp(instant)) WHERE id = \(bind: codeID)").run()
    }
}

struct AuthTransaction: Sendable {
    let sql: any SQLDatabase
}
