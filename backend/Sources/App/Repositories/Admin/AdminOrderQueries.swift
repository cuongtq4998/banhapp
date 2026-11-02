import Foundation
import Fluent
import FluentSQL

private extension SQLQueryString {
    mutating func add(_ part: SQLQueryString) { self += part }
}

private let isoSeconds = "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'"
private let isoMicros = "'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"'"

private let summaryColumns: SQLQueryString = """
    id, order_code, status, customer_name, delivery_date::text AS delivery_date, \
    expected_delivery_date::text AS expected_delivery_date, \
    (\(unsafeRaw: OrderListDate.sql))::text AS list_date, \
    to_char(slot_start_time, 'HH24:MI') AS slot_start, to_char(slot_end_time, 'HH24:MI') AS slot_end, \
    total_cakes, total_vnd, district_name, \
    to_char(created_at AT TIME ZONE 'UTC', \(unsafeRaw: isoSeconds)) AS created_at, \
    slot_start_time::text AS cursor_time, \
    to_char(created_at AT TIME ZONE 'UTC', \(unsafeRaw: isoMicros)) AS cursor_created
    """

/// Read SQL of the admin order endpoints. Rules live in the service; every
/// visibility decision goes through `OrderWindow`. Values are always bound.
struct AdminOrderQueries: Sendable {
    let sql: any SQLDatabase

    /// One page plus one row, to know whether there is a next page.
    func list(window: OrderWindow, query: OrderListQuery) async throws -> [OrderSummaryRow] {
        var text: SQLQueryString = "SELECT \(summaryColumns) FROM customer_order WHERE \(window.predicate)"
        if let statuses = query.status.statuses {
            text.add(" AND status IN (\(binds: statuses.map(\.rawValue)))")
        }
        if let date = query.deliveryDate { text.add(" AND \(unsafeRaw: OrderListDate.sql) = \(bind: date.description)::date") }
        if let search = query.search { text.add(" AND \(search.condition)") }
        if let cursor = query.cursor {
            text.add("""
                 AND (\(unsafeRaw: OrderListDate.sql), slot_start_time, created_at, id) > \
                (\(bind: cursor.listDate)::date, \(bind: cursor.slotStart)::time, \
                \(bind: cursor.createdAt)::timestamptz, \(bind: cursor.id)::uuid)
                """)
        }
        text.add(" ORDER BY \(unsafeRaw: OrderListDate.sql), slot_start_time, created_at, id LIMIT \(literal: OrderListQuery.pageSize + 1)")
        return try await sql.raw(text).all(decoding: OrderSummaryRow.self)
    }

    /// The badge (FR-13): open orders due today or earlier, whatever the filters.
    func unfinishedCount(window: OrderWindow, today: BusinessDate) async throws -> Int {
        let row = try await sql.raw("""
            SELECT count(*)::int AS total FROM customer_order
            WHERE \(window.predicate) AND status IN (\(unsafeRaw: OrderStatus.sqlList(OrderStatus.open))) AND \(unsafeRaw: OrderListDate.sql) <= \(bind: today.description)::date
            """).first(decoding: CountResult.self)
        return row?.total ?? 0
    }

    /// An order by its code, only if the window shows it.
    func find(code: String, window: OrderWindow) async throws -> OrderFoundRow? {
        try await sql.raw("SELECT id, status FROM customer_order WHERE order_code = \(bind: code) AND \(window.predicate)")
            .first(decoding: OrderFoundRow.self)
    }

    /// An order of this shop and kind (demo or real) whatever its age: only the
    /// repeat rule of the status route may use it (FR-19).
    func findIgnoringAge(code: String, window: OrderWindow) async throws -> OrderFoundRow? {
        try await sql.raw("""
            SELECT id, status FROM customer_order
            WHERE order_code = \(bind: code) AND shop_id = \(bind: window.shopID) AND is_demo = \(bind: window.demoOnly)
            """).first(decoding: OrderFoundRow.self)
    }

    /// The detail of an order id, with no window: used for the reply of a change
    /// that was just made or refused in the same transaction.
    func detail(id: UUID, range: ExpectedDateRange) async throws -> OrderDetail? {
        guard let summary = try await sql.raw("SELECT \(summaryColumns) FROM customer_order WHERE id = \(bind: id)")
            .first(decoding: OrderSummaryRow.self),
            let more = try await sql.raw("""
                SELECT customer_phone, customer_address, note, items_subtotal_vnd, delivery_fee_vnd, cancel_reason,
                       expected_delivery_date::text AS expected_delivery_date, delivery_fee_final_vnd
                FROM customer_order WHERE id = \(bind: id)
                """).first(decoding: OrderDetailRow.self) else { return nil }
        let lines = try await sql.raw("""
            SELECT product_name, quantity, unit_price_vnd, line_total_vnd FROM customer_order_item
            WHERE order_id = \(bind: id) ORDER BY product_name, product_id
            """).all(decoding: OrderLineRow.self)
        let last = try await lastChange(id: id)
        let status = OrderStatus.fromStored(summary.status)
        return OrderDetail(
            summary: summary.summary, customerPhone: more.customerPhone, customerAddress: more.customerAddress,
            note: more.note,
            items: lines.map { OrderLine(productName: $0.productName, quantity: $0.quantity, unitPriceVND: $0.unitPriceVND, lineTotalVND: $0.lineTotalVND) },
            itemsSubtotalVND: more.itemsSubtotalVND, deliveryFeeVND: more.deliveryFeeVND, cancelReason: more.cancelReason,
            allowedActions: status?.allowedActions.map(\.rawValue) ?? [],
            lastChange: last ?? OrderLastChange(actorName: nil, at: summary.createdAt, kind: .status),
            process: OrderProcessFields(
                requestedDeliveryDate: summary.deliveryDate, expectedDeliveryDate: more.expectedDeliveryDate,
                deliveryFeeEstimateVND: more.deliveryFeeVND, deliveryFeeFinalVND: more.deliveryFeeFinalVND,
                amountToCollectVND: more.deliveryFeeFinalVND.map { more.itemsSubtotalVND + $0 }, expectedDateRange: range.view,
                dateChanges: try await dateChanges(id: id), feeCorrections: try await feeCorrections(id: id),
                deliveryFeeEntry: try await deliveryFeeEntry(id: id)
            )
        )
    }

    func lastEvent(id: UUID) async throws -> OrderEventRow? {
        try await sql.raw("""
            SELECT actor_id, actor_name, from_status, to_char(created_at AT TIME ZONE 'UTC', \(unsafeRaw: isoSeconds)) AS at
            FROM order_event WHERE order_id = \(bind: id) ORDER BY id DESC LIMIT 1
            """).first(decoding: OrderEventRow.self)
    }
}
