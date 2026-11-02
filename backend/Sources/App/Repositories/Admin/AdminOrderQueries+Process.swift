import Foundation
import Fluent
import FluentSQL

private let isoSeconds = "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'"

/// Rows of the two append-only record tables, oldest first.
extension AdminOrderQueries {
    func dateChanges(id: UUID) async throws -> [DateChangeView] {
        try await sql.raw("""
            SELECT old_date::text AS old_date, new_date::text AS new_date, changed_by_name,
                   to_char(changed_at AT TIME ZONE 'UTC', \(unsafeRaw: isoSeconds)) AS changed_at
            FROM order_expected_date_change WHERE order_id = \(bind: id) ORDER BY id
            """).all(decoding: DateChangeRow.self).map(\.view)
    }

    func feeCorrections(id: UUID) async throws -> [FeeCorrectionView] {
        try await sql.raw("""
            SELECT old_fee_vnd, new_fee_vnd, changed_by_name,
                   to_char(changed_at AT TIME ZONE 'UTC', \(unsafeRaw: isoSeconds)) AS changed_at
            FROM order_fee_correction WHERE order_id = \(bind: id) ORDER BY id
            """).all(decoding: FeeCorrectionRow.self).map(\.view)
    }
}

struct DateChangeRow: Decodable, Sendable {
    let oldDate: String?, newDate: String, changedByName: String, changedAt: String

    private enum CodingKeys: String, CodingKey {
        case oldDate = "old_date", newDate = "new_date", changedByName = "changed_by_name", changedAt = "changed_at"
    }

    var view: DateChangeView { DateChangeView(oldDate: oldDate, newDate: newDate, changedByName: changedByName, changedAt: changedAt) }
}

struct FeeCorrectionRow: Decodable, Sendable {
    let oldFeeVND: Int, newFeeVND: Int, changedByName: String, changedAt: String

    private enum CodingKeys: String, CodingKey {
        case oldFeeVND = "old_fee_vnd", newFeeVND = "new_fee_vnd", changedByName = "changed_by_name", changedAt = "changed_at"
    }

    var view: FeeCorrectionView { FeeCorrectionView(oldFeeVND: oldFeeVND, newFeeVND: newFeeVND, changedByName: changedByName, changedAt: changedAt) }
}

/// Last change and fee entry reads (order-process.md 4.2).
extension AdminOrderQueries {
    /// The latest of the three records; ties: status, date, fee, larger id.
    func lastChange(id: UUID) async throws -> OrderLastChange? {
        try await sql.raw("""
            SELECT actor_name, to_char(at AT TIME ZONE 'UTC', \(unsafeRaw: isoSeconds)) AS at, kind FROM (
                SELECT actor_name, created_at AS at, 'status' AS kind, 1 AS rank, id FROM order_event WHERE order_id = \(bind: id)
                UNION ALL
                SELECT changed_by_name, changed_at, 'date', 2, id FROM order_expected_date_change WHERE order_id = \(bind: id)
                UNION ALL
                SELECT changed_by_name, changed_at, 'fee', 3, id FROM order_fee_correction WHERE order_id = \(bind: id)
            ) records ORDER BY records.at DESC, rank, id DESC LIMIT 1
            """).first(decoding: LastChangeRow.self).map(\.view)
    }

    /// The step that started delivery; nil before it and for backfilled rows.
    func deliveryFeeEntry(id: UUID) async throws -> DeliveryFeeEntryView? {
        try await sql.raw("""
            SELECT actor_name AS entered_by_name, to_char(created_at AT TIME ZONE 'UTC', \(unsafeRaw: isoSeconds)) AS entered_at
            FROM order_event WHERE order_id = \(bind: id) AND actor_name IS NOT NULL
              AND from_status = \(bind: OrderStatus.deliveryDateScheduled.rawValue) AND to_status = \(bind: OrderStatus.deliveryStarted.rawValue)
            ORDER BY id LIMIT 1
            """).first(decoding: FeeEntryRow.self).map { DeliveryFeeEntryView(enteredByName: $0.enteredByName, enteredAt: $0.enteredAt) }
    }
}

struct LastChangeRow: Decodable, Sendable {
    let actorName: String?, at: String, kind: String

    private enum CodingKeys: String, CodingKey { case actorName = "actor_name", at, kind }

    var view: OrderLastChange { OrderLastChange(actorName: actorName, at: at, kind: OrderLastChange.Kind(rawValue: kind) ?? .status) }
}

struct FeeEntryRow: Decodable, Sendable {
    let enteredByName: String, enteredAt: String

    private enum CodingKeys: String, CodingKey { case enteredByName = "entered_by_name", enteredAt = "entered_at" }
}
