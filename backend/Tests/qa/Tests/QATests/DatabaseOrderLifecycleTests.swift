import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

final class DatabaseOrderLifecycleTests: DatabaseTestBase {

    // MARK: TC-59, TC-60, TC-61

    func testCancelReleasesCapacityOnceAndWritesEvent() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 10)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT cakes_accepted AS n FROM day_load WHERE shop_id = \(Ids.shop)", 8)
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE order_id = \(Ids.order) AND to_status = 'Cancelled' AND from_status = 'New' AND actor_type = 'system'", 1)
            // Second cancel: final state; whatever the DB does, capacity must not drop twice and no second event.
            _ = try await q.rejected(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT cakes_accepted AS n FROM day_load WHERE shop_id = \(Ids.shop)", 8)
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE order_id = \(Ids.order)", 1)
        }
    }

    func testStatusTransitionMatrix() async throws {
        let valid = [("New", "Confirmed"), ("New", "Cancelled"), ("Confirmed", "Completed"), ("Confirmed", "Cancelled")]
        let invalid = [("New", "Completed"), ("Confirmed", "New"), ("Completed", "New"), ("Completed", "Confirmed"),
                       ("Completed", "Cancelled"), ("Cancelled", "New"), ("Cancelled", "Confirmed"), ("Cancelled", "Completed")]
        for (from, to) in valid + invalid {
            let expectOK = valid.contains { $0 == (from, to) }
            try await inRollback { tx in
                // Capacity row large enough so a cancel never trips the CHECK.
                try await q.insertShopGraph(tx, accepted: 4)
                try await q.run(tx, q.orderInsert(cakes: 2, status: from))
                let wasRejected = try await q.rejected(tx, "UPDATE customer_order SET status = '\(to)' WHERE id = \(Ids.order)")
                XCTAssertEqual(wasRejected, !expectOK, "\(from) -> \(to)")
                let now = try await q.text(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)")
                XCTAssertEqual(now, expectOK ? to : from, "\(from) -> \(to)")
            }
        }
    }

    func testCompletionAndConfirmationDoNotTouchCapacity() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 4)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET status = 'Confirmed' WHERE id = \(Ids.order)")
            try await q.run(tx, "UPDATE customer_order SET status = 'Completed' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT cakes_accepted AS n FROM day_load WHERE shop_id = \(Ids.shop)", 4)
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE order_id = \(Ids.order)", 2)
        }
    }

    func testActorSettingsAreRecordedInTheEvent() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "SELECT set_config('app.actor_type', 'staff', true), set_config('app.actor_id', 'aaaaaaaa-0000-4000-8000-0000000000c1', true)")
            try await q.run(tx, "UPDATE customer_order SET status = 'Confirmed' WHERE id = \(Ids.order)")
            try await q.expectCount(tx, "SELECT count(*)::int AS n FROM order_event WHERE actor_type = 'staff' AND actor_id = 'aaaaaaaa-0000-4000-8000-0000000000c1'", 1)
        }
    }

    func testBogusActorTypeFailsTheUpdateAtomically() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "SELECT set_config('app.actor_type', 'hacker', true)")
            try await q.expectRejected(tx, "UPDATE customer_order SET status = 'Confirmed' WHERE id = \(Ids.order)")
            try await q.expectText(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)", "New")
        }
    }

    func testCancelWithMissingDayLoadRowDoesNotFail() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, withDayLoad: false)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectText(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)", "Cancelled")
        }
    }

    func testCancelThatWouldMakeCounterNegativeIsBlockedAndAtomic() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 1) // inconsistent: order has 2 cakes
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.expectRejected(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            try await q.expectText(tx, "SELECT status AS s FROM customer_order WHERE id = \(Ids.order)", "New")
        }
    }

    func testReconciliationHoldsAfterCancels() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 5)
            try await q.run(tx, q.orderInsert(id: Ids.order, key: Ids.key, code: "'BT-ABC234'", cakes: 2))
            try await q.run(tx, q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a2'", key: "'aaaaaaaa-0000-4000-8000-0000000000b2'", code: "'BT-ABC235'", cakes: 3))
            try await q.run(tx, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(Ids.order)")
            let mismatch = try await q.count(tx, """
            SELECT count(*)::int AS n FROM day_load d WHERE d.shop_id = \(Ids.shop) AND d.cakes_accepted <>
              COALESCE((SELECT sum(total_cakes) FROM customer_order o WHERE o.shop_id = d.shop_id AND o.delivery_date = d.delivery_date AND o.status <> 'Cancelled'), 0)
            """)
            XCTAssertEqual(mismatch, 0)
        }
    }

}
