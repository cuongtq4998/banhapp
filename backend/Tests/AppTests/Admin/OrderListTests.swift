import XCTVapor
@testable import App

/// TC-B49 to TC-B58: the To do list, sort, row fields, status and date filters.
final class OrderListTests: AdminOrderTestCase {
    func testDefaultListHoldsOpenOrdersOfAnyAgeSortedByDateSlotPlacedTime() async throws {
        let now = clock.now()
        let a = try await place(.init(status: "Received", date: day(2)))
        let b = try await place(.init(status: "Processing", date: day(1), placed: now.addingTimeInterval(-600)))
        let c = try await place(.init(status: "Finished", date: day(1)))
        let d = try await place(.init(status: "Received", date: day(1), placed: now.addingTimeInterval(-7_200)))
        let staff = try await phone(.staff)
        let reply = try await list(staff)
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(codes(reply), [d, b, a])
        XCTAssertFalse(codes(reply).contains(c))
        XCTAssertEqual(reply.headers.first(name: .cacheControl), "no-store")
    }

    func testSortKeysAreDateThenSlotStartThenPlacedTimeThenCode() async throws {
        let now = clock.now(), date = day(2)
        let late = try await place(.init(date: date, slot: "10:00", placed: now.addingTimeInterval(-9_000)))
        let second = try await place(.init(date: date, slot: "08:00", placed: now.addingTimeInterval(-60)))
        let first = try await place(.init(date: date, slot: "08:00", placed: now.addingTimeInterval(-600)))
        let earlier = try await place(.init(date: day(1), slot: "10:00"))
        let staff = try await phone(.staff)
        let order = try await listCodes(staff)
        XCTAssertEqual(order, [earlier, first, second, late])
        let again = try await listCodes(staff)
        XCTAssertEqual(order, again)
    }

    func testSameDateSlotAndTimeBreaksTheTieByIdSoPagesAreStable() async throws {
        let at = clock.now().addingTimeInterval(-60)
        for _ in 0..<5 { try await place(.init(placed: at)) }
        let staff = try await phone(.staff)
        let first = try await listCodes(staff), second = try await listCodes(staff)
        XCTAssertEqual(first.count, 5)
        XCTAssertEqual(first, second)
    }

    func testRowHasListFieldsAndNoPhoneAddressOrNote() async throws {
        let orderCode = try await place(.init(date: "2031-05-04", cakes: 3, name: "Trần Thị Bé"))
        let staff = try await phone(.staff)
        let reply = try await list(staff)
        let row = try XCTUnwrap((reply.json["items"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(row.keys), ["order_code", "status", "customer_name", "delivery_date", "expected_delivery_date", "list_date", "slot", "total_cakes", "total_vnd", "district_name", "created_at"])
        XCTAssertEqual(row["order_code"] as? String, orderCode)
        XCTAssertEqual(row["customer_name"] as? String, "Trần Thị Bé")
        XCTAssertEqual(row["delivery_date"] as? String, "2031-05-04")
        XCTAssertEqual(row["slot"] as? [String: String], ["start": "08:00", "end": "10:00"])
        XCTAssertEqual(row["total_cakes"] as? Int, 3)
        XCTAssertEqual(row["total_vnd"] as? Int, 170_000)
        XCTAssertEqual(row["district_name"] as? String, "Quan An Phu")
        XCTAssertEqual((row["created_at"] as? String)?.count, 20)
        let text = String(decoding: reply.data, as: UTF8.self)
        XCTAssertFalse(text.contains("+84900000010") || text.contains("1 Test Street") || text.contains("Ít đường"))
        XCTAssertTrue(reply.json.keys.contains("next_cursor"))
        XCTAssertTrue(reply.json["next_cursor"] is NSNull)
    }

    func testEachStatusFilterIsExactAndAllHoldsTheFourStatuses() async throws {
        var byStatus: [String: String] = [:]
        for status in ["Received", "Processing", "Finished", "Cancelled"] {
            byStatus[status] = try await place(.init(status: status, reason: status == "Cancelled" ? "customer_asked" : nil))
        }
        let staff = try await phone(.staff)
        let todo = Set(try await listCodes(staff, "status=todo"))
        XCTAssertEqual(todo, [byStatus["Received"]!, byStatus["Processing"]!])
        for status in byStatus.keys {
            try await expectCodes(staff, "status=\(status)", [byStatus[status]!])
        }
        let all = Set(try await listCodes(staff, "status=all"))
        XCTAssertEqual(all, Set(byStatus.values))
    }

    func testDeliveryDateFilters() async throws {
        let todayOrder = try await place(.init(date: day(0)))
        let tomorrowOrder = try await place(.init(date: day(1)))
        let later = try await place(.init(date: "2031-11-05"))
        let staff = try await phone(.staff)
        try await expectCodes(staff, "date_preset=today", [todayOrder])
        try await expectCodes(staff, "date_preset=tomorrow", [tomorrowOrder])
        try await expectCodes(staff, "delivery_date=2031-11-05", [later])
        try await expectCodes(staff, "delivery_date=2099-01-01", [])
        try await expectCodes(staff, "delivery_date=1999-01-01", [])
    }

    func testInvalidParametersAreRefusedWithTheFieldName() async throws {
        let staff = try await phone(.staff)
        let cases: [(String, String)] = [
            ("status=Pending", "status"), ("status=New&status=Cancelled", "status"), ("status=New,Cancelled", "status"),
            ("view=unfinished", "view"), ("date_from=2026-11-01", "date_from"), ("date_to=2026-11-01", "date_to"),
            ("date_preset=yesterday", "date_preset"), ("date_preset=today&delivery_date=2026-11-01", "delivery_date"),
            ("delivery_date=01/11/2026", "delivery_date"), ("delivery_date=2026-02-31", "delivery_date"),
            ("limit=1000", "limit"), ("cursor=forged", "cursor"), ("status=", "status"), ("q=ab", "q"), ("q=09", "q")
        ]
        for (query, field) in cases {
            let reply = try await list(staff, query)
            XCTAssertEqual(reply.status, .unprocessableEntity, query)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", query)
            let fields = ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]])?.compactMap { $0["field"] as? String }
            XCTAssertEqual(fields?.first, field, query)
        }
    }

    func testListNeedsASessionAndBothRolesSeeTheSameOrders() async throws {
        let orderCode = try await place()
        let unsigned = try await send(.GET, "v1/admin/orders")
        XCTAssertEqual(unsigned.status, .unauthorized)
        let staff = try await phone(.staff), owner = try await phone(.owner, "Chu Mau")
        try await expectCodes(staff, [orderCode])
        try await expectCodes(owner, [orderCode])
    }
}
