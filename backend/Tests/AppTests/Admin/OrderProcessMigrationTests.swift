import XCTVapor
import FluentSQL
@testable import App

/// Migration 0008 (data-model/06): the remap of statuses and the new structure.
final class OrderProcessMigrationTests: OrderProcessMigrationCase {
    /// One order per old status; the events are written by the 0001 triggers.
    private func seedOldOrders() async throws {
        try await insertOrder("AAAAAA", status: "New")
        try await insertOrder("AAAAAB", status: "New")
        try await setStatus("AAAAAB", "status = 'Confirmed'")
        try await insertOrder("AAAAAC", status: "New")
        try await setStatus("AAAAAC", "status = 'Confirmed'")
        try await setStatus("AAAAAC", "status = 'Completed'")
        try await insertOrder("AAAAAD", status: "New")
        try await setStatus("AAAAAD", "status = 'Cancelled', cancel_reason = 'fake_spam'")
    }

    private func eventSnapshot() async throws -> [String] {
        try await rows("SELECT id, order_id, event_type, coalesce(from_status, '-') AS f, to_status, created_at FROM order_event ORDER BY id")
            .map { try $0.decode(column: "id", as: Int.self).description + "|" + $0.decode(column: "f", as: String.self) + ">" + $0.decode(column: "to_status", as: String.self) }
    }

    func testStatusesAreMappedAndOldEventsStayAsTheyAre() async throws {
        try await seedOldOrders()
        let before = try await eventSnapshot()
        XCTAssertEqual(before.count, 0 + 1 + 2 + 1)
        try await applyTarget()
        let mapped = try await [status("AAAAAA"), status("AAAAAB"), status("AAAAAC"), status("AAAAAD")]
        XCTAssertEqual(mapped, ["Received", "Processing", "Finished", "Cancelled"])
        let after = try await eventSnapshot()
        XCTAssertEqual(after, before, "order_event rows are not rewritten and none is added")
        let legacy = try await number("SELECT count(*)::int AS n FROM order_event WHERE to_status IN ('New', 'Confirmed', 'Completed')")
        XCTAssertGreaterThan(legacy, 0)
    }

    func testFinishedRowsGetTheEstimateAsFinalFeeAndOthersNothing() async throws {
        try await seedOldOrders()
        let changedAt = try await text("SELECT status_changed_at::text AS t FROM customer_order WHERE order_code = 'BT-AAAAAC'")
        try await applyTarget()
        let fee = try await number("SELECT delivery_fee_final_vnd AS n FROM customer_order WHERE order_code = 'BT-AAAAAC'")
        XCTAssertEqual(fee, 20_000)
        let setAt = try await text("SELECT delivery_fee_set_at::text AS t FROM customer_order WHERE order_code = 'BT-AAAAAC'")
        XCTAssertEqual(setAt, changedAt)
        let estimate = try await number("SELECT total_vnd AS n FROM customer_order WHERE order_code = 'BT-AAAAAC'")
        XCTAssertEqual(estimate, 120_000, "the stored estimate is frozen")
        let others = try await number("SELECT count(*)::int AS n FROM customer_order WHERE status <> 'Finished' AND (delivery_fee_final_vnd IS NOT NULL OR delivery_fee_set_at IS NOT NULL OR expected_delivery_date IS NOT NULL)")
        XCTAssertEqual(others, 0)
    }

    func testNoOrderRowIsLostByTheRemap() async throws {
        try await seedOldOrders()
        let total = try await number("SELECT count(*)::int AS n FROM customer_order")
        try await applyTarget()
        let after = try await number("SELECT count(*)::int AS n FROM customer_order")
        XCTAssertEqual(after, total)
    }

    func testTheSixValueCheckAndTheNewColumnRules() async throws {
        try await applyTarget()
        try await insertOrder("BAAAAA", status: "Received")
        try await refused("UPDATE customer_order SET status = 'New'", "old word")
        try await refused("UPDATE customer_order SET status = 'Shipped'", "unknown word")
        try await refused("UPDATE customer_order SET delivery_fee_final_vnd = 1000", "fee while Received")
        try await setStatus("BAAAAA", "status = 'Processing'")
        try await refused("UPDATE customer_order SET status = 'DeliveryDateScheduled'", "date is required")
        try await setStatus("BAAAAA", "status = 'DeliveryDateScheduled', expected_delivery_date = '2030-01-12'")
        try await refused("UPDATE customer_order SET status = 'DeliveryStarted', delivery_fee_final_vnd = 10000001, delivery_fee_set_at = now()", "fee above range")
        try await refused("UPDATE customer_order SET status = 'DeliveryStarted', delivery_fee_final_vnd = -1, delivery_fee_set_at = now()", "negative fee")
        try await setStatus("BAAAAA", "status = 'DeliveryStarted', delivery_fee_final_vnd = 0, delivery_fee_set_at = now()")
        let free = try await number("SELECT delivery_fee_final_vnd AS n FROM customer_order WHERE order_code = 'BT-BAAAAA'")
        XCTAssertEqual(free, 0, "a free delivery is a valid fee")
        try await refused("UPDATE customer_order SET expected_delivery_date = NULL", "date cleared while started")
    }

    func testThePairsOfTheNewGuardAreTheOnlyMoves() async throws {
        try await applyTarget()
        try await insertOrder("CAAAAA", status: "Received")
        try await refused("UPDATE customer_order SET status = 'Finished'", "Received to Finished")
        try await setStatus("CAAAAA", "status = 'Processing'")
        try await refused("UPDATE customer_order SET status = 'Received'", "going back")
        try await setStatus("CAAAAA", "status = 'DeliveryDateScheduled', expected_delivery_date = '2030-01-12'")
        try await refused("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'fake_spam'", "cancel after the date is set")
        let events = try await number("SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id WHERE o.order_code = 'BT-CAAAAA' AND e.to_status IN ('Processing', 'DeliveryDateScheduled')")
        XCTAssertEqual(events, 2, "each move writes its event with the new words")
    }

    func testTheOpenListIndexCoversTheFourOpenStatesOnly() async throws {
        try await applyTarget()
        let definition = try await text("SELECT indexdef AS t FROM pg_indexes WHERE indexname = 'customer_order_open_list_idx'")
        for word in ["Received", "Processing", "DeliveryDateScheduled", "DeliveryStarted", "COALESCE"] {
            XCTAssertTrue(definition.contains(word), definition)
        }
        XCTAssertFalse(definition.contains("Finished") || definition.contains("Cancelled"), definition)
        let stale = try await number("SELECT count(*)::int AS n FROM pg_indexes WHERE indexname = 'customer_order_open_idx'")
        XCTAssertEqual(stale, 0)
    }
}
