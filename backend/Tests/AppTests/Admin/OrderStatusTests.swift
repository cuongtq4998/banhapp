import XCTVapor
@testable import App

/// TC-B75 to TC-B81 (FR-16 to FR-19, ADR-0028): confirm, complete, cancel, the
/// record, stale views, and the repeat rule.
final class OrderStatusTests: AdminOrderTestCase {
    func testConfirmMovesTheOrderAndRecordsWhoDidIt() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 4))
        let staff = try await phone(.staff, "Nhan Vien A")
        let reply = try await change(staff, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(reply.status, .ok)
        XCTAssertNil(reply.headers.first(name: "Idempotent-Replay"))
        XCTAssertEqual(reply.string("status"), "Confirmed")
        XCTAssertEqual(reply.json["allowed_actions"] as? [String], ["complete", "cancel"])
        let line = try XCTUnwrap(reply.json["last_change"] as? [String: Any])
        XCTAssertEqual(line["actor_name"] as? String, "Nhan Vien A")
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Confirmed")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
        let named = try await count("""
            SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id
            WHERE o.order_code = \(bind: orderCode) AND e.from_status = 'New' AND e.to_status = 'Confirmed'
              AND e.actor_type = 'staff' AND e.actor_name = 'Nhan Vien A' AND e.actor_id IS NOT NULL AND e.reason IS NULL
            """)
        XCTAssertEqual(named, 1)
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 4, "confirming changes no capacity")
    }

    func testOwnerMayActToo() async throws {
        let orderCode = try await place()
        let owner = try await phone(.owner, "Chu Mau")
        let reply = try await change(owner, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(reply.status, .ok)
        let kind = try await count("""
            SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id
            WHERE o.order_code = \(bind: orderCode) AND e.actor_type = 'owner' AND e.actor_name = 'Chu Mau'
            """)
        XCTAssertEqual(kind, 1)
    }

    func testCompleteNeedsAConfirmedOrderAndARepeatIsNotAnError() async throws {
        let confirmed = try await place(.init(status: "Confirmed", date: day(5)))
        let fresh = try await place(.init(status: "New"))
        let staff = try await phone(.staff)
        let done = try await change(staff, confirmed, move("Confirmed", "Completed"))
        XCTAssertEqual(done.status, .ok)
        XCTAssertEqual(done.string("status"), "Completed")
        let refused = try await change(staff, fresh, move("New", "Completed"))
        XCTAssertEqual(refused.status, .unprocessableEntity)
        XCTAssertEqual(refused.errorCode, "STATUS_TRANSITION_INVALID")
        let details = (refused.json["error"] as? [String: Any])?["details"] as? [String: Any]
        XCTAssertEqual(details?["status"] as? String, "New")
        let still = try await status(of: fresh)
        XCTAssertEqual(still, "New")
        let again = try await change(staff, confirmed, move("Confirmed", "Completed"))
        XCTAssertEqual(again.status, .ok)
        XCTAssertEqual(again.headers.first(name: "Idempotent-Replay"), "true")
        let eventCount = try await events(of: confirmed)
        XCTAssertEqual(eventCount, 1)
    }

    func testTwoStaffOnTheSameViewFirstWinsAndTheSecondSeesTheCurrentOrder() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 3))
        let a = try await phone(.staff, "Nhan Vien A"), b = try await phone(.staff, "Nhan Vien B")
        let first = try await change(a, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(first.status, .ok)
        let second = try await change(b, orderCode, move("New", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(second.status, .conflict)
        XCTAssertEqual(second.errorCode, "ORDER_STATE_CHANGED")
        let current = ((second.json["error"] as? [String: Any])?["details"] as? [String: Any])?["order"] as? [String: Any]
        XCTAssertEqual(current?["status"] as? String, "Confirmed")
        XCTAssertEqual(current?["order_code"] as? String, orderCode)
        XCTAssertEqual((current?["last_change"] as? [String: Any])?["actor_name"] as? String, "Nhan Vien A")
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Confirmed")
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 3)
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
    }

    func testAnotherPersonReachingTheSameTargetIsAlsoRefused() async throws {
        let orderCode = try await place()
        let a = try await phone(.staff, "Nhan Vien A"), b = try await phone(.staff, "Nhan Vien B")
        let first = try await change(a, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(first.status, .ok)
        let second = try await change(b, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(second.status, .conflict)
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1, "history is never misattributed")
    }

    func testCancelTwiceWithDifferentReasonsKeepsTheFirstAndReturnsCakesOnce() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 4))
        try await addLoad(day(5), 10)
        let staff = try await phone(.staff)
        let first = try await change(staff, orderCode, move("New", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(first.status, .ok)
        let second = try await change(staff, orderCode, move("New", "Cancelled", reason: "fake_spam"))
        XCTAssertEqual(second.status, .ok)
        XCTAssertEqual(second.headers.first(name: "Idempotent-Replay"), "true")
        XCTAssertEqual(second.string("cancel_reason"), "customer_asked")
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 10)
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
    }

    func testAnOldOpenOrderCanBeClosedAndThenLeavesTheWindow() async throws {
        let placed = clock.now().addingTimeInterval(-100 * 86_400)
        let orderCode = try await place(.init(status: "New", date: day(-75), placed: placed))
        let staff = try await phone(.staff)
        let confirm = try await change(staff, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(confirm.status, .ok)
        let complete = try await change(staff, orderCode, move("Confirmed", "Completed"))
        XCTAssertEqual(complete.status, .ok, "the reply is built before the order leaves the window")
        XCTAssertEqual(complete.string("status"), "Completed")
        let listed = try await listCodes(staff, "status=all")
        XCTAssertEqual(listed, [])
        let opened = try await detail(staff, orderCode)
        XCTAssertEqual(opened.status, .notFound)
        let repeated = try await change(staff, orderCode, move("Confirmed", "Completed"))
        XCTAssertEqual(repeated.status, .notFound)
    }

    func testAnOldCancelledOrderWithNoCapacityRowCancelsWithoutError() async throws {
        let orderCode = try await place(.init(status: "New", date: day(-75), placed: clock.now().addingTimeInterval(-100 * 86_400)))
        try await run("DELETE FROM day_load WHERE shop_id = \(bind: shopID)")
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("New", "Cancelled", reason: "cannot_deliver"))
        XCTAssertEqual(reply.status, .ok)
        let rows = try await count("SELECT count(*)::int AS n FROM day_load WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(rows, 0)
    }

    func testUnknownHiddenAndForeignOrdersAnswer404() async throws {
        let old = try await place(.init(status: "Completed", placed: clock.now().addingTimeInterval(-91 * 86_400)))
        let demo = try await place(.init(demo: true))
        let staff = try await phone(.staff)
        for orderCode in [old, demo, code(99_999_999), "bt-aaaaaa"] {
            let reply = try await change(staff, orderCode, move("New", "Confirmed"))
            XCTAssertEqual(reply.errorCode, "ORDER_NOT_FOUND", orderCode)
        }
        let unsigned = try await send(.POST, "v1/admin/orders/\(old)/status")
        XCTAssertEqual(unsigned.status, .unauthorized)
    }
}
