import XCTVapor
@testable import App

/// `delivery_fee_entry` and the fee history order of the detail.
final class OrderFeeEntryTests: OrderRecordTestCase {
    func testEntryIsNullBeforeTheStepAndForBackfilledLegacyRows() async throws {
        let staff = try await phone(.staff)
        let before = try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(2)))
        let legacy = try await started()
        for orderCode in [before, legacy] {
            let reply = try await detail(staff, orderCode)
            XCTAssertTrue(reply.json["delivery_fee_entry"] is NSNull, orderCode)
        }
    }

    func testEntryNamesWhoStartedDeliveryAndWhen() async throws {
        let staff = try await phone(.staff, "Nhan Vien Giao"), orderCode = try await place(.init(date: day(5)))
        for json in [move("Received", "Processing"), move("Processing", "DeliveryDateScheduled", date: day(2)),
                     move("DeliveryDateScheduled", "DeliveryStarted", fee: 25_000)] {
            let reply = try await change(staff, orderCode, json)
            XCTAssertEqual(reply.status, .ok, json)
        }
        let reply = try await detail(staff, orderCode)
        let entry = try XCTUnwrap(reply.json["delivery_fee_entry"] as? [String: Any])
        XCTAssertEqual(entry["entered_by_name"] as? String, "Nhan Vien Giao")
        XCTAssertEqual((entry["entered_at"] as? String)?.count, 20)
    }

    func testFeeHistoryIsTheEntryThenCorrectionsOldestFirst() async throws {
        let staff = try await phone(.staff, "Nhan Vien Giao"), orderCode = try await place(.init(date: day(5)))
        for json in [move("Received", "Processing"), move("Processing", "DeliveryDateScheduled", date: day(2)),
                     move("DeliveryDateScheduled", "DeliveryStarted", fee: 25_000)] {
            _ = try await change(staff, orderCode, json)
        }
        for (previous, new) in [("25000", "30000"), ("30000", "35000")] {
            let reply = try await Self.put(app, staff, orderCode, "delivery-fee", feeBody(previous: previous, new: new))
            XCTAssertEqual(reply.status, .ok)
        }
        let reply = try await detail(staff, orderCode)
        XCTAssertNotNil(reply.json["delivery_fee_entry"] as? [String: Any])
        let fixes = try XCTUnwrap(reply.json["fee_corrections"] as? [[String: Any]])
        XCTAssertEqual(fixes.map { $0["new_fee_vnd"] as? Int }, [30_000, 35_000])
        XCTAssertEqual(fixes.first?["old_fee_vnd"] as? Int, 25_000)
        let keys = Array(reply.json.keys), entryAt = try XCTUnwrap(reply.json["delivery_fee_entry"] as? [String: Any])["entered_at"] as? String
        XCTAssertTrue(keys.contains("delivery_fee_entry") && keys.contains("fee_corrections"))
        XCTAssertLessThanOrEqual(try XCTUnwrap(entryAt), try XCTUnwrap(fixes.first?["changed_at"] as? String))
    }
}
