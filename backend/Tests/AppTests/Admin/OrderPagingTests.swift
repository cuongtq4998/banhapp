import XCTVapor
@testable import App

/// TC-B69 to TC-B72 (ADR-0029): 50 rows a page, keyset cursor, no duplicate and
/// no gap while orders arrive, old open orders first across the window boundary.
final class OrderPagingTests: AdminOrderTestCase {
    private func allPages(_ phone: Phone, _ query: String = "") async throws -> [[String]] {
        var pages: [[String]] = [], cursor: String?
        repeat {
            var q = query
            if let cursor { q += (q.isEmpty ? "" : "&") + "cursor=\(cursor)" }
            let reply = try await list(phone, q)
            XCTAssertEqual(reply.status, .ok)
            pages.append(codes(reply))
            cursor = reply.json["next_cursor"] as? String
        } while cursor != nil && pages.count < 10
        return pages
    }

    func testOneHundredTwentyOrdersComeAs50And50And20WithoutRepeatOrGap() async throws {
        var expected: [String] = []
        for index in 0..<120 {
            // Three orders share every date and slot, so the later sort keys decide.
            expected.append(try await place(.init(date: day(1 + index / 3), slot: index % 2 == 0 ? "08:00" : "10:00", placed: clock.now().addingTimeInterval(-TimeInterval(index)))))
        }
        let staff = try await phone(.staff)
        let pages = try await allPages(staff)
        XCTAssertEqual(pages.map(\.count), [50, 50, 20])
        let flat = pages.flatMap { $0 }
        XCTAssertEqual(Set(flat), Set(expected))
        XCTAssertEqual(flat.count, 120)
        let once = try await listCodes(staff)
        XCTAssertEqual(once, pages[0])
    }

    func testExactlyOnePageHasNoCursorAndFiftyOneHasOne() async throws {
        for index in 0..<50 { try await place(.init(date: day(1 + index))) }
        let staff = try await phone(.staff)
        let full = try await list(staff)
        XCTAssertEqual(codes(full).count, 50)
        XCTAssertTrue(full.json["next_cursor"] is NSNull)
        try await place(.init(date: day(99)))
        let more = try await list(staff)
        XCTAssertNotNil(more.json["next_cursor"] as? String)
        let rest = try await allPages(staff)
        XCTAssertEqual(rest.map(\.count), [50, 1])
    }

    func testNewAndStatusChangedOrdersBetweenPagesNeverRepeatARow() async throws {
        for index in 0..<60 { try await place(.init(date: day(1 + index))) }
        let staff = try await phone(.staff)
        let first = try await list(staff)
        let seen = Set(codes(first))
        let cursor = try XCTUnwrap(first.json["next_cursor"] as? String)
        let lastShown = try XCTUnwrap(codes(first).last)
        // A new order sorting before page 1, one after it, and an unfetched order leaving the filter.
        let early = try await place(.init(date: day(0)))
        let late = try await place(.init(date: day(200)))
        let leaving = try await place(.init(date: day(59)))
        try await run("UPDATE customer_order SET status = 'Cancelled', cancel_reason = 'customer_asked' WHERE order_code = \(bind: leaving)")
        let second = try await list(staff, "cursor=\(cursor)")
        let next = codes(second)
        XCTAssertTrue(seen.isDisjoint(with: next))
        XCTAssertFalse(next.contains(early))
        XCTAssertFalse(next.contains(leaving))
        XCTAssertTrue(next.contains(late))
        XCTAssertFalse(next.contains(lastShown))
        let refreshed = try await listCodes(staff)
        XCTAssertEqual(refreshed.first, early)
    }

    func testOldOpenOrdersSortFirstAndPagingCrossesTheWindowBoundary() async throws {
        let now = clock.now()
        var old: [String] = []
        for index in 0..<60 {
            old.append(try await place(.init(date: day(-150 + index), placed: now.addingTimeInterval(-120 * 86_400))))
            try await place(.init(date: day(index / 4), placed: now.addingTimeInterval(-3_600)))
        }
        let staff = try await phone(.staff)
        let pages = try await allPages(staff)
        XCTAssertEqual(pages.map(\.count), [50, 50, 20])
        let flat = pages.flatMap { $0 }
        XCTAssertEqual(Array(flat.prefix(60)), old)
        XCTAssertEqual(Set(flat).count, 120)
    }

    func testACursorKeepsWorkingWithFiltersAndOtherAccountsGetTheSameRows() async throws {
        for index in 0..<55 { try await place(.init(status: index % 2 == 0 ? "New" : "Confirmed", date: day(1 + index))) }
        let staff = try await phone(.staff), owner = try await phone(.owner, "Chu Mau")
        let pages = try await allPages(staff, "status=New")
        XCTAssertEqual(pages.map(\.count), [28])
        let first = try await list(staff)
        let cursor = try XCTUnwrap(first.json["next_cursor"] as? String)
        let theirs = try await list(owner, "cursor=\(cursor)")
        let mine = try await list(staff, "cursor=\(cursor)")
        XCTAssertEqual(codes(theirs), codes(mine))
        XCTAssertEqual(codes(mine).count, 5)
    }
}
