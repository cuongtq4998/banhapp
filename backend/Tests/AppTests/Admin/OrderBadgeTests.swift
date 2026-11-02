import XCTVapor
@testable import App

/// `unfinished_count` (FR-13): open orders whose list date is today or earlier.
final class OrderBadgeTests: AdminOrderTestCase {
    private func badge(_ phone: Phone, _ query: String = "") async throws -> Int {
        let reply = try await list(phone, query)
        return try XCTUnwrap(reply.json["unfinished_count"] as? Int)
    }

    private func open(_ status: String, date: String, expected: String? = nil) async throws {
        try await place(.init(status: status, date: date, expectedDate: expected, finalFee: status == "DeliveryStarted" ? 25_000 : nil))
    }

    func testOnlyOpenStepsCountAndFinishedAndCancelledNever() async throws {
        let staff = try await phone(.staff), due = day(-1)
        for status in ["Received", "Processing"] { try await open(status, date: due) }
        for status in ["DeliveryDateScheduled", "DeliveryStarted"] { try await open(status, date: due, expected: due) }
        try await place(.init(status: "Finished", date: due, expectedDate: due, finalFee: 25_000))
        try await place(.init(status: "Cancelled", date: due, reason: "customer_asked"))
        let total = try await badge(staff)
        XCTAssertEqual(total, 4)
    }

    func testListDateBoundariesYesterdayTodayTomorrow() async throws {
        let staff = try await phone(.staff)
        for (offset, counted) in [(-1, true), (0, true), (1, false)] {
            let before = try await badge(staff)
            try await open("Received", date: day(offset))
            let after = try await badge(staff)
            XCTAssertEqual(after - before, counted ? 1 : 0, "offset \(offset)")
        }
    }

    func testExpectedDateDecidesNotTheRequestedDate() async throws {
        let staff = try await phone(.staff)
        try await open("DeliveryDateScheduled", date: day(-3), expected: day(2))
        let later = try await badge(staff)
        XCTAssertEqual(later, 0, "requested date due, expected date later")
        try await open("DeliveryDateScheduled", date: day(5), expected: day(0))
        let earlier = try await badge(staff)
        XCTAssertEqual(earlier, 1, "requested date later, expected date today")
    }

    func testFiltersSearchAndTheNinetyDayWindowDoNotChangeTheBadge() async throws {
        let staff = try await phone(.staff), now = clock.now()
        try await open("Received", date: day(0))
        try await place(.init(status: "Processing", date: day(-200), placed: now.addingTimeInterval(-120 * 86_400)))
        try await place(.init(status: "Finished", date: day(-1), placed: now.addingTimeInterval(-3_600)))
        for query in ["", "status=Finished", "status=Cancelled", "date_preset=tomorrow", "delivery_date=\(day(30))", "q=Tran", "q=zzzz"] {
            let total = try await badge(staff, query)
            XCTAssertEqual(total, 2, query)
        }
    }
}
