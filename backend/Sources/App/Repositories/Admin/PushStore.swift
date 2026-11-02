import Foundation
import Fluent
import FluentSQL

/// The push token is two columns of `device_session` (data-model/04): this is
/// the only code that writes them besides the statements that revoke a
/// session, which null the token in the same statement (`AuthStore`).
struct PushStore: PushTokenStore {
    let database: any Database

    private struct TargetRow: Decodable {
        let platform: String
        let pushToken: String
        let environment: String?
        private enum CodingKeys: String, CodingKey { case platform, pushToken = "push_token", environment = "push_apns_environment" }
    }

    /// Stores the token on the session and takes it from any other session
    /// (a reinstalled app or a signed-out phone); one token has one owner.
    /// False when the session is not a live session of that platform.
    func register(sessionID: UUID, platform: String, token: String, apnsEnvironment: String?) async throws -> Bool {
        try await translatingDatabaseErrors {
            try await database.transaction { handle in
                guard let sql = handle as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
                let live = try await sql.raw("""
                    SELECT 1 AS one FROM device_session
                     WHERE id = \(bind: sessionID) AND platform = \(bind: platform) AND revoked_at IS NULL FOR UPDATE
                    """).first()
                guard live != nil else { return false }
                try await sql.raw("""
                    UPDATE device_session SET push_token = NULL, push_apns_environment = NULL
                     WHERE push_token = \(bind: token) AND id <> \(bind: sessionID)
                    """).run()
                try await sql.raw("""
                    UPDATE device_session SET push_token = \(bind: token), push_apns_environment = \(bind: apnsEnvironment)
                     WHERE id = \(bind: sessionID)
                    """).run()
                return true
            }
        }
    }

    /// Live phones of active staff and owner accounts of the shop. Review
    /// accounts see demo data only and never get a push (ADR-0027).
    func targets(shopID: UUID, now: Date) async throws -> [PushTarget] {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        let rows = try await translatingDatabaseErrors {
            try await sql.raw("""
                SELECT s.platform, s.push_token, s.push_apns_environment
                  FROM device_session s JOIN account a ON a.id = s.account_id
                 WHERE a.shop_id = \(bind: shopID) AND a.is_active AND a.kind <> 'review'
                   AND s.revoked_at IS NULL AND s.refresh_expires_at > \(timestamp(now)) AND s.push_token IS NOT NULL
                 ORDER BY s.created_at, s.id
                """).all(decoding: TargetRow.self)
        }
        return rows.compactMap { row in
            PushTarget.Platform(rawValue: row.platform).map {
                PushTarget(platform: $0, token: row.pushToken, apnsEnvironment: row.environment)
            }
        }
    }

    func clear(token: String) async throws {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        try await translatingDatabaseErrors {
            try await sql.raw("""
                UPDATE device_session SET push_token = NULL, push_apns_environment = NULL WHERE push_token = \(bind: token)
                """).run()
        }
    }
}
