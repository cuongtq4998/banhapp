import XCTest
import Vapor
@testable import AppUnderTest

/// TC-B76 to TC-B82, D-1 (repeat after the order left the window), BR-9 window: black box over HTTP.
final class AdminStatusRulesTests: AdminQABase {
    override var useRealClock: Bool { true }
    private var phone = QAPhone(access: "", refresh: "", deviceID: "")
    private let statuses = ["Received", "Processing", "DeliveryDateScheduled", "DeliveryStarted", "Finished", "Cancelled"]
    private let allowed: Set<String> = [
        "Received>Processing", "Received>Cancelled", "Processing>DeliveryDateScheduled",
        "Processing>Cancelled", "DeliveryDateScheduled>DeliveryStarted", "DeliveryStarted>Finished"]

    override func setUp() async throws {
        try await super.setUp()
        phone = try await owner()
    }

    func testTCB82_AllThirtySixPairsOnlySixSucceedAndNothingElseChanges() async throws {
        for from in statuses {
            for to in statuses {
                let reason = from == "Cancelled" ? "customer_asked" : nil
                let code = try await seedOrder(status: from, date: dayOffset(5), reason: reason)
                let before = try await loaded(dayOffset(5))
                let reply = try await changeStatus(phone, code, from: from, to: to, reason: to == "Cancelled" ? "cannot_deliver" : nil)
                if allowed.contains("\(from)>\(to)") {
                    XCTAssertEqual(reply.status, 200, "\(from)>\(to): \(reply.text)")
                    XCTAssertEqual(reply.json["status"] as? String, to)
                } else {
                    XCTAssertEqual(reply.status, 422, "\(from)>\(to): \(reply.text)")
                    XCTAssertEqual(reply.errorCode, "STATUS_TRANSITION_INVALID", "\(from)>\(to)")
                    let stored = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code = \(bind: code) AND status = \(bind: from)")
                    XCTAssertEqual(stored, 1, "\(from)>\(to) must not change the order")
                    let after = try await loaded(dayOffset(5))
                    XCTAssertEqual(after, before, "\(from)>\(to) must not touch capacity")
                }
            }
        }
    }

    func testTCB80_StaleViewIsAConflictWithTheCurrentOrder() async throws {
        let code = try await seedOrder(date: dayOffset(5))
        try await aeq(try await changeStatus(phone, code, from: "Received", to: "Processing").status, 200)
        let member = try await staff()
        let stale = try await changeStatus(member.phone, code, from: "Received", to: "Cancelled", reason: "cannot_deliver")
        XCTAssertEqual(stale.status, 409)
        XCTAssertEqual(stale.errorCode, "ORDER_STATE_CHANGED")
        let current = (stale.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["order"] as? [String: Any] }
        XCTAssertEqual(current?["status"] as? String, "Processing")
        let again = try await changeStatus(member.phone, code, from: "Received", to: "Processing")
        XCTAssertEqual(again.status, 409, "a different account repeating the move is a conflict, not a replay")
    }

    func testTCB78_CancelReasonRules() async throws {
        let date = dayOffset(5)
        for bad in [nil, "", "day_full", "CUSTOMER_ASKED", " fake_spam", "customer_asked,fake_spam", "other", String(repeating: "x", count: 500)] {
            let code = try await seedOrder(date: date)
            let before = try await loaded(date)
            let reply = try await changeStatus(phone, code, from: "Received", to: "Cancelled", reason: bad)
            XCTAssertEqual(reply.status, 422, "reason \(String(describing: bad?.prefix(20)))")
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED" == reply.errorCode ? "VALIDATION_FAILED" : "CANCEL_REASON_REQUIRED")
            let kept = try await loaded(date)
            XCTAssertEqual(kept, before)
        }
        for reason in ["customer_asked", "cannot_deliver", "cannot_reach_customer", "fake_spam"] {
            let code = try await seedOrder(status: reason.count % 2 == 0 ? "Received" : "Processing", date: date)
            let from = reason.count % 2 == 0 ? "Received" : "Processing"
            let reply = try await changeStatus(phone, code, from: from, to: "Cancelled", reason: reason)
            XCTAssertEqual(reply.status, 200, "\(reason): \(reply.text)")
            XCTAssertEqual(reply.json["cancel_reason"] as? String, reason)
        }
    }

