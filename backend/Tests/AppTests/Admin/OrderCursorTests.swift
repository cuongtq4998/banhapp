import XCTVapor
@testable import App

/// The list cursor: four keys, other filters, damaged and old-shaped tokens.
final class OrderCursorTests: AdminOrderTestCase {
    private func firstCursor(_ staff: Phone, _ query: String = "") async throws -> String {
        let reply = try await list(staff, query)
        return try XCTUnwrap(reply.json["next_cursor"] as? String)
    }

    private func seedPage() async throws -> Phone {
        for index in 0..<51 { try await place(.init(date: day(1 + index))) }
        // One order whose expected date moves it past the requested date sort position.
        try await place(.init(status: "DeliveryDateScheduled", date: day(1), expectedDate: day(60)))
        return try await phone(.staff)
    }

    private func refusal(_ reply: Reply) -> String? {
        ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]])?.first?["code"] as? String
    }

    func testCursorHoldsTheFourSortKeysOfTheLastRowWithListDateFirst() async throws {
        let staff = try await seedPage()
        let page = try await list(staff)
        let last = try XCTUnwrap((page.json["items"] as? [[String: Any]])?.last)
        let token = try XCTUnwrap(page.json["next_cursor"] as? String), cursor = try XCTUnwrap(OrderCursor(token: token))
        XCTAssertEqual(cursor.listDate, last["list_date"] as? String)
        XCTAssertEqual(cursor.slotStart, "08:00:00")
        XCTAssertEqual(cursor.createdAt.count, 27)
        XCTAssertNotNil(UUID(uuidString: cursor.id))
        XCTAssertEqual(OrderCursor(token: cursor.token), cursor)
    }

    func testCursorFromAnotherFilterIsAPositionNotAnError() async throws {
        let staff = try await seedPage()
        let cursor = try await firstCursor(staff)
        let other = try await list(staff, "status=Received&cursor=\(cursor)")
        XCTAssertEqual(other.status, .ok)
        let position = try XCTUnwrap(OrderCursor(token: cursor)).listDate
        let dates = (other.json["items"] as? [[String: Any]] ?? []).compactMap { $0["list_date"] as? String }
        XCTAssertTrue(dates.allSatisfy { $0 >= position })
        let search = try await list(staff, "q=Tran&cursor=\(cursor)")
        XCTAssertEqual(search.status, .ok)
    }

    func testMalformedAndTamperedCursorsAreRefusedWithCursorInvalid() async throws {
        let staff = try await seedPage()
        let token = try await firstCursor(staff), good = try XCTUnwrap(OrderCursor(token: token))
        func encode(_ text: String) -> String { OrderCursor(listDate: "", slotStart: "", createdAt: "", id: "").tokenFor(text) }
        let bad = ["", "abc", "!!!!", encode("only|three|parts"), encode("2026-13-01|08:00:00|\(good.createdAt)|\(good.id)"),
                   encode("\(good.listDate)|8:00|\(good.createdAt)|\(good.id)"), encode("\(good.listDate)|08:00:00|yesterday|\(good.id)"),
                   encode("\(good.listDate)|08:00:00|\(good.createdAt)|not-a-uuid"), encode("\(good.listDate)|08:00:00|\(good.createdAt)|\(good.id)|extra"),
                   String(good.token.dropLast(3)) + "!!!"]
        for bogus in bad {
            let reply = try await list(staff, "cursor=\(bogus)")
            XCTAssertEqual(reply.status, .unprocessableEntity, bogus)
            XCTAssertEqual(refusal(reply), "CURSOR_INVALID", bogus)
        }
        let injected = try await list(staff, "cursor=\(encode("\(good.listDate)|08:00:00|\(good.createdAt)|\(good.id)' OR 1=1"))")
        XCTAssertEqual(injected.status, .unprocessableEntity)
    }

    /// Open decision: a version marker for cursors. Until it is decided an
    /// old cursor (requested date first) has the same shape and is accepted.
    func testKnownGapCursorVersionMarkerOldShapedCursorIsAccepted() async throws {
        let staff = try await seedPage()
        let token = try await firstCursor(staff), current = try XCTUnwrap(OrderCursor(token: token))
        let old = OrderCursor(listDate: day(2), slotStart: current.slotStart, createdAt: current.createdAt, id: current.id)
        let reply = try await list(staff, "cursor=\(old.token)")
        XCTAssertEqual(reply.status, .ok, "change to 422 when the marker is decided")
    }
}

private extension OrderCursor {
    /// Encodes any text the way `token` does, to build damaged tokens.
    func tokenFor(_ text: String) -> String {
        Data(text.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
