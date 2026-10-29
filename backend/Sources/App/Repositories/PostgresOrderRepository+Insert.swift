import Foundation
import Fluent
import FluentSQL

extension PostgresOrderRepository {
    /// ADR-0008 in one transaction: make sure the `day_load` row exists, raise
    /// it with the guarded update (zero rows means the date cannot hold the
    /// order), then insert the order, its items and the `created` event. Any
    /// outcome but `.created` rolls everything back, including the counter.
    func insertOrder(_ order: NewOrder) async throws -> OrderInsertOutcome {
        let database = self.database
        _ = try requireSQL()
        return try await translatingDatabaseErrors {
            do {
                return try await database.transaction { transaction in
                    guard let sql = transaction as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
                    return try await Self.write(order, on: sql)
                }
            } catch let stop as Rollback {
                return stop.outcome
            }
        }
    }

    /// Thrown inside the transaction to roll it back with a known outcome.
    private struct Rollback: Error {
        let outcome: OrderInsertOutcome
    }

    private static func write(_ order: NewOrder, on sql: any SQLDatabase) async throws -> OrderInsertOutcome {
        let request = order.request
        let date = request.deliveryDate.description
        try await sql.raw("""
            INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit)
            VALUES (\(bind: order.shopID), \(bind: date)::date, 0, \(bind: order.dailyLimit))
            ON CONFLICT DO NOTHING
            """).run()
        let raised = try await sql.raw("""
            UPDATE day_load
               SET cakes_accepted = cakes_accepted + \(bind: request.totalCakes),
                   capacity_limit = \(bind: order.dailyLimit), updated_at = now()
             WHERE shop_id = \(bind: order.shopID) AND delivery_date = \(bind: date)::date
               AND cakes_accepted + \(bind: request.totalCakes) <= \(bind: order.dailyLimit)
            RETURNING cakes_accepted
            """).all()
        if raised.isEmpty { throw Rollback(outcome: .capacityExceeded) }

        guard let inserted = try await insertOrderRow(order, on: sql) else {
            let winner = try await PostgresOrderQueries.findOrder(sql, order.shopID, order.idempotencyKey)
            throw Rollback(outcome: winner == nil ? .codeCollision : .duplicateKey)
        }
        for line in order.lines {
            try await sql.raw("""
                INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd)
                VALUES (\(bind: order.orderID), \(bind: line.productID), \(bind: line.productName),
                        \(bind: line.unitPriceVND), \(bind: line.quantity), \(bind: line.lineTotalVND))
                """).run()
        }
        try await sql.raw("""
            INSERT INTO order_event (order_id, event_type, from_status, to_status, actor_type)
            VALUES (\(bind: order.orderID), 'created', NULL, 'New', 'customer')
            """).run()
        return .created(inserted)
    }

    /// `ON CONFLICT DO NOTHING` without a target covers the idempotency key
    /// and the order code alike; the caller tells them apart by looking for the key.
    private static func insertOrderRow(_ order: NewOrder, on sql: any SQLDatabase) async throws -> PlacedOrder? {
        let request = order.request
        let createdAt = PostgresTimestamp.text(order.createdAt)
        let row = try await sql.raw("""
            INSERT INTO customer_order (
                id, shop_id, order_code, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes,
                customer_name, customer_phone, customer_address, note, idempotency_key, request_hash,
                client_platform, app_version, status_changed_at, created_at, updated_at)
            VALUES (
                \(bind: order.orderID), \(bind: order.shopID), \(bind: order.orderCode),
                \(bind: request.deliveryDate.description)::date, \(bind: request.slotID),
                \(bind: order.slot.startTime)::time, \(bind: order.slot.endTime)::time,
                \(bind: request.districtID), \(bind: order.district.name), \(bind: order.district.deliveryFeeVND),
                \(bind: order.itemsSubtotalVND), \(bind: order.totalVND), \(bind: request.totalCakes),
                \(bind: request.customerName), \(bind: request.customerPhone), \(bind: request.customerAddress),
                \(bind: request.note), \(bind: order.idempotencyKey), \(bind: order.requestHash),
                \(bind: order.platform), \(bind: order.appVersion),
                \(bind: createdAt)::timestamptz, \(bind: createdAt)::timestamptz, \(bind: createdAt)::timestamptz)
            ON CONFLICT DO NOTHING
            RETURNING order_code, \(unsafeRaw: PostgresOrderQueries.createdAtText) AS created_at
            """).first()
        guard let row else { return nil }
        return PlacedOrder(
            orderCode: try row.decode(column: "order_code", as: String.self),
            createdAt: try row.decode(column: "created_at", as: String.self)
        )
    }
}
