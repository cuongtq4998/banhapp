import XCTVapor
@testable import App

/// TC-B76 to TC-B79, TC-B82 (BR-2, BR-8): the allowed pairs, the four reasons
/// and the field checks. A refused change writes nothing.
final class OrderStatusRulesTests: AdminOrderTestCase {
    private let statuses = ["New", "Confirmed", "Completed", "Cancelled"]
    private let allowed: Set<String> = ["New>Confirmed", "New>Cancelled", "Confirmed>Completed", "Confirmed>Cancelled"]

    func testOnlyTheFourAllowedPairsSucceedOutOfSixteen() async throws {
        let staff = try await phone(.staff)
        for from in statuses {
            for to in statuses {
                let orderCode = try await place(.init(status: from, date: day(5), reason: from == "Cancelled" ? "fake_spam" : nil))
                let reason = to == "Cancelled" ? "customer_asked" : nil
                let reply = try await change(staff, orderCode, move(from, to, reason: reason))
                let stored = try await status(of: orderCode)
                if allowed.contains("\(from)>\(to)") {
                    XCTAssertEqual(reply.status, .ok, "\(from) to \(to)")
                    XCTAssertEqual(stored, to)
                } else {
                    XCTAssertEqual(reply.errorCode, "STATUS_TRANSITION_INVALID", "\(from) to \(to)")
                    XCTAssertEqual(stored, from)
                    let eventCount = try await events(of: orderCode)
                    XCTAssertEqual(eventCount, 0)
                }
            }
        }
    }

    func testEachOfTheFourReasonsIsStoredRecordedAndShown() async throws {
        let staff = try await phone(.staff)
        for (index, reason) in ["customer_asked", "cannot_deliver", "cannot_reach_customer", "fake_spam"].enumerated() {
            for from in ["New", "Confirmed"] {
                let orderCode = try await place(.init(status: from, date: day(5 + index), cakes: 3))
                let reply = try await change(staff, orderCode, move(from, "Cancelled", reason: reason))
                XCTAssertEqual(reply.status, .ok, reason)
                XCTAssertEqual(reply.string("cancel_reason"), reason)
                XCTAssertEqual(reply.json["allowed_actions"] as? [String], [])
                let event = try await count("""
                    SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id
                    WHERE o.order_code = \(bind: orderCode) AND e.reason = \(bind: reason) AND o.cancel_reason = \(bind: reason)
                    """)
                XCTAssertEqual(event, 1)
            }
            let load = try await loaded(day(5 + index))
            XCTAssertEqual(load, 0, "both orders gave their cakes back")
        }
    }

    func testCancelWithoutAValidReasonIsRefusedAndNothingChanges() async throws {
        let orderCode = try await place(.init(date: day(5), cakes: 4))
        let staff = try await phone(.staff)
        let bodies = [
            move("New", "Cancelled"), move("New", "Cancelled", reason: ""), move("New", "Cancelled", reason: "day_full"),
            move("New", "Cancelled", reason: "CUSTOMER_ASKED"), move("New", "Cancelled", reason: "customer_asked,fake_spam"),
            "{\"expected_status\":\"New\",\"to_status\":\"Cancelled\",\"cancel_reason\":null}",
            "{\"expected_status\":\"New\",\"to_status\":\"Cancelled\",\"cancel_reason\":[\"fake_spam\"]}",
            "{\"expected_status\":\"New\",\"to_status\":\"Cancelled\",\"cancel_reason\":7}"
        ]
        for body in bodies {
            let reply = try await change(staff, orderCode, body)
            XCTAssertEqual(reply.status, .unprocessableEntity, body)
            XCTAssertEqual(reply.errorCode, "CANCEL_REASON_REQUIRED", body)
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "New")
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 4)
    }

    func testMalformedBodiesAreValidationErrors() async throws {
        let orderCode = try await place()
        let staff = try await phone(.staff)
        let bodies = [
            move("New", "Confirmed", reason: "customer_asked"), "{\"expected_status\":\"New\",\"to_status\":\"Confirmed\",\"note\":\"x\"}",
            "{\"expected_status\":\"New\",\"to_status\":\"Done\"}", "{\"expected_status\":\"new\",\"to_status\":\"Confirmed\"}",
            "{\"to_status\":\"Confirmed\"}", "{\"expected_status\":\"New\"}", "{\"expected_status\":5,\"to_status\":\"Confirmed\"}",
            "{}", "[]", "not json", ""
        ]
        for body in bodies {
            let reply = try await change(staff, orderCode, body)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", body)
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "New")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 0)
    }

    func testTheValidationErrorNamesTheField() async throws {
        let orderCode = try await place()
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("New", "Confirmed", reason: "customer_asked"))
        let fields = ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]])?.compactMap { $0["field"] as? String }
        XCTAssertEqual(fields, ["cancel_reason"])
    }
}