    /// D-1: the lost-reply repeat still answers 200 after the order left the 90 day window; anything else stays 404.
    func testTCB68_RepeatAfterTheOrderLeftTheWindow() async throws {
        let old = clock.now().addingTimeInterval(-100 * 86_400)
        let code = try await seedOrder(status: "DeliveryStarted", date: dayOffset(-70), placed: old, load: false)
        let done = try await changeStatus(phone, code, from: "DeliveryStarted", to: "Finished")
        XCTAssertEqual(done.status, 200, done.text)
        let detail = try await client.send("GET", "v1/admin/orders/\(code)", token: phone.access)
        XCTAssertEqual(detail.status, 404, "finished and older than 90 days: gone")
        let repeatCall = try await changeStatus(phone, code, from: "DeliveryStarted", to: "Finished")
        XCTAssertEqual(repeatCall.status, 200)
        XCTAssertEqual(repeatCall.header("Idempotent-Replay"), "true")
        let other = try await changeStatus(phone, code, from: "Finished", to: "Cancelled", reason: "customer_asked")
        XCTAssertEqual(other.status, 404, "any other call on a finished old order stays 404")
        XCTAssertEqual(other.errorCode, "ORDER_NOT_FOUND")
        let member = try await staff()
        let strangerRepeat = try await changeStatus(member.phone, code, from: "DeliveryStarted", to: "Finished")
        XCTAssertEqual(strangerRepeat.status, 404, "another account's repeat is not a replay")
        let unknown = try await changeStatus(phone, "BT-ZZZZZZ", from: "Received", to: "Processing")
        XCTAssertEqual(unknown.status, 404)
        XCTAssertEqual(unknown.json["error"] as? NSDictionary, other.json["error"] as? NSDictionary, "unknown and out-of-window answer the same")
    }

    func testTCB64_NinetyDayWindowBoundaryAndOldOpenOrders() async throws {
        let now = clock.now()
        let inside = try await seedOrder(status: "Finished", date: dayOffset(-80), placed: now.addingTimeInterval(-89 * 86_400))
        let outside = try await seedOrder(status: "Finished", date: dayOffset(-80), placed: now.addingTimeInterval(-91 * 86_400))
        let cancelledOutside = try await seedOrder(status: "Cancelled", date: dayOffset(-80), placed: now.addingTimeInterval(-91 * 86_400), reason: "customer_asked")
        let oldOpen = try await seedOrder(status: "Received", date: dayOffset(-75), placed: now.addingTimeInterval(-100 * 86_400), load: false)
        let list = try await client.send("GET", "v1/admin/orders?status=all", token: phone.access)
        let shown = (list.json["items"] as? [[String: Any]] ?? []).compactMap { $0["order_code"] as? String }
        XCTAssertTrue(shown.contains(inside))
        XCTAssertTrue(shown.contains(oldOpen), "an open order of any age is listed")
        XCTAssertFalse(shown.contains(outside) || shown.contains(cancelledOutside))
        for code in [outside, cancelledOutside] {
            let detail = try await client.send("GET", "v1/admin/orders/\(code)", token: phone.access)
            XCTAssertEqual(detail.status, 404)
            let unknown = try await client.send("GET", "v1/admin/orders/BT-ZZZZZZ", token: phone.access)
            XCTAssertEqual(detail.json["error"] as? NSDictionary, unknown.json["error"] as? NSDictionary, "no hint that it exists")
            let search = try await client.send("GET", "v1/admin/orders?status=all&q=\(code)", token: phone.access)
            XCTAssertEqual((search.json["items"] as? [Any])?.count, 0)
        }
        try await aeq(try await client.send("GET", "v1/admin/orders/\(oldOpen)", token: phone.access).status, 200)
    }
}
