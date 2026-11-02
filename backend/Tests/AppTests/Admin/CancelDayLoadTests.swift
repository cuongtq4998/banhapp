import XCTVapor
@testable import App

/// D-3 (ADR-0030): a cancel that would take `day_load` below zero (a counter that is
/// smaller than the order, reachable only by manual SQL) is a handled error, not a
/// crash and not a silent floor: the order stays as it was and the counter is untouched.
final class CancelDayLoadTests: AdminOrderTestCase {
    func testCancelAgainstASmallerDayLoadIsRefusedAndChangesNothing() async throws {
        let date = day(6)
        let orderCode = try await place(.init(date: date, cakes: 4))
        try await run("UPDATE day_load SET cakes_accepted = 1 WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: date)::date")
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("Received", "Cancelled", reason: "cannot_deliver"))
        XCTAssertEqual(reply.status, .internalServerError)
        XCTAssertEqual(reply.errorCode, "INTERNAL_ERROR")
        XCTAssertEqual((reply.json["error"] as? [String: Any])?["details"] as? [String: String], ["reason": "DAY_LOAD_INCONSISTENT"])
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Received")
        let load = try await loaded(date)
        XCTAssertEqual(load, 1, "no floor: the wrong counter stays visible")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 0)
        // The same order is still usable.
        let processed = try await change(staff, orderCode, move("Received", "Processing"))
        XCTAssertEqual(processed.status, .ok)
    }

    func testCancelWithoutADayLoadRowStillWorks() async throws {
        let orderCode = try await place(.init(date: day(7), cakes: 2))
        try await run("DELETE FROM day_load WHERE shop_id = \(bind: shopID)")
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("Received", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(reply.status, .ok)
    }
}

extension CancelDayLoadTests {
    func testCancelFromProcessingFreesTheDayLoadAndFinishingFreesNothing() async throws {
        let staff = try await phone(.staff)
        let cancelled = try await place(.init(status: "Processing", date: day(6), cakes: 3))
        let finished = try await place(.init(status: "DeliveryStarted", date: day(7), cakes: 2, expectedDate: day(1), finalFee: 5_000))
        let freed = try await change(staff, cancelled, move("Processing", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(freed.status, .ok)
        let load = try await loaded(day(6))
        XCTAssertEqual(load, 0)
        let done = try await change(staff, finished, move("DeliveryStarted", "Finished"))
        XCTAssertEqual(done.status, .ok)
        let kept = try await loaded(day(7))
        XCTAssertEqual(kept, 2)
    }
}
