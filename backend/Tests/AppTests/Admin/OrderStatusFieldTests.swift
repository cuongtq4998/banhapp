import XCTVapor
@testable import App

/// The expected date at schedule and the real fee at start (api/09 10.13.1):
/// required, bounded, written with the move.
final class OrderStatusFieldTests: AdminOrderTestCase {
    private func schedule(_ staff: Phone, _ orderCode: String, _ date: String?) async throws -> Reply {
        try await change(staff, orderCode, move("Processing", "DeliveryDateScheduled", date: date))
    }

    private func start(_ staff: Phone, _ orderCode: String, _ body: String) async throws -> Reply {
        try await change(staff, orderCode, body)
    }

    private func fields(_ reply: Reply) -> [String] {
        ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]])?.compactMap { $0["code"] as? String } ?? []
    }

    func testScheduleNeedsADateAndAcceptsTodayToTodayPlusSeven() async throws {
        let staff = try await phone(.staff, "Nhan Vien A")
        for offset in [0, 1, 7] {
            let orderCode = try await place(.init(status: "Processing", date: day(3)))
            let reply = try await schedule(staff, orderCode, day(offset))
            XCTAssertEqual(reply.status, .ok, "today + \(offset)")
            XCTAssertEqual(reply.string("expected_delivery_date"), day(offset))
            XCTAssertEqual(reply.string("status"), "DeliveryDateScheduled")
            XCTAssertEqual(reply.json["allowed_actions"] as? [String], ["change_date", "start_delivery"])
            let changes = try XCTUnwrap(reply.json["date_changes"] as? [[String: Any]])
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes.first?["new_date"] as? String, day(offset))
            XCTAssertEqual(changes.first?["changed_by_name"] as? String, "Nhan Vien A")
            XCTAssertTrue(changes.first?["old_date"] is NSNull)
            let range = try XCTUnwrap(reply.json["expected_date_range"] as? [String: String])
            XCTAssertEqual(range, ["min": day(0), "max": day(7)])
        }
    }

    func testScheduleRefusesMissingBadPastAndTooFarDatesAndWritesNothing() async throws {
        let staff = try await phone(.staff)
        let orderCode = try await place(.init(status: "Processing", date: day(3)))
        let cases: [(String?, String)] = [
            (nil, "EXPECTED_DATE_REQUIRED"), ("not-a-date", "EXPECTED_DATE_INVALID"),
            (day(-1), "EXPECTED_DATE_PAST"), (day(8), "EXPECTED_DATE_TOO_FAR")
        ]
        for (date, code) in cases {
            let reply = try await schedule(staff, orderCode, date)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", code)
            XCTAssertEqual(fields(reply), [code])
            if code.hasSuffix("PAST") || code.hasSuffix("FAR") {
                let details = (reply.json["error"] as? [String: Any])?["details"] as? [String: Any]
                XCTAssertEqual(details?["expected_date_range"] as? [String: String], ["min": day(0), "max": day(7)])
            }
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Processing")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 0)
        let rows = try await count("SELECT count(*)::int AS n FROM order_expected_date_change c JOIN customer_order o ON o.id = c.order_id WHERE o.order_code = \(bind: orderCode)")
        XCTAssertEqual(rows, 0)
    }

    func testStartNeedsTheFeeAndZeroIsAllowed() async throws {
        let staff = try await phone(.staff)
        for fee in [0, 25_000, 10_000_000] {
            let orderCode = try await place(.init(status: "DeliveryDateScheduled", cakes: 2, expectedDate: day(1)))
            let reply = try await start(staff, orderCode, move("DeliveryDateScheduled", "DeliveryStarted", fee: fee))
            XCTAssertEqual(reply.status, .ok, "fee \(fee)")
            XCTAssertEqual(reply.json["delivery_fee_final_vnd"] as? Int, fee)
            XCTAssertEqual(reply.json["amount_to_collect_vnd"] as? Int, 100_000 + fee)
            XCTAssertEqual(reply.json["allowed_actions"] as? [String], ["correct_fee", "finish"])
            let set = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code = \(bind: orderCode) AND delivery_fee_set_at IS NOT NULL")
            XCTAssertEqual(set, 1)
        }
    }

    func testStartRefusesAMissingOrInvalidFeeAndWritesNothing() async throws {
        let staff = try await phone(.staff)
        let orderCode = try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(1)))
        let head = #"{"expected_status":"DeliveryDateScheduled","to_status":"DeliveryStarted""#
        let cases = [
            (move("DeliveryDateScheduled", "DeliveryStarted"), "FEE_REQUIRED"), (head + #","delivery_fee_vnd":null}"#, "FEE_REQUIRED"),
            (move("DeliveryDateScheduled", "DeliveryStarted", fee: -1), "FEE_INVALID"),
            (move("DeliveryDateScheduled", "DeliveryStarted", fee: 10_000_001), "FEE_INVALID"),
            (head + #","delivery_fee_vnd":1.5}"#, "FEE_INVALID"), (head + #","delivery_fee_vnd":"20000"}"#, "FEE_INVALID")
        ]
        for (json, code) in cases {
            let reply = try await start(staff, orderCode, json)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", json)
            XCTAssertEqual(fields(reply), [code], json)
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "DeliveryDateScheduled")
        let set = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code = \(bind: orderCode) AND delivery_fee_final_vnd IS NOT NULL")
        XCTAssertEqual(set, 0)
    }

    func testAFeeOrDateOnTheWrongTargetIsRefused() async throws {
        let staff = try await phone(.staff)
        let orderCode = try await place(.init(status: "Processing"))
        let wrong = [
            move("Processing", "DeliveryDateScheduled", date: day(1), fee: 5), move("Processing", "Cancelled", reason: "fake_spam", date: day(1)),
            move("Processing", "Cancelled", reason: "fake_spam", fee: 5)
        ]
        for json in wrong {
            let reply = try await change(staff, orderCode, json)
            XCTAssertEqual(fields(reply), ["FIELD_NOT_ALLOWED"], json)
        }
    }
}
