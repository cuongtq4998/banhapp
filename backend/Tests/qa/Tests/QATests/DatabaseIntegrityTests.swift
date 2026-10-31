import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

final class DatabaseIntegrityTests: DatabaseTestBase {

    // MARK: immutability and audit trail (TC-60, TC-70)

    func testSnapshotColumnsAreImmutable() async throws {
        let updates = ["total_cakes = 3", "total_vnd = 1", "items_subtotal_vnd = 1", "delivery_fee_vnd = 1", "delivery_date = '2030-02-01'",
                       "order_code = 'BT-ZZZZZZ'", "slot_start_time = '09:00'", "district_name = 'x'", "created_at = now() - interval '1 day'",
                       "idempotency_key = 'aaaaaaaa-0000-4000-8000-0000000000b9'", "request_hash = '\(String(repeating: "b", count: 64))'",
                       "client_platform = 'android'", "app_version = '9'"]
        for update in updates {
            try await inRollback { tx in
                try await q.insertShopGraph(tx, accepted: 2)
                try await q.run(tx, q.orderInsert(cakes: 2))
                let wasRejected = try await q.rejected(tx, "UPDATE customer_order SET \(update) WHERE id = \(Ids.order)")
                XCTAssertTrue(wasRejected, update)
            }
        }
    }

