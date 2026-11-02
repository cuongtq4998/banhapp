import XCTVapor
@testable import App

/// The allowed pairs, the four reasons and the field checks of the status
/// route (BR-2, BR-8). A refused change writes nothing.
final class OrderStatusRouteTests: AdminOrderTestCase {
    private let steps = OrderStatus.allCases.map(\.rawValue)

    /// Valid body for a pair, and the order the pair starts from.
    private func seed(_ from: String) -> SeedOrder {
        let needsDate = ["DeliveryDateScheduled", "DeliveryStarted", "Finished"].contains(from)
        return SeedOrder(
            status: from, date: day(5), reason: from == "Cancelled" ? "fake_spam" : nil,
            expectedDate: needsDate ? day(2) : nil, finalFee: ["DeliveryStarted", "Finished"].contains(from) ? 20_000 : nil
        )
    }

    private func body(_ from: String, _ to: String) -> String {
        move(from, to, reason: to == "Cancelled" ? "customer_asked" : nil,
             date: to == "DeliveryDateScheduled" ? day(2) : nil, fee: to == "DeliveryStarted" ? 25_000 : nil)
    }

    func testOnlyTheSixAllowedPairsSucceedOutOfThirtySix() async throws {
        let allowed: Set<String> = [
            "Received>Processing", "Received>Cancelled", "Processing>DeliveryDateScheduled",
            "Processing>Cancelled", "DeliveryDateScheduled>DeliveryStarted", "DeliveryStarted>Finished"
        ]
        let staff = try await phone(.staff)
        for from in steps {
            for to in steps {
                let orderCode = try await place(seed(from))
                let reply = try await change(staff, orderCode, body(from, to))
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

    func testEachOfTheFourReasonsIsStoredRecordedAndShownFromReceivedAndProcessing() async throws {
        let staff = try await phone(.staff)
        for (index, reason) in ["customer_asked", "cannot_deliver", "cannot_reach_customer", "fake_spam"].enumerated() {
            for from in ["Received", "Processing"] {
                let orderCode = try await place(.init(status: from, date: day(5 + index), cakes: 3))
                let reply = try await change(staff, orderCode, move(from, "Cancelled", reason: reason))
                XCTAssertEqual(reply.status, .ok, reason)
                XCTAssertEqual(reply.string("cancel_reason"), reason)
                XCTAssertEqual(reply.json["allowed_actions"] as? [String], [])
                let event = try await count("""
                    SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id
                    WHERE o.order_code = \(bind: orderCode) AND e.reason = \(bind: reason) AND o.cancel_reason = \(bind: reason)
                      AND e.to_status = 'Cancelled'
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
        let head = #"{"expected_status":"Received","to_status":"Cancelled""#
        let bodies = [
            move("Received", "Cancelled"), move("Received", "Cancelled", reason: ""), move("Received", "Cancelled", reason: "day_full"),
            move("Received", "Cancelled", reason: "CUSTOMER_ASKED"), head + #","cancel_reason":null}"#,
            head + #","cancel_reason":["fake_spam"]}"#, head + #","cancel_reason":7}"#
        ]
        for json in bodies {
            let reply = try await change(staff, orderCode, json)
            XCTAssertEqual(reply.status, .unprocessableEntity, json)
            XCTAssertEqual(reply.errorCode, "CANCEL_REASON_REQUIRED", json)
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Received")
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 4)
    }

    func testMalformedBodiesAreValidationErrors() async throws {
        let orderCode = try await place()
        let staff = try await phone(.staff)
        let head = #"{"expected_status":"Received","to_status":"Processing""#
        let bodies = [
            move("Received", "Processing", reason: "customer_asked"), head + #","note":"x"}"#,
            move("Received", "Processing", date: day(1)), move("Received", "Processing", fee: 0),
            #"{"expected_status":"Received","to_status":"Done"}"#, #"{"expected_status":"received","to_status":"Processing"}"#,
            #"{"expected_status":"New","to_status":"Processing"}"#, #"{"to_status":"Processing"}"#,
            #"{"expected_status":"Received"}"#, #"{"expected_status":5,"to_status":"Processing"}"#,
            "{}", "[]", "not json", ""
        ]
        for json in bodies {
            let reply = try await change(staff, orderCode, json)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", json)
        }
        let stored = try await status(of: orderCode)
        XCTAssertEqual(stored, "Received")
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 0)
    }

    func testTheValidationErrorNamesTheField() async throws {
        let orderCode = try await place()
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("Received", "Processing", reason: "customer_asked"))
        let fields = (reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]]
        XCTAssertEqual(fields?.compactMap { $0["field"] as? String }, ["cancel_reason"])
        XCTAssertEqual(fields?.compactMap { $0["code"] as? String }, ["FIELD_NOT_ALLOWED"])
    }
}
