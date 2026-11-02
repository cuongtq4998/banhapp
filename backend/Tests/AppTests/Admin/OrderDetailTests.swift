import XCTVapor
@testable import App

/// TC-B73, TC-B74 (FR-14): every detail field, stored prices, the one "last
/// changed by" line, allowed actions, and 404 for anything not visible.
final class OrderDetailTests: AdminOrderTestCase {
    func testDetailHasEveryFieldWithStoredValuesAndNoHistory() async throws {
        let orderCode = try await place(.init(date: "2031-05-04", cakes: 2))
        // The cake price changes later; the order keeps the price it was placed at.
        try await run("UPDATE product SET price_vnd = 99000, name = 'Renamed' WHERE id = \(bind: productID)")
        let staff = try await phone(.staff)
        let reply = try await detail(staff, orderCode)
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.headers.first(name: .cacheControl), "no-store")
        let body = reply.json
        XCTAssertEqual(Set(body.keys), [
            "order_code", "status", "customer_name", "delivery_date", "slot", "total_cakes", "total_vnd", "district_name", "created_at",
            "customer_phone", "customer_address", "note", "items", "items_subtotal_vnd", "delivery_fee_vnd", "cancel_reason",
            "allowed_actions", "last_change", "requested_delivery_date", "expected_delivery_date", "delivery_fee_estimate_vnd",
            "delivery_fee_final_vnd", "amount_to_collect_vnd", "expected_date_range", "date_changes", "fee_corrections", "list_date", "delivery_fee_entry"
        ])
        XCTAssertEqual(body["customer_phone"] as? String, "+84900000010")
        XCTAssertEqual(body["customer_address"] as? String, "1 Test Street")
        XCTAssertEqual(body["note"] as? String, "Ít đường")
        XCTAssertEqual(body["items_subtotal_vnd"] as? Int, 100_000)
        XCTAssertEqual(body["delivery_fee_vnd"] as? Int, 20_000)
        XCTAssertEqual(body["total_vnd"] as? Int, 120_000)
        XCTAssertTrue(body["cancel_reason"] is NSNull)
        let items = try XCTUnwrap(body["items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0]["product_name"] as? String, "Banh Mau")
        XCTAssertEqual(items[0]["unit_price_vnd"] as? Int, 50_000)
        XCTAssertEqual(items[0]["quantity"] as? Int, 2)
        XCTAssertEqual(items[0]["line_total_vnd"] as? Int, 100_000)
        XCTAssertNil(body["history"])
    }

    func testLastChangeNamesNobodyUntilSomeoneChangesTheOrder() async throws {
        let orderCode = try await place()
        let staff = try await phone(.staff, "Nhan Vien A")
        let fresh = try await detail(staff, orderCode)
        let none = try XCTUnwrap(fresh.json["last_change"] as? [String: Any])
        XCTAssertTrue(none["actor_name"] is NSNull)
        XCTAssertNotNil(none["at"] as? String)
        let eventTime = clock.now()
        try await run("INSERT INTO order_event (order_id, event_type, to_status, actor_type, actor_name, created_at) SELECT id, 'status_changed', 'Processing', 'staff', 'Nhan Vien A', \(timestamp(eventTime)) FROM customer_order WHERE order_code = \(bind: orderCode)")
        let after = try await detail(staff, orderCode)
        let line = try XCTUnwrap(after.json["last_change"] as? [String: Any])
        XCTAssertEqual(line["actor_name"] as? String, "Nhan Vien A")
        XCTAssertEqual((line["at"] as? String)?.count, 20)
    }

    func testAllowedActionsFollowTheStatusAndFinalStatesHaveNone() async throws {
        let staff = try await phone(.staff)
        let expected: [(String, [String])] = [
            ("Received", ["cancel", "process"]), ("Processing", ["cancel", "schedule_delivery"]),
            ("DeliveryDateScheduled", ["change_date", "start_delivery"]), ("DeliveryStarted", ["correct_fee", "finish"]),
            ("Finished", []), ("Cancelled", [])
        ]
        for (status, actions) in expected {
            let dated = ["DeliveryDateScheduled", "DeliveryStarted", "Finished"].contains(status)
            let fee = ["DeliveryStarted", "Finished"].contains(status) ? 20_000 : nil
            let orderCode = try await place(.init(status: status, reason: status == "Cancelled" ? "fake_spam" : nil, expectedDate: dated ? day(1) : nil, finalFee: fee))
            let reply = try await detail(staff, orderCode)
            XCTAssertEqual(reply.json["allowed_actions"] as? [String], actions, status)
            if status == "Cancelled" { XCTAssertEqual(reply.string("cancel_reason"), "fake_spam") }
        }
    }

    func testMalformedUnknownAndInjectedCodesAnswer404WithoutInternals() async throws {
        let staff = try await phone(.staff)
        for orderCode in ["BT-ZZZZZZ", "bt-aaaaaa", "BT-AAAAA", "BT-AAAAAAA", "BT-0AAAAA", "x", "'%3B%20DROP%20TABLE%20customer_order%3B--"] {
            let reply = try await authed(.GET, "v1/admin/orders/\(orderCode)", staff.access)
            XCTAssertEqual(reply.status, .notFound, orderCode)
            XCTAssertEqual(reply.errorCode, "ORDER_NOT_FOUND", orderCode)
        }
    }

    func testDetailNeedsASession() async throws {
        let orderCode = try await place()
        let reply = try await send(.GET, "v1/admin/orders/\(orderCode)")
        XCTAssertEqual(reply.status, .unauthorized)
    }
}
