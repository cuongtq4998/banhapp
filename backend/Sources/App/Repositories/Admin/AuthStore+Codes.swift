import Foundation
import FluentSQL

struct StoredCode: Decodable, Sendable {
    let id: UUID
    let accountID: UUID?
    let hmac: Data
    let expiresAt: Date
    let wrongCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, accountID = "account_id", hmac = "code_hmac", expiresAt = "expires_at", wrongCount = "wrong_count"
    }
}

struct AccountRecord: Decodable, Sendable {
    let id: UUID
    let role: AccountRole
    let displayName: String
    let email: String

    private enum CodingKeys: String, CodingKey { case id, role, displayName = "display_name", email }
}

private struct TimeRow: Decodable { let at: Date }
private struct CountRow: Decodable { let total: Int }
private struct WrongRow: Decodable { let wrongCount: Int
    private enum CodingKeys: String, CodingKey { case wrongCount = "wrong_count" }
}

extension AuthTransaction {
    /// Serialises requests for one address, so two parallel requests cannot
    /// both pass the 30 s wait (released at commit).
    func lockAddress(_ email: String) async throws {
        try await sql.raw("SELECT pg_advisory_xact_lock(hashtextextended(\(bind: email), 0))").run()
    }

    func latestCodeCreatedAt(email: String) async throws -> Date? {
        try await sql.raw("SELECT created_at AS at FROM auth_code WHERE email = \(bind: email) ORDER BY created_at DESC LIMIT 1")
            .first(decoding: TimeRow.self)?.at
    }

    /// Codes of the address created strictly after `since` (the 60 minute look-back).
    func codeTimes(email: String, since: Date) async throws -> [Date] {
        try await sql.raw("""
            SELECT created_at AS at FROM auth_code
             WHERE email = \(bind: email) AND created_at > \(timestamp(since))
            """).all(decoding: TimeRow.self).map(\.at)
    }

    func codeCount(since: Date) async throws -> Int {
        try await sql.raw("SELECT count(*)::int AS total FROM auth_code WHERE created_at >= \(timestamp(since))")
            .first(decoding: CountRow.self)?.total ?? 0
    }

    func activeAccount(shopID: UUID, email: String) async throws -> AccountRecord? {
        try await sql.raw("""
            SELECT id, role, display_name, email FROM account
             WHERE shop_id = \(bind: shopID) AND email = \(bind: email) AND is_active
            """).first(decoding: AccountRecord.self)
    }

    func activeAccount(id: UUID) async throws -> AccountRecord? {
        try await sql.raw("SELECT id, role, display_name, email FROM account WHERE id = \(bind: id) AND is_active")
            .first(decoding: AccountRecord.self)
    }

    /// A newer code makes older ones unusable.
    func consumeOpenCodes(email: String, at now: Date) async throws {
        try await sql.raw("UPDATE auth_code SET consumed_at = \(timestamp(now)) WHERE email = \(bind: email) AND consumed_at IS NULL").run()
    }

    func insertCode(id: UUID, email: String, accountID: UUID?, hmac: Data, createdAt: Date, expiresAt: Date) async throws {
        try await sql.raw("""
            INSERT INTO auth_code (id, email, account_id, code_hmac, created_at, expires_at)
            VALUES (\(bind: id), \(bind: email), \(bind: accountID), \(bind: hmac), \(timestamp(createdAt)), \(timestamp(expiresAt)))
            """).run()
    }

    /// The unconsumed code of the address, locked: parallel guesses queue up
    /// here, so at most five are ever counted.
    func lockOpenCode(email: String) async throws -> StoredCode? {
        try await sql.raw("""
            SELECT id, account_id, code_hmac, expires_at, wrong_count FROM auth_code
             WHERE email = \(bind: email) AND consumed_at IS NULL
             ORDER BY created_at DESC LIMIT 1 FOR UPDATE
            """).first(decoding: StoredCode.self)
    }

    func addWrongEntry(codeID: UUID) async throws -> Int {
        try await sql.raw("UPDATE auth_code SET wrong_count = wrong_count + 1 WHERE id = \(bind: codeID) RETURNING wrong_count")
            .first(decoding: WrongRow.self)?.wrongCount ?? AuthPolicy.maxWrongEntries
    }

    func consumeCode(id: UUID, at now: Date) async throws {
        try await sql.raw("UPDATE auth_code SET consumed_at = \(timestamp(now)) WHERE id = \(bind: id)").run()
    }
}
