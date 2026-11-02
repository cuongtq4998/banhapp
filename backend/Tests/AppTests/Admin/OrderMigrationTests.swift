import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// Migrations 0003 and 0008 (data-model/05 section 11, 06 section 9): cancel_reason checks, the
/// immutable reason, event reason and actor, the search fold and the indexes.
final class OrderMigrationTests: AdminOrderTestCase {
    private func rejected(_ statement: SQLQueryString, _ message: String = "") async throws {
        do {
            try await sql.raw(statement).run()
            XCTFail("accepted: \(message)")
        } catch {
            // check_violation (23514) or foreign_key_violation (23503), as expected
            let text = String(reflecting: error)
            XCTAssertTrue(text.contains("sqlState: 23514") || text.contains("sqlState: 23503"), message)
        }
    }

    func testCancelledNeedsAReasonAndOnlyCancelledMayHaveOne() async throws {
        let open = try await place(), cancelled = try await place(.init(status: "Cancelled", reason: "fake_spam"))
        try await rejected("UPDATE customer_order SET status = 'Cancelled' WHERE order_code = \(bind: open)", "no reason")
        try await rejected("UPDATE customer_order SET cancel_reason = 'fake_spam' WHERE order_code = \(bind: open)", "reason on open")
        try await rejected("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'day_full' WHERE order_code = \(bind: open)", "removed value")
        try await rejected("UPDATE customer_order SET status = 'Cancelled', cancel_reason = '' WHERE order_code = \(bind: open)", "empty")
        let still = try await status(of: open)
        XCTAssertEqual(still, "Received")
        try await rejected("UPDATE customer_order SET cancel_reason = 'customer_asked' WHERE order_code = \(bind: cancelled)", "reason cannot change")
        try await rejected("UPDATE customer_order SET cancel_reason = NULL WHERE order_code = \(bind: cancelled)", "reason cannot be cleared")
    }

    func testTheEventKeepsTheReasonAndTheActorEvenWhenSetBySql() async throws {
        let orderCode = try await place(.init(date: day(5)))
        let account = try await addAccount(.staff, "Nhan Vien A")
        let (shop, actor) = (shopID, account.id)
        try await app.db.transaction { handle in
            let sql = try XCTUnwrap(handle as? any SQLDatabase)
            try await sql.raw("SELECT set_config('app.actor_type', 'staff', true)").run()
            try await sql.raw("SELECT set_config('app.actor_id', \(bind: actor.uuidString), true)").run()
            try await sql.raw("SELECT set_config('app.actor_name', 'Nhan Vien A', true)").run()
            try await sql.raw("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'cannot_deliver' WHERE order_code = \(bind: orderCode) AND shop_id = \(bind: shop)").run()
        }
        let recorded = try await count("""
            SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id
            WHERE o.order_code = \(bind: orderCode) AND e.reason = 'cannot_deliver' AND e.actor_name = 'Nhan Vien A' AND e.actor_id = \(bind: account.id)
            """)
        XCTAssertEqual(recorded, 1)
        try await rejected("INSERT INTO order_event (order_id, event_type, to_status, actor_type, reason) SELECT id, 'status_changed', 'Processing', 'staff', 'fake_spam' FROM customer_order WHERE order_code = \(bind: orderCode)", "reason on non-cancel")
        try await rejected("INSERT INTO order_event (order_id, event_type, to_status, actor_type, actor_id) SELECT id, 'status_changed', 'Processing', 'staff', gen_random_uuid() FROM customer_order WHERE order_code = \(bind: orderCode)", "unknown actor")
        try await rejected("UPDATE order_event SET actor_name = 'Someone Else'", "append only")
    }

    func testDirectSqlCannotMakeAnInvalidMove() async throws {
        let done = try await place(.init(status: "Finished"))
        try await rejected("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'fake_spam' WHERE order_code = \(bind: done)", "from final state")
        try await rejected("UPDATE customer_order SET status = 'Finished' WHERE order_code = \(bind: try await place())", "New to Completed")
    }

    func testSearchFoldIgnoresCaseAndAccentsIncludingDecomposedForms() async throws {
        let row = try await sql.raw("SELECT search_fold('Trần Thị Bé ĐỖ') AS a, search_fold(U&'Tra\\0302\\0300n') AS b").first()
        XCTAssertEqual(try row?.decode(column: "a", as: String.self), "tran thi be do")
        XCTAssertEqual(try row?.decode(column: "b", as: String.self), "tran")
    }

    // Plan choice depends on statistics; OrderListPlanTests covers it with seeded data.
    func testTheOpenListAndWindowIndexesExistAndTheOldOneIsGone() async throws {
        let present = try await count("SELECT count(*)::int AS n FROM pg_indexes WHERE indexname IN ('customer_order_open_list_idx', 'customer_order_shop_created_idx')")
        XCTAssertEqual(present, 2)
        let gone = try await count("SELECT count(*)::int AS n FROM pg_indexes WHERE indexname = 'customer_order_open_idx'")
        XCTAssertEqual(gone, 0)
    }
}