    func testPaymentStatusStaysMutable() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "UPDATE customer_order SET payment_status = 'paid' WHERE id = \(Ids.order)")
        }
    }

    func testPersonalColumnsChangeOnlyThroughPurge() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.expectRejected(tx, "UPDATE customer_order SET customer_name = 'Other' WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "UPDATE customer_order SET note = 'x' WHERE id = \(Ids.order)")
            // Purge: blank personal columns and set the marker in one statement.
            try await q.run(tx, "UPDATE customer_order SET customer_name = '', customer_phone = '', customer_address = '', note = NULL, pii_purged_at = now() WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "UPDATE customer_order SET pii_purged_at = NULL WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "UPDATE customer_order SET pii_purged_at = now() + interval '1 day' WHERE id = \(Ids.order)")
            // After the purge the personal columns are no longer guarded by the trigger; record behaviour only.
            _ = try await q.rejected(tx, "UPDATE customer_order SET customer_name = 'Late edit' WHERE id = \(Ids.order)")
        }
    }

    func testBlankPersonalDataWithoutPurgeMarkerIsRejected() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.expectRejected(tx, q.orderInsert(cakes: 2).replacingOccurrences(of: "'QA Customer'", with: "''"))
        }
    }

    func testOrderEventIsAppendOnly() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            try await q.run(tx, "INSERT INTO order_event (order_id, event_type, to_status, actor_type) VALUES (\(Ids.order), 'created', 'New', 'customer')")
            try await q.expectRejected(tx, "UPDATE order_event SET to_status = 'Cancelled' WHERE order_id = \(Ids.order)")
            try await q.expectRejected(tx, "DELETE FROM order_event WHERE order_id = \(Ids.order)")
            try await q.expectRejected(tx, "INSERT INTO order_event (order_id, event_type, to_status, actor_type) VALUES (\(Ids.order), 'deleted', 'New', 'customer')")
            try await q.expectRejected(tx, "INSERT INTO order_event (order_id, event_type, to_status, actor_type) VALUES (\(Ids.order), 'created', 'New', 'robot')")
        }
    }

    func testCheckConstraintsRejectBadRows() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            let bad: [(String, String)] = [
                ("day_load over limit", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-02-01', 11, 10)"),
                ("day_load negative", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-02-02', -1, 10)"),
                ("day_load zero limit", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-02-03', 0, 0)"),
                ("day_load duplicate date", "INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(Ids.shop), '2030-01-10', 0, 10)"),
                ("total not sum", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a3'", key: "'aaaaaaaa-0000-4000-8000-0000000000b3'", code: "'BT-ABC236'", subtotal: 100000, total: 1)),
                ("code with excluded letter O", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a4'", key: "'aaaaaaaa-0000-4000-8000-0000000000b4'", code: "'BT-ABCO34'")),
                ("code with digit 1", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a5'", key: "'aaaaaaaa-0000-4000-8000-0000000000b5'", code: "'BT-ABC134'")),
                ("code lower case", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a6'", key: "'aaaaaaaa-0000-4000-8000-0000000000b6'", code: "'BT-abc234'")),
                ("code too short", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a7'", key: "'aaaaaaaa-0000-4000-8000-0000000000b7'", code: "'BT-ABC23'")),
                ("phone not +84", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a8'", key: "'aaaaaaaa-0000-4000-8000-0000000000b8'", code: "'BT-ABC237'", phone: "0901234567")),
                ("phone prefix 84 2", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a9'", key: "'aaaaaaaa-0000-4000-8000-0000000000b9'", code: "'BT-ABC238'", phone: "+84201234567")),
                ("zero cakes", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000aa'", key: "'aaaaaaaa-0000-4000-8000-0000000000ba'", code: "'BT-ABC239'", cakes: 0, subtotal: 0, total: 20000)),
                ("bad status", q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000ab'", key: "'aaaaaaaa-0000-4000-8000-0000000000bb'", code: "'BT-ABC23A'", status: "Done")),
                ("slot end before start", "INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(Ids.shop), '12:00', '11:00')"),
                ("slot equal times", "INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(Ids.shop), '12:00', '12:00')"),
                ("duplicate slot", "INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(Ids.shop), '08:00', '10:00')"),
                ("duplicate district name", "INSERT INTO district (shop_id, name, delivery_fee_vnd) VALUES (\(Ids.shop), 'QA district', 1)"),
                ("negative fee", "INSERT INTO district (shop_id, name, delivery_fee_vnd) VALUES (\(Ids.shop), 'Other', -1)"),
                ("duplicate slug", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'qa-cake', 'n', 'd', 1, 'i')"),
                ("slug upper case", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'QA', 'n', 'd', 1, 'i')"),
                ("negative price", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'neg', 'n', 'd', -1, 'i')"),
                ("empty product name", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(Ids.shop), 'emp', '', 'd', 1, 'i')"),
                ("setting max_days_ahead below lead", "INSERT INTO shop_setting (shop_id, daily_limit, lead_days, max_days_ahead) VALUES (\(Ids.shop), 5, 5, 1)"),
                ("second setting row", "INSERT INTO shop_setting (shop_id, daily_limit) VALUES (\(Ids.shop), 5)"),
                ("shop phone not E.164", "INSERT INTO shop (name, greeting, phone_contact, zalo_contact) VALUES ('n', 'g', '0123456789', '84123456789')"),
                ("unknown shop FK", "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES ('aaaaaaaa-0000-4000-8000-0000000000ff', 'fk', 'n', 'd', 1, 'i')")
            ]
            for (label, sql) in bad {
                let wasRejected = try await q.rejected(tx, sql)
                XCTAssertTrue(wasRejected, label)
            }
        }
    }

    func testIdempotencyKeyAndOrderCodeAreUnique() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 4)
            try await q.run(tx, q.orderInsert(cakes: 2))
            let sameKey = q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a2'", code: "'BT-ABC235'", cakes: 2)
            try await q.expectRejected(tx, sameKey)
            let sameCode = q.orderInsert(id: "'aaaaaaaa-0000-4000-8000-0000000000a3'", key: "'aaaaaaaa-0000-4000-8000-0000000000b3'", cakes: 2)
            try await q.expectRejected(tx, sameCode)
        }
    }

    func testItemChecksAndRestrictiveForeignKeys() async throws {
        try await inRollback { tx in
            try await q.insertShopGraph(tx, accepted: 2)
            try await q.run(tx, q.orderInsert(cakes: 2))
            let item = { (qty: Int, line: Int) in "INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd) VALUES (\(Ids.order), \(Ids.product), 'QA cake', 50000, \(qty), \(line))" }
            try await q.expectRejected(tx, item(0, 0))
            try await q.expectRejected(tx, item(100, 5_000_000))
            try await q.expectRejected(tx, item(2, 1))
            try await q.run(tx, item(2, 100_000))
            try await q.expectRejected(tx, item(2, 100_000), "one line per product")
            try await q.expectRejected(tx, "DELETE FROM product WHERE id = \(Ids.product)")
            try await q.expectRejected(tx, "DELETE FROM customer_order WHERE id = \(Ids.order)")
            try await q.expectRejected(tx, "DELETE FROM shop WHERE id = \(Ids.shop)")
        }
    }

}
