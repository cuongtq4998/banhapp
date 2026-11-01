import XCTVapor
@testable import App

/// TC-B64 to TC-B67 (BR-9): open orders of any age, finished orders for 90 days
/// after they were placed (exactly 90 days still shown), one rule everywhere.
final class OrderWindowTests: AdminOrderTestCase {
    private let day90: TimeInterval = 90 * 86_400

    private func finished(_ status: String, age: TimeInterval, name: String = "Tran Thi B") async throws -> String {
        try await place(.init(status: status, date: day(-1), placed: clock.now().addingTimeInterval(-age), name: name,
                              reason: status == "Cancelled" ? "customer_asked" : nil))
    }

    func testFinishedOrdersStayNinetyDaysFromThePlacedTimeInclusive() async throws {
        let ages: [(TimeInterval, Bool)] = [(89 * 86_400, true), (day90 - 1, true), (day90, true), (day90 + 1, false), (91 * 86_400, false)]
        // Sign in first: signing in moves the clock, and the boundary is measured against it.
        let staff = try await phone(.staff), owner = try await phone(.owner, "Chu Mau")
        var expected: [String: Bool] = [:]
        for (age, shown) in ages { expected[try await finished("Completed", age: age)] = shown }
        for who in [staff, owner] {
            let listed = Set(try await listCodes(who, "status=all"))
            let searched = Set(try await listCodes(who, "q=BT-&status=Completed"))
            for (orderCode, shown) in expected {
                XCTAssertEqual(listed.contains(orderCode), shown, orderCode)
                XCTAssertEqual(searched.contains(orderCode), shown, orderCode)
                let reply = try await detail(who, orderCode)
                XCTAssertEqual(reply.status, shown ? .ok : .notFound, orderCode)
                if !shown { XCTAssertEqual(reply.errorCode, "ORDER_NOT_FOUND") }
            }
        }
    }

    func testAnOldFinishedOrderAnswersLikeAnUnknownCode() async throws {
        let old = try await finished("Cancelled", age: 91 * 86_400)
        let staff = try await phone(.staff)
        let hidden = try await detail(staff, old), unknown = try await detail(staff, code(99_999_999))
        XCTAssertEqual(hidden.status, unknown.status)
        XCTAssertEqual(hidden.json["error"] as? NSDictionary, unknown.json["error"] as? NSDictionary)
        let malformed = try await detail(staff, "bt-aaaaaa")
        XCTAssertEqual(malformed.errorCode, "ORDER_NOT_FOUND")
    }

    func testAnOpenOrderOfAnyAgeIsListedSearchedAndOpened() async throws {
        let now = clock.now()
        let old = try await place(.init(status: "New", date: day(-75), placed: now.addingTimeInterval(-100 * 86_400), name: "Nguyen Van Cu"))
        let confirmed = try await place(.init(status: "Confirmed", date: day(-60), placed: now.addingTimeInterval(-200 * 86_400)))
        let staff = try await phone(.staff)
        let listed = try await listCodes(staff)
        XCTAssertEqual(listed, [old, confirmed])
        try await expectCodes(staff, "q=nguyen", [old])
        for orderCode in [old, confirmed] {
            let reply = try await detail(staff, orderCode)
            XCTAssertEqual(reply.status, .ok)
        }
    }

    func testDemoRowsAreInvisibleToRealAccountsAndTheOnlyOnesForReviewAccounts() async throws {
        let real = try await place(), demo = try await place(.init(demo: true))
        let staff = try await phone(.staff)
        try await expectCodes(staff, [real])
        let hidden = try await detail(staff, demo)
        XCTAssertEqual(hidden.status, .notFound)
        let reviewer = try await phone(.staff, "Reviewer")
        try await run("UPDATE account SET kind = 'review' WHERE id = (SELECT account_id FROM device_session WHERE id = \(bind: reviewer.deviceID))")
        try await expectCodes(reviewer, [demo])
        let other = try await detail(reviewer, real)
        XCTAssertEqual(other.status, .notFound)
        let own = try await detail(reviewer, demo)
        XCTAssertEqual(own.status, .ok)
    }

    func testBadgeCountsOpenOrdersDueTodayOrEarlierIgnoringFiltersAndTheWindow() async throws {
        let now = clock.now()
        try await place(.init(status: "New", date: day(-2)))
        try await place(.init(status: "Confirmed", date: day(0)))
        try await place(.init(status: "New", date: day(-75), placed: now.addingTimeInterval(-100 * 86_400)))
        try await place(.init(status: "New", date: day(1)))
        try await place(.init(status: "Completed", date: day(-2)))
        try await place(.init(status: "New", date: day(-2), demo: true))
        let staff = try await phone(.staff), owner = try await phone(.owner, "Chu Mau")
        for query in ["", "status=Completed", "date_preset=tomorrow", "q=tran", "q=zzz"] {
            for who in [staff, owner] {
                let reply = try await list(who, query)
                XCTAssertEqual(reply.json["unfinished_count"] as? Int, 3, query)
            }
        }
    }

    func testBadgeIsZeroWithNothingDueAndGrowsPastOneHundredAsANumber() async throws {
        let staff = try await phone(.staff)
        let empty = try await list(staff)
        XCTAssertEqual(empty.json["unfinished_count"] as? Int, 0)
        try await place(.init(status: "New", date: day(5)))
        let none = try await list(staff)
        XCTAssertEqual(none.json["unfinished_count"] as? Int, 0)
        try await run("""
            INSERT INTO customer_order (shop_id, order_code, delivery_date, slot_id, slot_start_time, slot_end_time, district_id, district_name,
                delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes, customer_name, customer_phone, customer_address,
                idempotency_key, request_hash, client_platform, app_version)
            SELECT shop_id, 'BT-' || translate(upper(substr(md5(random()::text || g::text), 1, 6)), '01', 'AB'), \(bind: day(0))::date, slot_id, slot_start_time, slot_end_time, district_id,
                district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes, customer_name, customer_phone, customer_address,
                gen_random_uuid(), request_hash, client_platform, app_version
            FROM customer_order, generate_series(1, 120) g WHERE shop_id = \(bind: shopID) LIMIT 120
            """)
        let many = try await list(staff)
        XCTAssertEqual(many.json["unfinished_count"] as? Int, 120)
    }

    func testDueAndOverdueFollowTheShopDateAndFlipAtMidnightInUTCPlus7() async throws {
        let before = Date(timeIntervalSince1970: 1794329999) // 2026-11-10T16:59:59Z
        let staff = try await phone(.staff, now: before)
        XCTAssertEqual(today.description, "2026-11-10")
        try await place(.init(status: "New", date: "2026-11-10"))
        try await place(.init(status: "New", date: "2026-11-11"))
        let evening = try await list(staff)
        XCTAssertEqual(evening.string("server_date"), "2026-11-10")
        XCTAssertEqual(evening.json["unfinished_count"] as? Int, 1)
        clock.advance(1) // 17:00:00Z is 00:00 on 11 November in Vietnam
        let midnight = try await list(staff)
        XCTAssertEqual(midnight.string("server_date"), "2026-11-11")
        XCTAssertEqual(midnight.json["unfinished_count"] as? Int, 2)
        let presets = try await listCodes(staff, "date_preset=today")
        XCTAssertEqual(presets.count, 1)
    }
}
