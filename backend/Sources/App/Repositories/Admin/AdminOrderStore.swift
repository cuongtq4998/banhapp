import Foundation
import Fluent
import FluentSQL

/// Entry point of the admin order SQL: plain reads and one-transaction writes.
struct AdminOrderStore: Sendable {
    let database: any Database

    func read<T: Sendable>(_ work: @Sendable (AdminOrderQueries) async throws -> T) async throws -> T {
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        return try await translatingDatabaseErrors { try await work(AdminOrderQueries(sql: sql)) }
    }

    /// All statements share one transaction; a thrown error rolls everything back.
    func write<T: Sendable>(_ work: @escaping @Sendable (AdminOrderWriter) async throws -> T) async throws -> T {
        try await translatingDatabaseErrors {
            try await database.transaction { handle in
                guard let sql = handle as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
                return try await work(AdminOrderWriter(sql: sql, queries: AdminOrderQueries(sql: sql)))
            }
        }
    }
}

/// Who acts, as the triggers read it (`app.actor_*`, transaction-local).
struct OrderActor: Sendable {
    let type: String
    let id: UUID
    let name: String
}

struct AdminOrderWriter: Sendable {
    let sql: any SQLDatabase
    let queries: AdminOrderQueries

    /// The compare-and-set of ADR-0028: zero rows means the status was not
    /// `expected` any more (someone else moved the order first).
    func move(id: UUID, from expected: OrderStatus, to target: OrderStatus, reason: CancelReason?, actor: OrderActor) async throws -> Bool {
        try await sql.raw("SELECT set_config('app.actor_type', \(bind: actor.type), true)").run()
        try await sql.raw("SELECT set_config('app.actor_id', \(bind: actor.id.uuidString), true)").run()
        try await sql.raw("SELECT set_config('app.actor_name', \(bind: actor.name), true)").run()
        let rows = try await sql.raw("""
            UPDATE customer_order SET status = \(bind: target.rawValue), cancel_reason = \(bind: reason?.rawValue)::text, updated_at = now()
            WHERE id = \(bind: id) AND status = \(bind: expected.rawValue) RETURNING id
            """).all()
        return !rows.isEmpty
    }
}
