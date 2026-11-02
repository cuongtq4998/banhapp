import Foundation
import Fluent
import FluentSQL
import PostgresNIO

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
    /// `expected` any more (someone else moved the order first). The date or
    /// fee of the move goes in the same UPDATE, so no order holds a step
    /// without its field.
    func move(id: UUID, request: StatusRequest, actor: OrderActor) async throws -> Bool {
        try await sql.raw("SELECT set_config('app.actor_type', \(bind: actor.type), true)").run()
        try await sql.raw("SELECT set_config('app.actor_id', \(bind: actor.id.uuidString), true)").run()
        try await sql.raw("SELECT set_config('app.actor_name', \(bind: actor.name), true)").run()
        do {
            let rows = try await sql.raw("""
                UPDATE customer_order SET status = \(bind: request.target.rawValue), cancel_reason = \(bind: request.reason?.rawValue)::text,
                    expected_delivery_date = COALESCE(\(bind: request.expectedDate?.description)::date, expected_delivery_date),
                    delivery_fee_final_vnd = COALESCE(\(bind: request.feeVND)::int, delivery_fee_final_vnd),
                    delivery_fee_set_at = CASE WHEN \(bind: request.feeVND)::int IS NULL THEN delivery_fee_set_at ELSE now() END,
                    updated_at = now()
                WHERE id = \(bind: id) AND status = \(bind: request.expected.rawValue) RETURNING id
                """).all()
            guard !rows.isEmpty else { return false }
            if let date = request.expectedDate { try await recordFirstDate(id: id, date: date, actor: actor) }
            return true
        } catch let error as PSQLError where error.serverInfo?[.constraintName] == Self.dayLoadConstraint {
            // The cancel would take `day_load` below zero: the counter holds fewer cakes
            // than the order (only manual SQL gets there; ADR-0030 keeps no silent floor).
            // The surrounding transaction rolls back, so the order stays as it was.
            throw APIError(.internalError, details: ["reason": .string(Self.dayLoadInconsistent)])
        }
    }

    /// The first date entry is a record row with no old date.
    private func recordFirstDate(id: UUID, date: BusinessDate, actor: OrderActor) async throws {
        try await sql.raw("""
            INSERT INTO order_expected_date_change (order_id, old_date, new_date, changed_by_account_id, changed_by_name)
            VALUES (\(bind: id), NULL, \(bind: date.description)::date, \(bind: actor.id), \(bind: actor.name))
            """).run()
    }

    static let dayLoadConstraint = "day_load_within_limit"
    /// Detail of the 500 answer and the log line when the counter is wrong.
    static let dayLoadInconsistent = "DAY_LOAD_INCONSISTENT"
}
