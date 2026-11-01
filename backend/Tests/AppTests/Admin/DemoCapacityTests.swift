import XCTVapor
import FluentSQL
@testable import App

/// Defect D-2 (migration 0005): cancelling a demo order must not return cakes
/// to `day_load`, because demo rows never took any (ADR-0027).
final class DemoCapacityTests: AdminOrderTestCase {
    private func cakes(_ date: String) async throws -> Int {
        try await count("SELECT cakes_accepted::int AS n FROM day_load WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: date)::date")
    }

    func testCancellingADemoOrderLeavesTheDayLoadAlone() async throws {
        let date = day(4)
        let demo = try await place(.init(date: date, cakes: 3, demo: true))
        let before = try await cakes(date)
        XCTAssertEqual(before, 3, "the fixture counts the demo cakes, as the pre-fix trigger would subtract them")
        try await run("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'fake_spam' WHERE order_code = \(bind: demo)")
        let load = try await cakes(date)
        XCTAssertEqual(load, before)
        let events = try await count("SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id WHERE o.order_code = \(bind: demo) AND e.to_status = 'Cancelled'")
        XCTAssertEqual(events, 1, "the event is still written")
    }

    func testCancellingARealOrderStillGivesTheCakesBack() async throws {
        let date = day(4)
        let real = try await place(.init(date: date, cakes: 3))
        let before = try await cakes(date)
        try await run("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'fake_spam' WHERE order_code = \(bind: real)")
        let after = try await cakes(date)
        XCTAssertEqual([before, after], [3, 0])
    }
}
