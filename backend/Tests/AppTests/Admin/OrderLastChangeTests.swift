import XCTVapor
@testable import App

/// The last change line of the detail: latest of status, date and fee records.
final class OrderLastChangeTests: OrderRecordTestCase {
    func testEachKindIsReportedWithItsActor() async throws {
        let staff = try await phone(.staff), at = clock.now()
        let byStatus = try await started(), byDate = try await started(), byFee = try await started()
        try await addEvent(byStatus, to: "DeliveryStarted", actor: "Ai Status", at: at)
        try await addDateChange(byDate, name: "Ai Date", at: at)
        try await addFeeChange(byFee, name: "Ai Fee", at: at)
        for (orderCode, kind, name) in [(byStatus, "status", "Ai Status"), (byDate, "date", "Ai Date"), (byFee, "fee", "Ai Fee")] {
            let line = try await lastChange(staff, orderCode)
            XCTAssertEqual(line["kind"] as? String, kind)
            XCTAssertEqual(line["actor_name"] as? String, name)
        }
    }

    func testTheLatestRecordWinsWhateverItsKind() async throws {
        let staff = try await phone(.staff), now = clock.now()
        let orderCode = try await started()
        try await addDateChange(orderCode, name: "Ai Date", at: now.addingTimeInterval(-300))
        try await addEvent(orderCode, to: "DeliveryStarted", actor: "Ai Status", at: now.addingTimeInterval(-200))
        try await addFeeChange(orderCode, name: "Ai Fee", at: now.addingTimeInterval(-100))
        let line = try await lastChange(staff, orderCode)
        XCTAssertEqual(line["kind"] as? String, "fee")
        try await addEvent(orderCode, to: "Finished", actor: "Ai Later", at: now.addingTimeInterval(-50))
        let later = try await lastChange(staff, orderCode)
        XCTAssertEqual(later["actor_name"] as? String, "Ai Later")
    }

    func testTiesGoToStatusThenDateThenFee() async throws {
        let staff = try await phone(.staff), at = clock.now().addingTimeInterval(-60)
        let all = try await started(), dateFee = try await started(), twoFees = try await started()
        try await addFeeChange(all, name: "Ai Fee", at: at)
        try await addDateChange(all, name: "Ai Date", at: at)
        try await addEvent(all, to: "DeliveryStarted", actor: "Ai Status", at: at)
        try await addFeeChange(dateFee, name: "Ai Fee", at: at)
        try await addDateChange(dateFee, name: "Ai Date", at: at)
        let first = try await lastChange(staff, all), second = try await lastChange(staff, dateFee)
        XCTAssertEqual(first["kind"] as? String, "status")
        XCTAssertEqual(second["kind"] as? String, "date")
        try await addFeeChange(twoFees, name: "Ai Old", at: at)
        try await addFeeChange(twoFees, name: "Ai New", at: at)
        let third = try await lastChange(staff, twoFees)
        XCTAssertEqual(third["actor_name"] as? String, "Ai New", "larger id wins")
    }

    func testOnlyTheCustomersCreatedEventHasNoActorName() async throws {
        let staff = try await phone(.staff), orderCode = try await place()
        try await run("""
            INSERT INTO order_event (order_id, event_type, to_status, actor_type, created_at)
            SELECT id, 'created', 'Received', 'customer', \(timestamp(Date(timeIntervalSince1970: 0))) FROM customer_order WHERE order_code = \(bind: orderCode)
            """)
        let created = try await lastChange(staff, orderCode)
        XCTAssertTrue(created["actor_name"] is NSNull)
        let reply = try await change(staff, orderCode, move("Received", "Processing"))
        XCTAssertEqual(reply.status, .ok)
        let moved = try await lastChange(staff, orderCode)
        XCTAssertNotNil(moved["actor_name"] as? String)
        XCTAssertEqual(moved["kind"] as? String, "status")
        // The test clock runs ahead of the database clock, so the created event is dated to the epoch.
        let unnamed = try await count("SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id WHERE o.order_code = \(bind: orderCode) AND e.actor_name IS NULL AND e.actor_type <> 'customer'")
        XCTAssertEqual(unnamed, 0)
    }

    func testWithNoRecordTheLineFallsBackToCreationTime() async throws {
        let staff = try await phone(.staff), orderCode = try await place()
        let reply = try await detail(staff, orderCode)
        let line = try XCTUnwrap(reply.json["last_change"] as? [String: Any])
        XCTAssertTrue(line["actor_name"] is NSNull)
        XCTAssertEqual(line["kind"] as? String, "status")
        XCTAssertEqual(line["at"] as? String, reply.json["created_at"] as? String)
    }
}
