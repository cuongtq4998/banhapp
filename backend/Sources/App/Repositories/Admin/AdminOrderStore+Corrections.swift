import Foundation
import Fluent
import FluentSQL

/// The compare-and-set writes of the two corrections. The record row goes in
/// the same transaction as the UPDATE.
extension AdminOrderWriter {
    /// False when the status or the stored date is not the one the caller saw.
    func changeDate(id: UUID, request: DateMoveRequest, actor: OrderActor) async throws -> Bool {
        try await setActor(actor)
        let rows = try await sql.raw("""
            UPDATE customer_order SET expected_delivery_date = \(bind: request.new.description)::date, updated_at = now()
            WHERE id = \(bind: id) AND status = \(bind: OrderStatus.deliveryDateScheduled.rawValue)
              AND expected_delivery_date = \(bind: request.previous.description)::date RETURNING id
            """).all()
        guard !rows.isEmpty else { return false }
        try await sql.raw("""
            INSERT INTO order_expected_date_change (order_id, old_date, new_date, changed_by_account_id, changed_by_name)
            VALUES (\(bind: id), \(bind: request.previous.description)::date, \(bind: request.new.description)::date, \(bind: actor.id), \(bind: actor.name))
            """).run()
        return true
    }

    /// False when the status is not `DeliveryStarted` or the stored fee differs.
    func correctFee(id: UUID, request: FeeCorrectionRequest, actor: OrderActor) async throws -> Bool {
        try await setActor(actor)
        let rows = try await sql.raw("""
            UPDATE customer_order SET delivery_fee_final_vnd = \(bind: request.new), delivery_fee_set_at = now(), updated_at = now()
            WHERE id = \(bind: id) AND status = \(bind: OrderStatus.deliveryStarted.rawValue)
              AND delivery_fee_final_vnd = \(bind: request.previous) RETURNING id
            """).all()
        guard !rows.isEmpty else { return false }
        try await sql.raw("""
            INSERT INTO order_fee_correction (order_id, old_fee_vnd, new_fee_vnd, changed_by_account_id, changed_by_name)
            VALUES (\(bind: id), \(bind: request.previous), \(bind: request.new), \(bind: actor.id), \(bind: actor.name))
            """).run()
        return true
    }

    func lastDateChanger(id: UUID) async throws -> UUID? {
        try await lastChanger(table: "order_expected_date_change", id: id)
    }

    func lastFeeChanger(id: UUID) async throws -> UUID? {
        try await lastChanger(table: "order_fee_correction", id: id)
    }

    private func lastChanger(table: String, id: UUID) async throws -> UUID? {
        let row = try await sql.raw("SELECT changed_by_account_id FROM \(unsafeRaw: table) WHERE order_id = \(bind: id) ORDER BY id DESC LIMIT 1").first()
        return try row?.decode(column: "changed_by_account_id", as: UUID?.self) ?? nil
    }
}
