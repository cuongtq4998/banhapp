import XCTVapor
import FluentSQL
import BanhContracts
@testable import App

final class OrderDatabaseTests: OrderDatabaseTestCase {
    func testStoresOrderItemsCounterAndCreatedEvent() async throws {
        let seed = try await start(dailyLimit: 20)
        let answer = try await send(body(seed))
        XCTAssertEqual(answer.status, .created)
        let placed = try JSONDecoder().decode(OrderCreatedResponse.self, from: Data(answer.body.utf8))
        XCTAssertNotNil(placed.orderCode.wholeMatch(of: /BT-[2-9A-HJKMNP-Z]{6}/))

        let found = try await sql.raw("""
            SELECT status, payment_status, customer_name, customer_phone, customer_address, note, district_name,
                   delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes, client_platform, app_version,
                   to_char(slot_start_time, 'HH24:MI') AS slot_start, delivery_date::text AS delivery_date,
                   to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
            FROM customer_order WHERE shop_id = \(bind: seed.shopID) AND order_code = \(bind: placed.orderCode)
            """).first()
        let row = try XCTUnwrap(found)
        XCTAssertEqual(try row.decode(column: "status", as: String.self), "New")
        XCTAssertEqual(try row.decode(column: "payment_status", as: String.self), "unpaid")
        XCTAssertEqual(try row.decode(column: "customer_name", as: String.self), "Nguyễn Văn A")
        XCTAssertEqual(try row.decode(column: "customer_phone", as: String.self), "+84900000000")
        XCTAssertEqual(try row.decode(column: "note", as: String?.self), "Ít đường")
        XCTAssertEqual(try row.decode(column: "district_name", as: String.self), "Quận 1")
        XCTAssertEqual(try row.decode(column: "items_subtotal_vnd", as: Int.self), 100_000)
        XCTAssertEqual(try row.decode(column: "total_vnd", as: Int.self), 120_000)
        XCTAssertEqual(try row.decode(column: "total_cakes", as: Int.self), 2)
        XCTAssertEqual(try row.decode(column: "client_platform", as: String.self), "android")
        XCTAssertEqual(try row.decode(column: "app_version", as: String.self), "2.1.0")
        XCTAssertEqual(try row.decode(column: "slot_start", as: String.self), "08:00")
        XCTAssertEqual(try row.decode(column: "delivery_date", as: String.self), "2026-11-10")
        XCTAssertEqual(try row.decode(column: "created_at", as: String.self), placed.createdAt)
        XCTAssertEqual(placed.createdAt, "2026-11-02T05:00:00Z")

        let items = try await count("SELECT count(*)::int AS n FROM customer_order_item i JOIN customer_order o ON o.id = i.order_id WHERE o.shop_id = \(bind: seed.shopID) AND i.unit_price_vnd = 50000 AND i.quantity = 2 AND i.line_total_vnd = 100000 AND i.product_name = 'Bánh chuối'")
        XCTAssertEqual(items, 1)
        let events = try await count("SELECT count(*)::int AS n FROM order_event e JOIN customer_order o ON o.id = e.order_id WHERE o.shop_id = \(bind: seed.shopID) AND e.event_type = 'created' AND e.from_status IS NULL AND e.to_status = 'New' AND e.actor_type = 'customer'")
        XCTAssertEqual(events, 1)
        let counter = try await cakes(seed)
        XCTAssertEqual(counter, 2)
    }

    func testReplayChangesNothingAndSurvivesPriceAndDateChanges() async throws {
        let seed = try await start(dailyLimit: 20)
        let key = UUID()
        let payload = try body(seed)
        let first = try await send(payload, key: key)
        try await sql.raw("UPDATE product SET price_vnd = 99000 WHERE id = \(bind: seed.productID)").run()
        let again = try await send(payload, key: key)
        XCTAssertEqual(again.status, .ok)
        XCTAssertEqual(again.replayHeader, "true")
        XCTAssertEqual(again.body, first.body)
        let orders = try await orderCount(seed)
        let counter = try await cakes(seed)
        XCTAssertEqual(orders, 1)
        XCTAssertEqual(counter, 2)
        let different = try await send(body(seed, cakes: 3), key: key)
        XCTAssertEqual(different.status, .unprocessableEntity)
        XCTAssertEqual(try errorCode(different), "IDEMPOTENCY_KEY_REUSED")
    }

