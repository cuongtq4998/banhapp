import XCTVapor
import FluentSQL
@testable import App

/// Migration 0008: the record tables, the immutable rule and the capacity release.
final class OrderProcessTriggerTests: OrderProcessMigrationCase {
    private func orderID(_ code: String) -> String { "(SELECT id FROM customer_order WHERE order_code = 'BT-\(code)')" }

    private func finishedOrder(_ code: String) async throws {
        try await insertOrder(code, status: "Received")
        try await setStatus(code, "status = 'Processing'")
        try await setStatus(code, "status = 'DeliveryDateScheduled', expected_delivery_date = '2030-01-12'")
        try await setStatus(code, "status = 'DeliveryStarted', delivery_fee_final_vnd = 15000, delivery_fee_set_at = now()")
    }

    func testBothRecordTablesAreInsertOnly() async throws {
        try await applyTarget()
        try await finishedOrder("DAAAAA")
        let order = orderID("DAAAAA")
        try await run("INSERT INTO order_expected_date_change (order_id, old_date, new_date, changed_by_name) VALUES (\(order), NULL, '2030-01-12', 'Nhan Vien A')")
        try await run("INSERT INTO order_fee_correction (order_id, old_fee_vnd, new_fee_vnd, changed_by_name) VALUES (\(order), 15000, 18000, 'Nhan Vien A')")
        for table in ["order_expected_date_change", "order_fee_correction"] {
            try await refused("UPDATE \(table) SET changed_by_name = 'Someone Else'", "\(table) update")
            try await refused("DELETE FROM \(table)", "\(table) delete")
        }
        try await refused("INSERT INTO order_fee_correction (order_id, old_fee_vnd, new_fee_vnd, changed_by_name) VALUES (\(order), 15000, 15000, 'A')", "same fee")
        try await refused("INSERT INTO order_fee_correction (order_id, old_fee_vnd, new_fee_vnd, changed_by_name) VALUES (\(order), 15000, 10000001, 'A')", "fee above range")
        let kept = try await number("SELECT count(*)::int AS n FROM order_fee_correction")
        XCTAssertEqual(kept, 1)
    }

    func testRemovingAnAccountBlanksTheLinkButKeepsTheName() async throws {
        try await applyTarget()
        let account = UUID()
        try await run("INSERT INTO account (id, shop_id, role, email, display_name, is_active) VALUES ('\(account)', '\(shop)', 'staff', 'a@example.com', 'Nhan Vien A', true)")
        try await finishedOrder("DAAAAB")
        try await run("INSERT INTO order_expected_date_change (order_id, new_date, changed_by_account_id, changed_by_name) VALUES (\(orderID("DAAAAB")), '2030-01-12', '\(account)', 'Nhan Vien A')")
        try await run("DELETE FROM account WHERE id = '\(account)'")
        let row = try await rows("SELECT changed_by_account_id IS NULL AS gone, changed_by_name AS t FROM order_expected_date_change").first
        XCTAssertEqual(try row?.decode(column: "gone", as: Bool.self), true)
        XCTAssertEqual(try row?.decode(column: "t", as: String.self), "Nhan Vien A")
    }

    func testTheFeeCorrectsInDeliveryStartedAndFreezesOnceFinished() async throws {
        try await applyTarget()
        try await finishedOrder("EAAAAA")
        try await setStatus("EAAAAA", "delivery_fee_final_vnd = 18000, delivery_fee_set_at = now()")
        try await setStatus("EAAAAA", "status = 'Finished'")
        try await refused("UPDATE customer_order SET delivery_fee_final_vnd = 1 WHERE order_code = 'BT-EAAAAA'", "fee after Finished")
        try await refused("UPDATE customer_order SET expected_delivery_date = '2030-01-13' WHERE order_code = 'BT-EAAAAA'", "date after Finished")
        try await refused("UPDATE customer_order SET delivery_fee_vnd = 1, total_vnd = 100001 WHERE order_code = 'BT-EAAAAA'", "estimate is frozen")
        let fee = try await number("SELECT delivery_fee_final_vnd AS n FROM customer_order WHERE order_code = 'BT-EAAAAA'")
        XCTAssertEqual(fee, 18_000)
    }

    func testTheDateMovesInDeliveryDateScheduledAndFreezesWhenCancelledOrFinished() async throws {
        try await applyTarget()
        try await insertOrder("FAAAAA", status: "Received")
        try await setStatus("FAAAAA", "status = 'Processing'")
        try await setStatus("FAAAAA", "status = 'DeliveryDateScheduled', expected_delivery_date = '2030-01-12'")
        try await setStatus("FAAAAA", "expected_delivery_date = '2030-01-14'")
        try await insertOrder("FAAAAB", status: "Received")
        try await setStatus("FAAAAB", "status = 'Cancelled', cancel_reason = 'fake_spam'")
        try await refused("UPDATE customer_order SET expected_delivery_date = '2030-01-12' WHERE order_code = 'BT-FAAAAB'", "date on a cancelled order")
    }

    func testCapacityIsFreedOnlyWhenCancelled() async throws {
        try await applyTarget()
        try await run("INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES ('\(shop)', '2030-01-10', 6, 100)")
        for code in ["GAAAAA", "GAAAAB", "GAAAAC"] { try await insertOrder(code, status: "Received") }
        try await setStatus("GAAAAA", "status = 'Processing'")
        let afterProcessing = try await number("SELECT cakes_accepted AS n FROM day_load WHERE shop_id = '\(shop)'")
        XCTAssertEqual(afterProcessing, 6)
        try await setStatus("GAAAAA", "status = 'DeliveryDateScheduled', expected_delivery_date = '2030-01-12'")
        try await setStatus("GAAAAA", "status = 'DeliveryStarted', delivery_fee_final_vnd = 0, delivery_fee_set_at = now()")
        try await setStatus("GAAAAA", "status = 'Finished'")
        let afterFinished = try await number("SELECT cakes_accepted AS n FROM day_load WHERE shop_id = '\(shop)'")
        XCTAssertEqual(afterFinished, 6)
        try await setStatus("GAAAAB", "status = 'Cancelled', cancel_reason = 'customer_asked'")
        let afterReceivedCancel = try await number("SELECT cakes_accepted AS n FROM day_load WHERE shop_id = '\(shop)'")
        XCTAssertEqual(afterReceivedCancel, 4)
        try await setStatus("GAAAAC", "status = 'Processing'")
        try await setStatus("GAAAAC", "status = 'Cancelled', cancel_reason = 'cannot_deliver'")
        let afterProcessingCancel = try await number("SELECT cakes_accepted AS n FROM day_load WHERE shop_id = '\(shop)'")
        XCTAssertEqual(afterProcessingCancel, 2)
        let cancelEvents = try await number("SELECT count(*)::int AS n FROM order_event WHERE to_status = 'Cancelled' AND reason IS NOT NULL")
        XCTAssertEqual(cancelEvents, 2)
    }
}
