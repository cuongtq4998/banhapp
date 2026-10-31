import Foundation
import FluentSQL

struct NewSession: Sendable {
    let id: UUID
    let accountID: UUID
    let installationID: UUID
    let platform: String
    let deviceName: String
    let accessHash: Data
    let refreshHash: Data
    let now: Date
}

/// A session row read for renewal, with the account state.
struct LockedSession: Decodable, Sendable {
    let accountID: UUID
    let platform: String
    let isRevoked: Bool
    let accountActive: Bool
    let refreshHash: Data
    let previousHash: Data?
    let rotatedAt: Date?
    let refreshExpiresAt: Date

    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id", platform, isRevoked = "is_revoked", accountActive = "account_active"
        case refreshHash = "refresh_token_hash", previousHash = "previous_refresh_hash"
        case rotatedAt = "refresh_rotated_at", refreshExpiresAt = "refresh_expires_at"
    }
}

enum SecurityEventType: String, Sendable {
    case signIn = "sign_in"
    case signOut = "sign_out"
    case signOutOthers = "sign_out_others"
    case refreshReuseDetected = "refresh_reuse_detected"
}

enum RevokeReason: String, Sendable {
    case signedOut = "signed_out"
    case signedOutOthers = "signed_out_others"
    case reuseDetected = "reuse_detected"
    case replaced
}

private struct CountRow: Decodable { let total: Int }

extension AuthTransaction {
    /// Unrevoked, unexpired sessions of the account on this installation.
    func liveSessionCount(accountID: UUID, installationID: UUID, now: Date) async throws -> Int {
        try await sql.raw("""
            SELECT count(*)::int AS total FROM device_session
             WHERE account_id = \(bind: accountID) AND installation_id = \(bind: installationID)
               AND revoked_at IS NULL AND refresh_expires_at > \(timestamp(now))
            """).first(decoding: CountRow.self)?.total ?? 0
    }

    func revokeInstallation(_ installationID: UUID, now: Date) async throws {
        try await sql.raw("""
            UPDATE device_session SET revoked_at = \(timestamp(now)), revoked_reason = 'replaced', push_token = NULL
             WHERE installation_id = \(bind: installationID) AND revoked_at IS NULL
            """).run()
    }

    func insertSession(_ session: NewSession) async throws {
        let refreshExpires = session.now.addingTimeInterval(AuthPolicy.refreshLifetime)
        let accessExpires = session.now.addingTimeInterval(AuthPolicy.accessLifetime)
        try await sql.raw("""
            INSERT INTO device_session (id, account_id, installation_id, platform, device_name, sign_in_method,
                access_token_hash, access_expires_at, refresh_token_hash, refresh_expires_at, last_used_at, created_at)
            VALUES (\(bind: session.id), \(bind: session.accountID), \(bind: session.installationID),
                \(bind: session.platform), \(bind: session.deviceName), 'code',
                \(bind: session.accessHash), \(timestamp(accessExpires)), \(bind: session.refreshHash),
                \(timestamp(refreshExpires)), \(timestamp(session.now)), \(timestamp(session.now)))
            """).run()
    }

    func insertEvent(_ type: SecurityEventType, accountID: UUID, sessionID: UUID?, platform: String?, at now: Date) async throws {
        try await sql.raw("""
            INSERT INTO security_event (at, event_type, account_id, device_session_id, platform)
            VALUES (\(timestamp(now)), \(bind: type.rawValue), \(bind: accountID), \(bind: sessionID), \(bind: platform))
            """).run()
    }

    func lockSession(id: UUID) async throws -> LockedSession? {
        try await sql.raw("""
            SELECT s.account_id, s.platform, (s.revoked_at IS NOT NULL) AS is_revoked, a.is_active AS account_active,
                   s.refresh_token_hash, s.previous_refresh_hash, s.refresh_rotated_at, s.refresh_expires_at
              FROM device_session s JOIN account a ON a.id = s.account_id
             WHERE s.id = \(bind: id) FOR UPDATE OF s
            """).first(decoding: LockedSession.self)
    }

    /// New pair. `keepPrevious` is the lost-answer retry: the replaced
    /// credential stays the "previous" one and its 20 s window is not extended.
    func rotate(sessionID: UUID, access: Data, refresh: Data, replacing current: Data, keepPrevious: Bool, now: Date) async throws {
        let accessExpires = now.addingTimeInterval(AuthPolicy.accessLifetime)
        let refreshExpires = now.addingTimeInterval(AuthPolicy.refreshLifetime)
        let previous: SQLQueryString = keepPrevious ? "previous_refresh_hash" : "\(bind: current)"
        let rotated: SQLQueryString = keepPrevious ? "refresh_rotated_at" : timestamp(now)
        try await sql.raw("""
            UPDATE device_session
               SET access_token_hash = \(bind: access), access_expires_at = \(timestamp(accessExpires)),
                   refresh_token_hash = \(bind: refresh), previous_refresh_hash = \(previous),
                   refresh_rotated_at = \(rotated), refresh_expires_at = \(timestamp(refreshExpires)),
                   last_used_at = \(timestamp(now))
             WHERE id = \(bind: sessionID)
            """).run()
    }

    func revoke(sessionID: UUID, reason: RevokeReason, now: Date) async throws {
        try await sql.raw("""
            UPDATE device_session SET revoked_at = \(timestamp(now)), revoked_reason = \(bind: reason.rawValue), push_token = NULL
             WHERE id = \(bind: sessionID) AND revoked_at IS NULL
            """).run()
    }

    /// Every other unrevoked session of the account, in one statement.
    func revokeOthers(accountID: UUID, keeping sessionID: UUID, now: Date) async throws {
        try await sql.raw("""
            UPDATE device_session SET revoked_at = \(timestamp(now)), revoked_reason = 'signed_out_others', push_token = NULL
             WHERE account_id = \(bind: accountID) AND id <> \(bind: sessionID) AND revoked_at IS NULL
            """).run()
    }
}
