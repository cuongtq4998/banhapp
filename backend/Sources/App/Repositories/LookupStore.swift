import Foundation
import Fluent
import FluentSQL

/// What the lookup service needs from storage; one query, no second round trip.
protocol LookupStore: Sendable {
    /// Up to `limit` rows of the window, newest first, after `cursor`.
    func fetchPage(phone: String, cursor: LookupCursor?, windowStart: Date, limit: Int) async throws -> [LookupRow]
}

/// One stored order with its cake lines, before masking.
struct LookupRow: Decodable, Sendable {
    let id: UUID
    let order_code: String
    let status: String
    let created_at: Date
    let district_name: String
    let requested: String
    let slot_start: String
    let slot_end: String
    let expected: String?
    let items_subtotal_vnd: Int
    let delivery_fee_vnd: Int
    let delivery_fee_final_vnd: Int?
    let items: [LookupOrderView.Item]
}

struct PostgresLookupStore: LookupStore {
    let database: any Database

    func fetchPage(phone: String, cursor: LookupCursor?, windowStart: Date, limit: Int) async throws -> [LookupRow] {
        guard let sql = database as? any SQLDatabase else { throw APIError(.serviceUnavailable) }
        // Same statement for every phone; the cursor test is a no-op when absent.
        let hasCursor = cursor != nil
        let at = cursor?.placedAt ?? Date.distantFuture
        let after = cursor?.orderID ?? UUID()
        return try await translatingDatabaseErrors {
            try await sql.raw("""
                SELECT o.id, o.order_code, o.status, o.created_at, o.district_name,
                       to_char(o.delivery_date, 'YYYY-MM-DD') AS requested,
                       to_char(o.slot_start_time, 'HH24:MI') AS slot_start, to_char(o.slot_end_time, 'HH24:MI') AS slot_end,
                       to_char(o.expected_delivery_date, 'YYYY-MM-DD') AS expected,
                       o.items_subtotal_vnd, o.delivery_fee_vnd, o.delivery_fee_final_vnd,
                       COALESCE(i.lines, '[]'::jsonb) AS items
                FROM customer_order o
                LEFT JOIN LATERAL (
                    SELECT jsonb_agg(jsonb_build_object('cake_name', product_name, 'quantity', quantity,
                                                        'unit_price_vnd', unit_price_vnd) ORDER BY product_name, product_id) AS lines
                    FROM customer_order_item WHERE order_id = o.id) i ON true
                WHERE o.customer_phone = \(bind: phone)
                  AND (o.status NOT IN ('Finished', 'Cancelled') OR o.status_changed_at >= \(bind: windowStart))
                  AND (\(bind: !hasCursor) OR (o.created_at, o.id) < (\(bind: at), \(bind: after)))
                ORDER BY o.created_at DESC, o.id DESC
                LIMIT \(bind: limit)
                """).all(decoding: LookupRow.self)
        }
    }
}
