import Foundation
import FluentSQL

/// Staff account reads and writes. Writes run after `SettingsWriter.lock`.
/// Review accounts (ADR-0027) are neither listed nor counted.
extension SettingsQueries {
    private static let columns: SQLQueryString = "id AS account_id, display_name AS name, email, role, is_active"

    func staff(shopID: UUID) async throws -> [StaffView] {
        try await sql.raw("""
            SELECT \(Self.columns) FROM account WHERE shop_id = \(bind: shopID) AND kind = 'normal'
            ORDER BY (role = 'owner') DESC, lower(display_name), created_at, id
            """).all(decoding: StaffView.self)
    }

    func staffAccount(shopID: UUID, id: UUID) async throws -> StaffView? {
        try await sql.raw("""
            SELECT \(Self.columns) FROM account WHERE shop_id = \(bind: shopID) AND kind = 'normal' AND id = \(bind: id)
            """).first(decoding: StaffView.self)
    }
}

extension SettingsWriter {
    /// Any account of the shop uses the address, review accounts included.
    func emailTaken(shopID: UUID, email: String) async throws -> Bool {
        try await sql.raw("SELECT 1 AS one FROM account WHERE shop_id = \(bind: shopID) AND email = \(bind: email)").first() != nil
    }

    func activeStaffCount(shopID: UUID, besides id: UUID?) async throws -> Int {
        try await sql.raw("""
            SELECT count(*)::int AS n FROM account
            WHERE shop_id = \(bind: shopID) AND role = 'staff' AND kind = 'normal' AND is_active AND id IS DISTINCT FROM \(bind: id)
            """).first()?.decode(column: "n", as: Int.self) ?? 0
    }

    func insertStaff(shopID: UUID, id: UUID, name: String, email: String, at now: Date) async throws {
        try await sql.raw("""
            INSERT INTO account (id, shop_id, role, email, display_name, created_at, updated_at)
            VALUES (\(bind: id), \(bind: shopID), 'staff', \(bind: email), \(bind: name), \(timestamp(now)), \(timestamp(now)))
            """).run()
    }

    /// Switching an account off ends every live phone of it in the same
    /// transaction and forgets their push tokens (FR-5).
    func setStaffActive(id: UUID, _ active: Bool, at now: Date) async throws {
        let deactivated: SQLQueryString = active ? "NULL" : timestamp(now)
        try await sql.raw("""
            UPDATE account SET is_active = \(bind: active), deactivated_at = \(deactivated), updated_at = \(timestamp(now))
            WHERE id = \(bind: id)
            """).run()
        if !active {
            try await sql.raw("""
                UPDATE device_session SET revoked_at = \(timestamp(now)), revoked_reason = 'account_deactivated', push_token = NULL
                WHERE account_id = \(bind: id) AND revoked_at IS NULL
                """).run()
        }
    }
}
