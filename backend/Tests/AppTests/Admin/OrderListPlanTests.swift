import XCTVapor
import FluentSQL
@testable import App

/// The default open list and its keyset page must be able to use the partial index.
final class OrderListPlanTests: AdminOrderTestCase {
    private static let indexName = "customer_order_open_list_idx"
    private static let seeded = 300

    private func plan(_ extra: SQLQueryString) async throws -> String {
        let window = OrderWindow(shopID: shopID, now: clock.now(), demoOnly: false)
        let statuses = OrderStatus.open.map(\.rawValue), order = OrderListDate.sql
        return try await app.db.transaction { db in
            let sql = db as! any SQLDatabase // swiftlint:disable:this force_cast
            try await sql.raw("SET LOCAL enable_seqscan = off").run()
            let rows = try await sql.raw("""
                EXPLAIN SELECT id FROM customer_order WHERE \(window.predicate) AND status IN (\(binds: statuses)) \(extra)
                ORDER BY \(unsafeRaw: order), slot_start_time, created_at, id LIMIT \(literal: OrderListQuery.pageSize + 1)
                """).all()
            return try rows.map { try $0.decode(column: "QUERY PLAN", as: String.self) }.joined(separator: "\n")
        }
    }

    func testOpenListAndItsKeysetPageCanUseTheOpenListIndex() async throws {
        for index in 0..<Self.seeded { try await place(.init(status: index % 3 == 0 ? "Processing" : "Received", date: day(index % 40), slot: index % 2 == 0 ? "08:00" : "10:00")) }
        try await run("ANALYZE customer_order")
        let first = try await plan("")
        let page = try await plan("AND (\(unsafeRaw: OrderListDate.sql), slot_start_time, created_at, id) > (\(bind: day(10))::date, '08:00'::time, \(timestamp(clock.now())), \(bind: UUID())::uuid)")
        print("PLAN first page:\n\(first)\nPLAN keyset page:\n\(page)")
        XCTAssertTrue(first.contains(Self.indexName), first)
        XCTAssertTrue(page.contains(Self.indexName), page)
    }
}
