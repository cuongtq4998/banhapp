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
        let reply = try await change(staff, orderCode, move("New", "Cancelled", reason: "cannot_deliver"))
        XCTAssertEqual(reply.status, .internalServerError)
        XCTAssertEqual(reply.errorCode, "INTERNAL_ERROR")
        XCTAssertEqual((reply.json["error"] as? [String: Any])?["details"] as? [String: String], ["reason": "DAY_LOAD_INCONSISTENT"])
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "New")
        let load = try await loaded(date)
        XCTAssertEqual(load, 1, "no floor: the wrong counter stays visible")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 0)
        // The same order is still usable.
        let confirmed = try await change(staff, orderCode, move("New", "Confirmed"))
        XCTAssertEqual(confirmed.status, .ok)
    }

    func testCancelWithoutADayLoadRowStillWorks() async throws {
        let orderCode = try await place(.init(status: "New", date: day(7), cakes: 2))
        try await run("DELETE FROM day_load WHERE shop_id = \(bind: shopID)")
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("New", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(reply.status, .ok)
    }
}
