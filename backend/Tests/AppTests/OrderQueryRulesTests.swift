import XCTest
import BanhContracts
@testable import App

/// The pure rules of the admin order endpoints: no database, no HTTP.
final class OrderQueryRulesTests: XCTestCase {
    // 2026-11-10T16:59:59Z is still 10 November in Vietnam.
    private let calendar = ShopCalendar(clock: FixedWallClock(instant: Date(timeIntervalSince1970: 1794329999)))

    private func parse(_ query: String) throws -> OrderListQuery {
        try OrderListQuery.parse(OrderListQuery.pairs(of: query), calendar: calendar)
    }

    func testNoParametersMeansTheTodoListWithNoFilters() throws {
        let query = try parse("")
        XCTAssertEqual(query.status, .todo)
        XCTAssertNil(query.deliveryDate)
        XCTAssertNil(query.search)
        XCTAssertNil(query.cursor)
        XCTAssertEqual(query.status.statuses, [.new, .confirmed])
        XCTAssertNil(OrderListQuery.StatusFilter.all.statuses)
    }

    func testPresetsUseTheShopDate() throws {
        XCTAssertEqual(try parse("date_preset=today").deliveryDate?.description, "2026-11-10")
        XCTAssertEqual(try parse("date_preset=tomorrow").deliveryDate?.description, "2026-11-11")
        XCTAssertEqual(try parse("delivery_date=2026-12-31").deliveryDate?.description, "2026-12-31")
    }

    func testEveryDefectIsAValidationErrorNamingTheParameter() {
        for query in ["status=x", "status=New&status=New", "view=unfinished", "date_preset=now", "delivery_date=2026-13-01", "delivery_date=2026-02-30",
                      "date_preset=today&delivery_date=2026-11-10", "cursor=abc", "q=ab", "q=%20%20%20%20"] {
            XCTAssertThrowsError(try parse(query), query) { error in
                XCTAssertEqual((error as? APIError)?.code, .validationFailed, query)
            }
        }
    }

    func testPairsDecodePercentEscapesAndPlusAsSpace() {
        let pairs = OrderListQuery.pairs(of: "q=a+b%2Bc&status")
        XCTAssertEqual(pairs.map(\.0), ["q", "status"])
        XCTAssertEqual(pairs.map(\.1), ["a b+c", ""])
    }

    func testCursorRoundTripsAndRejectsForgeries() throws {
        let cursor = OrderCursor(deliveryDate: "2026-11-10", slotStart: "08:00:00", createdAt: "2026-11-01T03:00:00.123456Z", id: UUID().uuidString.lowercased())
        XCTAssertEqual(OrderCursor(token: cursor.token), cursor)
        XCTAssertFalse(cursor.token.contains("=") || cursor.token.contains("+") || cursor.token.contains("/"))
        for token in ["", "!!!", Data("a|b|c|d".utf8).base64EncodedString(), Data("2026-11-10|08:00:00|x|y".utf8).base64EncodedString(),
                      Data("2026-13-10|08:00:00|2026-11-01T03:00:00.123456Z|\(UUID())".utf8).base64EncodedString()] {
            XCTAssertNil(OrderCursor(token: token), token)
        }
    }

    func testSearchRules() {
        XCTAssertNil(OrderSearch("ab"))
        XCTAssertNotNil(OrderSearch("abc"))
        XCTAssertNil(OrderSearch(String(repeating: "x", count: 51)))
        XCTAssertNotNil(OrderSearch(String(repeating: "x", count: 50)))
        XCTAssertNil(OrderSearch("09"))
        XCTAssertNil(OrderSearch("+-8"))
        XCTAssertNil(OrderSearch("ab\u{0}c"))
        XCTAssertEqual(OrderSearch("0900 000-010")?.phoneDigits, "84900000010")
        XCTAssertEqual(OrderSearch("+84 900 000 010")?.phoneDigits, "84900000010")
        XCTAssertNil(OrderSearch("tran")?.phoneDigits)
        XCTAssertEqual(OrderSearch("Tra\u{0302}\u{0300}n")?.text, "Trần")
    }

    func testStatusRequestChecksFieldsReasonAndPair() throws {
        func body(_ json: String) throws -> [String: JSONValue] {
            try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
        }
        let ok = try StatusRequest.parse(body(#"{"expected_status":"New","to_status":"Cancelled","cancel_reason":"fake_spam"}"#))
        XCTAssertEqual(ok, StatusRequest(expected: .new, target: .cancelled, reason: .fakeSpam))
        let cases: [(String, APIErrorCode)] = [
            (#"{"expected_status":"New","to_status":"Cancelled"}"#, .cancelReasonRequired),
            (#"{"expected_status":"New","to_status":"Cancelled","cancel_reason":"day_full"}"#, .cancelReasonRequired),
            (#"{"expected_status":"New","to_status":"Confirmed","cancel_reason":"fake_spam"}"#, .validationFailed),
            (#"{"expected_status":"New","to_status":"Completed"}"#, .statusTransitionInvalid),
            (#"{"expected_status":"Completed","to_status":"Cancelled","cancel_reason":"fake_spam"}"#, .statusTransitionInvalid),
            (#"{"expected_status":"New","to_status":"Confirmed","x":1}"#, .validationFailed),
            (#"{"expected_status":"Nope","to_status":"Confirmed"}"#, .validationFailed)
        ]
        for (json, code) in cases {
            XCTAssertThrowsError(try StatusRequest.parse(body(json)), json) { XCTAssertEqual(($0 as? APIError)?.code, code, json) }
        }
    }

    func testTransitionTableMatchesBR2() {
        var allowed = 0
        for from in OrderStatus.allCases { for to in OrderStatus.allCases where from.canMove(to: to) { allowed += 1 } }
        XCTAssertEqual(allowed, 4)
        XCTAssertEqual(CancelReason.allCases.count, 4)
        XCTAssertTrue(OrderStatus.completed.allowedActions.isEmpty && OrderStatus.cancelled.allowedActions.isEmpty)
    }
}
