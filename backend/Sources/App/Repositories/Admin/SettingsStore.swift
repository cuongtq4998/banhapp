import Foundation
import Fluent
import FluentSQL

/// Entry point of the owner-settings SQL. A write is one transaction that
/// first locks the `shop_setting` row, so two owner devices, a staff addition
/// and the "last active" checks are counted one after the other (ADR-0031).
struct SettingsStore: Sendable {
    let database: any Database

    func read<T: Sendable>(_ work: @Sendable (SettingsQueries) async throws -> T) async throws -> T {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        return try await translatingDatabaseErrors { try await work(SettingsQueries(sql: sql)) }
    }

    /// Everything the closure writes commits together, or nothing does.
    func write<T: Sendable>(_ work: @escaping @Sendable (SettingsWriter) async throws -> T) async throws -> T {
        try await translatingDatabaseErrors {
            try await database.transaction { handle in
                guard let sql = handle as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
                return try await work(SettingsWriter(sql: sql, queries: SettingsQueries(sql: sql)))
            }
        }
    }
}

/// One save of one form (`settings_change.batch_id`) and who made it.
struct ChangeBatch: Sendable {
    let id = UUID()
    let shopID: UUID
    let accountID: UUID
    let actorName: String
    let at: Date
}

/// One field that may have changed; equal values are not recorded.
struct FieldChange: Sendable {
    let field: String
    let old: String?
    let new: String?
}

struct SettingsWriter: Sendable {
    let sql: any SQLDatabase
    let queries: SettingsQueries

    /// Takes the shop's serialisation lock and answers whether the row exists.
    func lock(shopID: UUID) async throws {
        let row = try await sql.raw("SELECT 1 AS one FROM shop_setting WHERE shop_id = \(bind: shopID) FOR UPDATE").first()
        if row == nil { throw CatalogRepositoryError.shopNotFound }
    }

    /// Appends a `settings_change` row for each field whose value differs (BR-3).
    func record(_ batch: ChangeBatch, entity: String, id: UUID?, _ changes: [FieldChange]) async throws {
        for change in changes where change.old != change.new {
            try await sql.raw("""
                INSERT INTO settings_change (batch_id, shop_id, actor_account_id, actor_name, entity_type, entity_id, field, old_value, new_value, changed_at)
                VALUES (\(bind: batch.id), \(bind: batch.shopID), \(bind: batch.accountID), \(bind: batch.actorName), \(bind: entity),
                        \(bind: id), \(bind: change.field), \(bind: change.old), \(bind: change.new), \(timestamp(batch.at)))
                """).run()
        }
    }

    func updateShop(shopID: UUID, _ value: ShopSection, at now: Date) async throws {
        try await sql.raw("""
            UPDATE shop SET name = \(bind: value.name), greeting = \(bind: value.greeting),
                phone_contact = \(bind: value.phoneContact), zalo_contact = \(bind: value.zaloContact), updated_at = \(timestamp(now))
            WHERE id = \(bind: shopID)
            """).run()
    }

    func updateOrdering(shopID: UUID, dailyLimit: Int, leadDays: Int, minQty: Int, at now: Date) async throws {
        try await sql.raw("""
            UPDATE shop_setting SET daily_limit = \(bind: dailyLimit), lead_days = \(bind: leadDays),
                min_qty = \(bind: minQty), updated_at = \(timestamp(now))
            WHERE shop_id = \(bind: shopID)
            """).run()
    }
}
