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
