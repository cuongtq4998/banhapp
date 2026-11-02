import XCTVapor
@testable import App

final class LookupDatabaseTests: LookupDatabaseTestCase {
    override func setUp() async throws {
        try await super.setUp()
        applyPolicy()
    }

    func testNewestFirstAndFormattedFields() async throws {
        let older = try await seed { $0.placed = self.clock.now().addingTimeInterval(-7_200) }
        let newer = try await seed { $0.expectedDate = self.day(5); $0.status = "DeliveryDateScheduled" }
        let reply = try await lookup()
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(lookedUp(reply), [newer, older])
        let first = try XCTUnwrap((reply.json["orders"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["requested_delivery_date"] as? String, day(3))
        XCTAssertEqual(first["expected_delivery_date"] as? String, day(5))
        XCTAssertEqual(first["slot_start_time"] as? String, "08:00")
        XCTAssertEqual(first["slot_end_time"] as? String, "10:00")
        XCTAssertEqual((first["items"] as? [[String: Any]])?.count, 1)
    }

    func testItemsAreOrderedByNameThenProduct() async throws {
        let code = try await seed()
        for (index, name) in ["Zed cake", "Aaa cake"].enumerated() {
            let extra = UUID()
            try await run("INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path) VALUES (\(bind: extra), \(bind: shopID), \(bind: "extra-\(index)"), \(bind: name), 'x', 10000, 'images/banana.png')")
            try await run("""
                INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd)
                SELECT id, \(bind: extra), \(bind: name), 10000, 1, 10000 FROM customer_order WHERE order_code = \(bind: code)
                """)
        }
        let reply = try await lookup()
        let items = try XCTUnwrap((reply.json["orders"] as? [[String: Any]])?.first?["items"] as? [[String: Any]])
        XCTAssertEqual(items.compactMap { $0["cake_name"] as? String }, ["Aaa cake", "Banh Mau", "Zed cake"])
    }

    func testOtherPhonesAreNeverShown() async throws {
        _ = try await seed { $0.phone = "+84909999999" }
        try await expectLookup([])
    }

    func testOpenOrderShowsAtAnyAge() async throws {
        let code = try await seed { $0.status = "Processing" }
        try await setStatusAge(code, secondsAgo: 400 * 86_400)
        try await expectLookup([code])
    }

    func testClosedOrderWindowEdge() async throws {
        let inside = try await seed { $0.status = "Cancelled"; $0.reason = "customer_asked" }
        let outside = try await seed { $0.status = "Finished"; $0.expectedDate = self.day(3); $0.finalFee = 20_000 }
        let edge = policy.retention
        try await setStatusAge(inside, secondsAgo: edge - 1)
        try await setStatusAge(outside, secondsAgo: edge + 1)
        try await expectLookup([inside])
    }

    /// Pins the current rule (kept at exactly 30 x 24 hours); change when the atlas decides.
    func testPinnedWindowEdgeExactlyAtRetentionIsShown() async throws {
        let code = try await seed { $0.status = "Cancelled"; $0.reason = "customer_asked" }
        try await setStatusAge(code, secondsAgo: policy.retention)
        try await expectLookup([code])
    }

    func testEqualPlacedTimesPageWithoutLossOrRepeat() async throws {
        let same = clock.now().addingTimeInterval(-3_600.123_456)
        var expected: [String] = []
        for _ in 0..<3 { expected.append(try await seed { $0.placed = same }) }
        policy.pageSize = 1
        applyPolicy()
        var seen: [String] = [], cursor: String?
        for _ in 0..<5 {
            let reply = try await lookup(cursor: cursor)
            seen += lookedUp(reply)
            cursor = nextCursor(reply)
            if cursor == nil { break }
        }
        XCTAssertEqual(seen.count, 3)
        XCTAssertEqual(Set(seen), Set(expected))
    }
}
