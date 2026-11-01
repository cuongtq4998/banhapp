import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// TC-B84, TC-B81, TC-B67 (black box over HTTP): cancel against customer orders and against itself.
final class AdminCancelRaceTests: AdminQABase {

    private func openCakes(_ date: String) async throws -> Int {
        try await count("SELECT coalesce(sum(total_cakes), 0)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: date)::date AND status IN ('New','Confirmed')")
    }

    /// TC-B84: a cancel freeing cakes races customers who want them at the capacity edge. Ten rounds.
    func testTCB84_CancelRacingCustomerOrdersNeverOversellsOrGoesNegative() async throws {
        let ownerPhone = try await owner()
        try await run("UPDATE shop_setting SET daily_limit = 10 WHERE shop_id = \(bind: shopID)")
        for round in 0..<10 {
            let date = dayOffset(3 + round)
            let big = try await seedOrder(cakes: 8, date: date)       // day_load 8 of 10
            try await run("UPDATE day_load SET capacity_limit = 10 WHERE shop_id = \(bind: shopID) AND delivery_date = \(bind: date)::date")
            let client = self.client, access = ownerPhone.access, shop = self.shopRef
            let results: [Int] = await withTaskGroup(of: Int.self) { group in
                group.addTask {
                    let r = try? await client.send("POST", "v1/admin/orders/\(big)/status", token: access,
                        json: ["expected_status": "New", "to_status": "Cancelled", "cancel_reason": "customer_asked"])
                    return r?.status ?? -1
                }
                for index in 0..<6 {
                    group.addTask {
                        let r = try? await shop.order(date: date, cakes: 4, phone: "09000001\(round)\(index)")
                        return r?.status ?? -1
                    }
                }
                var all: [Int] = []
                for await status in group { all.append(status) }
                return all
            }
            XCTAssertFalse(results.contains { $0 >= 500 || $0 < 0 }, "round \(round): \(results)")
            let loaded = try await self.loaded(date), open = try await openCakes(date)
            XCTAssertEqual(loaded, open, "round \(round): day_load must equal the open cakes")
            XCTAssertLessThanOrEqual(loaded, 10, "round \(round): oversold")
            XCTAssertGreaterThanOrEqual(loaded, 0)
            let accepted = results.dropFirst(0).filter { $0 == 201 }.count
            XCTAssertLessThanOrEqual(accepted, 2, "round \(round): at most two 4-cake orders fit into 10 once 8 are freed")
        }
    }

    /// TC-B81 and TC-B84: many parallel cancels of one order give the cakes back once.
    func testTCB81_ParallelRepeatedCancelReturnsCakesOnce() async throws {
        let ownerPhone = try await owner()
        let date = dayOffset(5)
        let target = try await seedOrder(cakes: 4, date: date)
        _ = try await seedOrder(cakes: 3, date: date)
        let client = self.client, access = ownerPhone.access
        let replies: [QAReply] = await withTaskGroup(of: QAReply?.self) { group in
            for index in 0..<8 {
                group.addTask {
                    try? await client.send("POST", "v1/admin/orders/\(target)/status", token: access,
                        json: ["expected_status": "New", "to_status": "Cancelled", "cancel_reason": index % 2 == 0 ? "customer_asked" : "fake_spam"])
                }
            }
            var all: [QAReply] = []
            for await reply in group { if let reply { all.append(reply) } }
            return all
        }
        XCTAssertEqual(replies.count, 8)
        XCTAssertEqual(replies.filter { $0.status >= 500 }.count, 0)
        // Reasons differ between callers: exactly one wins; the rest are conflicts or same-move replays.
        XCTAssertGreaterThanOrEqual(replies.filter { $0.status == 200 && $0.header("Idempotent-Replay") == nil }.count, 1)
        let after = try await loaded(date)
        XCTAssertEqual(after, 3, "4 cakes given back once")
        let events = try await count("SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id WHERE o.order_code = \(bind: target) AND e.event_type = 'status_changed'")
        XCTAssertEqual(events, 1)
        // A later repeat of the exact same move is a 200 replay and changes nothing.
        let first = try await client.send("GET", "v1/admin/orders/\(target)", token: ownerPhone.access)
        let reason = first.json["cancel_reason"] as? String ?? ""
        let again = try await changeStatus(ownerPhone, target, from: "New", to: "Cancelled", reason: reason)
        XCTAssertEqual(again.status, 200)
        XCTAssertEqual(again.header("Idempotent-Replay"), "true")
        let final = try await loaded(date)
        XCTAssertEqual(final, 3)
    }

    /// TC-B67: cancel of an old order whose day_load row is missing or smaller than the order. Records the observed behaviour.
    func testTCB67_CancelWithMissingOrInconsistentDayLoadDoesNotCrash() async throws {
        let ownerPhone = try await owner()
        let past = dayOffset(-75)
        let old = try await seedOrder(cakes: 3, date: past, placed: clock.now().addingTimeInterval(-100 * 86_400), load: false)
        let missing = try await changeStatus(ownerPhone, old, from: "New", to: "Cancelled", reason: "cannot_deliver")
        XCTAssertEqual(missing.status, 200, "no day_load row: cancel must succeed (\(missing.text))")
        let date = dayOffset(6)
        let short = try await seedOrder(cakes: 4, date: date, load: false)
        try await addLoad(date, 1)  // row says 1 cake but the order has 4: inconsistent, reachable only by manual SQL
        let negative = try await changeStatus(ownerPhone, short, from: "New", to: "Cancelled", reason: "cannot_deliver")
        let value = try await loaded(date)
        XCTAssertTrue(value >= 0, "day_load went negative: \(value) (status \(negative.status))")
        // Observed (defect D-3, low): the CHECK on day_load refuses the negative value and the answer is 500.
        // The safe outcome is what matters here: nothing is half done.
        if negative.status >= 500 {
            let stored = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code = \(bind: short) AND status = 'New'")
            XCTAssertEqual(stored, 1, "a refused cancel must leave the order New")
            XCTAssertEqual(value, 1, "and day_load unchanged")
        }
    }
}
