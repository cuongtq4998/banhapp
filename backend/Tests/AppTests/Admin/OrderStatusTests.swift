import XCTVapor
@testable import App

/// The record, stale views and the repeat rules (FR-16 to FR-19, ADR-0028,
/// order-process.md 4.1).
final class OrderStatusTests: AdminOrderTestCase {
    private func replayed(_ reply: Reply) -> Bool { reply.headers.first(name: "Idempotent-Replay") == "true" }

    func testProcessMovesTheOrderAndRecordsWhoDidItWithTheNewWords() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 4))
        let staff = try await phone(.staff, "Nhan Vien A")
        let reply = try await change(staff, orderCode, move("Received", "Processing"))
        XCTAssertEqual(reply.status, .ok)
        XCTAssertFalse(replayed(reply))
        XCTAssertEqual(reply.string("status"), "Processing")
        XCTAssertEqual(reply.json["allowed_actions"] as? [String], ["cancel", "schedule_delivery"])
        XCTAssertEqual((reply.json["last_change"] as? [String: Any])?["actor_name"] as? String, "Nhan Vien A")
        let named = try await count("""
            SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id
            WHERE o.order_code = \(bind: orderCode) AND e.from_status = 'Received' AND e.to_status = 'Processing'
              AND e.actor_type = 'staff' AND e.actor_name = 'Nhan Vien A' AND e.actor_id IS NOT NULL
            """)
        XCTAssertEqual(named, 1)
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 4, "processing changes no capacity")
    }

    func testTheWholeHappyPathByOwnerAndStaffFreesNothing() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 3))
        let owner = try await phone(.owner, "Chu Tiem"), staff = try await phone(.staff)
        let steps = [
            (owner, move("Received", "Processing")), (staff, move("Processing", "DeliveryDateScheduled", date: day(2))),
            (owner, move("DeliveryDateScheduled", "DeliveryStarted", fee: 0)), (staff, move("DeliveryStarted", "Finished"))
        ]
        for (phone, json) in steps {
            let reply = try await change(phone, orderCode, json)
            XCTAssertEqual(reply.status, .ok, json)
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Finished")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 4)
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 3, "finishing frees nothing")
    }

    func testFinishNeedsDeliveryStartedAndARepeatIsNotAnError() async throws {
        let orderCode = try await place(.init(status: "DeliveryStarted", expectedDate: day(1), finalFee: 20_000))
        let staff = try await phone(.staff)
        let early = try await change(staff, orderCode, move("DeliveryDateScheduled", "Finished"))
        XCTAssertEqual(early.errorCode, "STATUS_TRANSITION_INVALID")
        let first = try await change(staff, orderCode, move("DeliveryStarted", "Finished"))
        XCTAssertEqual(first.status, .ok)
        let again = try await change(staff, orderCode, move("DeliveryStarted", "Finished"))
        XCTAssertEqual(again.status, .ok)
        XCTAssertTrue(replayed(again))
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
    }

    func testStartAgainWithTheSameFeeReplaysAndADifferentFeeIs409WithNoWrite() async throws {
        let orderCode = try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(1)))
        let staff = try await phone(.staff)
        let first = try await change(staff, orderCode, move("DeliveryDateScheduled", "DeliveryStarted", fee: 25_000))
        XCTAssertEqual(first.status, .ok)
        let same = try await change(staff, orderCode, move("DeliveryDateScheduled", "DeliveryStarted", fee: 25_000))
        XCTAssertEqual(same.status, .ok)
        XCTAssertTrue(replayed(same))
        let other = try await change(staff, orderCode, move("DeliveryDateScheduled", "DeliveryStarted", fee: 30_000))
        XCTAssertEqual(other.errorCode, "ORDER_STATE_CHANGED")
        let order = (other.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["order"] as? [String: Any] }
        XCTAssertEqual(order?["delivery_fee_final_vnd"] as? Int, 25_000)
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
    }

    func testScheduleAgainWithTheSameDateReplaysAndAnotherDateIs409() async throws {
        let orderCode = try await place(.init(status: "Processing"))
        let staff = try await phone(.staff)
        let first = try await change(staff, orderCode, move("Processing", "DeliveryDateScheduled", date: day(2)))
        XCTAssertEqual(first.status, .ok)
        let same = try await change(staff, orderCode, move("Processing", "DeliveryDateScheduled", date: day(2)))
        XCTAssertTrue(replayed(same))
        let other = try await change(staff, orderCode, move("Processing", "DeliveryDateScheduled", date: day(3)))
        XCTAssertEqual(other.errorCode, "ORDER_STATE_CHANGED")
        let rows = try await count("SELECT count(*)::int AS n FROM order_expected_date_change c JOIN customer_order o ON o.id = c.order_id WHERE o.order_code = \(bind: orderCode)")
        XCTAssertEqual(rows, 1)
    }

    func testAFeeOrDateThroughTheStatusRouteAtTheSameStatusIsRefusedWithNoWrite() async throws {
        let staff = try await phone(.staff)
        let started = try await place(.init(status: "DeliveryStarted", expectedDate: day(1), finalFee: 20_000))
        let fee = try await change(staff, started, move("DeliveryStarted", "DeliveryStarted", fee: 30_000))
        XCTAssertEqual(fee.errorCode, "STATUS_TRANSITION_INVALID")
        let scheduled = try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(1)))
        let date = try await change(staff, scheduled, move("DeliveryDateScheduled", "DeliveryDateScheduled", date: day(2)))
        XCTAssertEqual(date.errorCode, "STATUS_TRANSITION_INVALID")
        let stored = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code IN (\(bind: started), \(bind: scheduled)) AND (delivery_fee_final_vnd IS NOT DISTINCT FROM 20000) AND expected_delivery_date = \(bind: day(1))::date")
        XCTAssertEqual(stored, 1, "fee and date unchanged (only the started order holds a fee)")
    }

    func testTwoStaffOnTheSameViewFirstWinsAndTheSecondSeesTheCurrentOrder() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 4))
        let a = try await phone(.staff, "Nhan Vien A"), b = try await phone(.staff, "Nhan Vien B")
        let first = try await change(a, orderCode, move("Received", "Processing"))
        XCTAssertEqual(first.status, .ok)
        let second = try await change(b, orderCode, move("Received", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(second.status, .conflict)
        XCTAssertEqual(second.errorCode, "ORDER_STATE_CHANGED")
        let order = (second.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["order"] as? [String: Any] }
        XCTAssertEqual(order?["status"] as? String, "Processing")
        XCTAssertEqual((order?["last_change"] as? [String: Any])?["actor_name"] as? String, "Nhan Vien A")
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 4)
    }

    func testAnotherPersonReachingTheSameTargetIsAlsoRefused() async throws {
        let orderCode = try await place()
        let a = try await phone(.staff, "Nhan Vien A"), b = try await phone(.staff, "Nhan Vien B")
        let first = try await change(a, orderCode, move("Received", "Processing"))
        XCTAssertEqual(first.status, .ok)
        let second = try await change(b, orderCode, move("Received", "Processing"))
        XCTAssertEqual(second.errorCode, "ORDER_STATE_CHANGED")
    }

    func testCancelTwiceWithDifferentReasonsKeepsTheFirstAndReturnsCakesOnce() async throws {
        let orderCode = try await place(.init(status: "Processing", date: day(5), cakes: 4))
        try await addLoad(day(5), 6)
        let staff = try await phone(.staff)
        let first = try await change(staff, orderCode, move("Processing", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(first.status, .ok)
        let again = try await change(staff, orderCode, move("Processing", "Cancelled", reason: "fake_spam"))
        XCTAssertTrue(replayed(again))
        XCTAssertEqual(again.string("cancel_reason"), "customer_asked")
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 6)
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
    }

    func testAnOldOpenOrderCanBeClosedAndThenLeavesTheWindow() async throws {
        let placed = clock.now().addingTimeInterval(-100 * 86_400)
        let orderCode = try await place(.init(status: "DeliveryStarted", date: day(-75), placed: placed, expectedDate: day(0), finalFee: 10_000))
        let staff = try await phone(.staff)
        let finish = try await change(staff, orderCode, move("DeliveryStarted", "Finished"))
        XCTAssertEqual(finish.status, .ok, "the reply is built before the order leaves the window")
        XCTAssertEqual(finish.string("status"), "Finished")
        let opened = try await detail(staff, orderCode)
        XCTAssertEqual(opened.status, .notFound)
        let repeated = try await change(staff, orderCode, move("DeliveryStarted", "Finished"))
        XCTAssertEqual(repeated.status, .ok, "FR-19: the repeat of the closing change is a replay")
        XCTAssertTrue(replayed(repeated))
        let other = try await change(staff, orderCode, move("Received", "Cancelled", reason: "cannot_deliver"))
        XCTAssertEqual(other.errorCode, "ORDER_NOT_FOUND")
        let bad = try await change(staff, orderCode, #"{"nonsense":true}"#)
        XCTAssertEqual(bad.errorCode, "ORDER_NOT_FOUND")
    }

    func testAnOldCancelledOrderWithNoCapacityRowCancelsWithoutError() async throws {
        let orderCode = try await place(.init(date: day(-75), placed: clock.now().addingTimeInterval(-100 * 86_400)))
        try await run("DELETE FROM day_load WHERE shop_id = \(bind: shopID)")
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("Received", "Cancelled", reason: "cannot_deliver"))
        XCTAssertEqual(reply.status, .ok)
    }

    func testUnknownHiddenAndForeignOrdersAnswer404() async throws {
        let old = try await place(.init(status: "Finished", placed: clock.now().addingTimeInterval(-91 * 86_400), expectedDate: day(-80), finalFee: 0))
        let demo = try await place(.init(demo: true))
        let staff = try await phone(.staff)
        for orderCode in [old, demo, code(99_999_999), "bt-aaaaaa"] {
            let reply = try await change(staff, orderCode, move("Received", "Processing"))
            XCTAssertEqual(reply.errorCode, "ORDER_NOT_FOUND", orderCode)
        }
        let unsigned = try await send(.POST, "v1/admin/orders/\(old)/status")
        XCTAssertEqual(unsigned.status, .unauthorized)
    }
}
