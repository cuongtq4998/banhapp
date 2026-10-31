import XCTest
import FluentSQL
@testable import App

/// Behaviour of the triggers in `0001_init.sql` (order-lifecycle.md section 6,
/// data-model.md section 7). Skipped without `DATABASE_MIGRATION_URL`.
final class OrderTriggerTests: DatabaseTestCase {
    func testStatusGuardAllowsOnlyTheLifecycleTransitions() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            try await assertRejected(by: sql, "UPDATE customer_order SET status = 'Completed' WHERE id = \(bind: order.orderID)")
            try await order.setStatus("Confirmed", on: sql)
            try await assertRejected(by: sql, "UPDATE customer_order SET status = 'New' WHERE id = \(bind: order.orderID)")
            try await order.setStatus("Completed", on: sql)
            try await assertRejected(by: sql, "UPDATE customer_order SET status = 'Cancelled' WHERE id = \(bind: order.orderID)")
        }
    }

    func testUpdateThatKeepsTheStatusIsAllowedAndWritesNoEvent() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            try await sql.raw("UPDATE customer_order SET payment_status = 'paid' WHERE id = \(bind: order.orderID)").run()
            try await sql.raw("UPDATE customer_order SET status = 'New' WHERE id = \(bind: order.orderID)").run()
            let events = try await order.events(on: sql)
            XCTAssertTrue(events.isEmpty)
        }
    }

    func testEveryStatusChangeWritesAnEventWithTheSystemActorByDefault() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            try await order.setStatus("Confirmed", on: sql)
            try await order.setStatus("Completed", on: sql)
            let events = try await order.events(on: sql)
            XCTAssertEqual(events, [
                .init(fromStatus: "New", toStatus: "Confirmed", actorType: "system", actorID: nil),
                .init(fromStatus: "Confirmed", toStatus: "Completed", actorType: "system", actorID: nil)
            ])
        }
    }

    func testSessionSettingsOverrideTheEventActor() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            let staffID = UUID()
            // `true` makes the setting local to the transaction.
            try await sql.raw("SELECT set_config('app.actor_type', 'staff', true)").run()
            try await sql.raw("SELECT set_config('app.actor_id', \(bind: staffID.uuidString), true)").run()
            try await order.setStatus("Confirmed", on: sql)
            let events = try await order.events(on: sql)
            XCTAssertEqual(events, [.init(fromStatus: "New", toStatus: "Confirmed", actorType: "staff", actorID: staffID)])
        }
    }

    /// AC-28: a cancellation gives the cakes back to the date.
    func testCancellingReleasesCapacityAndOtherChangesDoNot() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql, totalCakes: 6)
            let before = try await order.cakesAccepted(on: sql)
            XCTAssertEqual(before, 6)
            try await order.setStatus("Confirmed", on: sql)
            let afterConfirm = try await order.cakesAccepted(on: sql)
            XCTAssertEqual(afterConfirm, 6)
            try await order.setStatus("Cancelled", on: sql)
            let afterCancel = try await order.cakesAccepted(on: sql)
            XCTAssertEqual(afterCancel, 0)
            let events = try await order.events(on: sql)
            XCTAssertEqual(events.last?.toStatus, "Cancelled")
        }
    }

    func testCancellingANewOrderReleasesCapacity() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql, totalCakes: 4)
            try await order.setStatus("Cancelled", on: sql)
            let accepted = try await order.cakesAccepted(on: sql)
            XCTAssertEqual(accepted, 0)
        }
    }

    func testSnapshotColumnsAreImmutable() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            let id = order.orderID
            try await assertRejected(by: sql, "UPDATE customer_order SET delivery_date = '2030-02-01' WHERE id = \(bind: id)")
            try await assertRejected(by: sql, "UPDATE customer_order SET total_cakes = 1 WHERE id = \(bind: id)")
            try await assertRejected(by: sql, "UPDATE customer_order SET district_name = 'Other' WHERE id = \(bind: id)")
            try await assertRejected(by: sql, "UPDATE customer_order SET order_code = 'BT-222222' WHERE id = \(bind: id)")
        }
    }

    func testPersonalColumnsChangeOnlyWhenPurging() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            let id = order.orderID
            try await assertRejected(by: sql, "UPDATE customer_order SET customer_name = 'Someone Else' WHERE id = \(bind: id)")
            try await sql.raw("""
                UPDATE customer_order
                   SET customer_name = '', customer_phone = '', customer_address = '', note = NULL,
                       pii_purged_at = now()
                 WHERE id = \(bind: id)
                """).run()
            try await assertRejected(by: sql, "UPDATE customer_order SET pii_purged_at = NULL WHERE id = \(bind: id)")
        }
    }

    func testOrderEventIsAppendOnly() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql)
            try await order.setStatus("Confirmed", on: sql)
            try await assertRejected(by: sql, "UPDATE order_event SET to_status = 'Completed' WHERE order_id = \(bind: order.orderID)")
            try await assertRejected(by: sql, "DELETE FROM order_event WHERE order_id = \(bind: order.orderID)")
        }
    }

    func testDayLoadNeverExceedsItsLimit() async throws {
        try await withRolledBackTransaction { sql in
            let order = try await OrderFixture.insert(on: sql, totalCakes: 6, capacityLimit: 10)
            try await assertRejected(by: sql, """
                UPDATE day_load SET cakes_accepted = 11
                WHERE shop_id = \(bind: order.shopID)
                """)
        }
    }
}