    func testStoredPricesSurviveALaterPriceChange() async throws {
        let seed = try await start(dailyLimit: 20)
        _ = try await send(body(seed))
        try await sql.raw("UPDATE product SET price_vnd = 60000 WHERE id = \(bind: seed.productID)").run()
        let stored = try await count("SELECT i.unit_price_vnd AS n FROM customer_order_item i JOIN customer_order o ON o.id = i.order_id WHERE o.shop_id = \(bind: seed.shopID)")
        XCTAssertEqual(stored, 50_000)
        let stale = try await send(body(seed))
        XCTAssertEqual(stale.status, .conflict)
        XCTAssertEqual(try errorCode(stale), "PRICE_CHANGED")
        let ordersAfterStale = try await orderCount(seed)
        XCTAssertEqual(ordersAfterStale, 1)
    }

    func testFullDateRollsEverythingBack() async throws {
        let seed = try await start(dailyLimit: 3)
        let first = try await send(body(seed, cakes: 2))
        XCTAssertEqual(first.status, .created)
        let second = try await send(body(seed, cakes: 2, phone: "0900000001"))
        XCTAssertEqual(second.status, .conflict)
        XCTAssertEqual(try errorCode(second), "DATE_CAPACITY")
        let orders = try await orderCount(seed)
        let counter = try await cakes(seed)
        XCTAssertEqual(orders, 1)
        XCTAssertEqual(counter, 2)
        let exactFit = try await send(body(seed, cakes: 1, phone: "0900000002", total: 70_000))
        XCTAssertEqual(exactFit.status, .unprocessableEntity, "one cake is below the minimum of 2")
    }

    func testExactFitIsAccepted() async throws {
        let seed = try await start(dailyLimit: 4)
        let a = try await send(body(seed, cakes: 2, phone: "0900000001"))
        let b = try await send(body(seed, cakes: 2, phone: "0900000002"))
        XCTAssertEqual([a.status, b.status], [.created, .created])
        let counter = try await cakes(seed)
        XCTAssertEqual(counter, 4)
    }

    func testPerPhoneLimitCountsStoredOrdersOfTheLast24Hours() async throws {
        let seed = try await start(dailyLimit: 100, orders: OrderPolicy(perAddressPerHour: 10_000, perPhonePerDay: 2))
        for _ in 0..<2 {
            let ok = try await send(body(seed, phone: "+84 900 000 007"))
            XCTAssertEqual(ok.status, .created)
        }
        let limited = try await send(body(seed, phone: "0900-000-007"))
        XCTAssertEqual(limited.status, .tooManyRequests)
        XCTAssertEqual(try errorCode(limited), "RATE_LIMITED")
        let other = try await send(body(seed, phone: "0900000008"))
        XCTAssertEqual(other.status, .created)
        let orders = try await orderCount(seed)
        XCTAssertEqual(orders, 3)
    }

    func testRulesAreCheckedAgainstTheDatabaseData() async throws {
        let seed = try await start(dailyLimit: 20)
        let soon = try await send(body(seed, date: "2026-11-03"))
        XCTAssertEqual(try errorCode(soon), "DATE_LEAD")
        let far = try await send(body(seed, date: "2026-12-03"))
        XCTAssertEqual(try errorCode(far), "DATE_HORIZON")
        try await sql.raw("UPDATE district SET is_active = false WHERE id = \(bind: seed.districtID)").run()
        let district = try await send(body(seed))
        XCTAssertEqual(try errorCode(district), "DISTRICT_UNSERVED")
        try await sql.raw("UPDATE product SET is_active = false WHERE id = \(bind: seed.productID)").run()
        let product = try await send(body(seed))
        XCTAssertEqual(try errorCode(product), "PRODUCT_UNAVAILABLE")
        let orders = try await orderCount(seed)
        XCTAssertEqual(orders, 0)
    }
}
