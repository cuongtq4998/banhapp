import XCTVapor
@testable import App

final class LookupSecurityTests: LookupRouteTestCase {
    private let allowed: Set<String> = [
        "order_code", "status", "placed_at", "phone_masked", "district_name", "requested_delivery_date", "slot_start_time",
        "slot_end_time", "expected_delivery_date", "items", "items_subtotal_vnd", "delivery_fee_estimate_vnd",
        "delivery_fee_final_vnd", "amount_to_collect_vnd",
    ]

    func testAnswerKeysAreExactlyTheAllowList() async throws {
        try await start()
        store.plant(normalised, [.sample(1)])
        try await lookup(#"{"phone":"\#(phone)"}"#) { res in
            XCTAssertEqual(res.status, .ok)
            // null fields are encoded too, so the full key set is comparable.
            XCTAssertEqual(try self.keys(res), self.allowed)
            XCTAssertTrue(res.body.string.contains("+84 900 000 ***"))
            XCTAssertFalse(res.body.string.contains(self.normalised))
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
        }
    }

    func testPhoneFormsGiveTheSameNumber() async throws {
        try await start()
        store.plant(normalised, [.sample(1)])
        for form in ["0900000001", "+84 900 000 001", "0900.000.001", " 0900000001 "] {
            try await lookup(#"{"phone":"\#(form)"}"#) { XCTAssertEqual(try self.keys($0), self.allowed, form) }
        }
    }

    func testInvalidPhoneIs422WithoutQuery() async throws {
        try await start()
        for (body, code) in [(#"{}"#, "PHONE_REQUIRED"), (#"{"phone":" "}"#, "PHONE_REQUIRED"), (#"{"phone":"123"}"#, "PHONE_INVALID")] {
            try await lookup(body) { res in
                XCTAssertEqual(res.status, .unprocessableEntity)
                XCTAssertTrue(res.body.string.contains(code))
            }
        }
        XCTAssertEqual(store.calls, 0)
    }

    func testGetIsRefused() async throws {
        try await start()
        let url = "v1/orders/lookup?phone=\(phone)"
        try await app.test(.GET, url, afterResponse: { res async throws in XCTAssertNotEqual(res.status, .ok) })
        XCTAssertEqual(store.calls, 0)
    }

    func testEmptyAndFullPhonesShareShape() async throws {
        try await start()
        store.plant(normalised, [.sample(1)])
        try await lookup(#"{"phone":"0900000002"}"#) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains(#""orders":[]"#))
            XCTAssertTrue(res.body.string.contains(#""next_cursor":null"#))
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
        }
    }

    func testCursorIsBoundToThePhoneAndTamperingFails() async throws {
        try await start()
        store.plant(normalised, (1...12).map { .sample($0) })
        var cursor = ""
        try await lookup(#"{"phone":"\#(phone)"}"#) { res in
            let answer = try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]
            XCTAssertEqual((answer?["orders"] as? [Any])?.count, 10)
            cursor = answer?["next_cursor"] as? String ?? ""
        }
        XCTAssertFalse(cursor.isEmpty)
        try await lookup(#"{"phone":"0900000002","cursor":"\#(cursor)"}"#) { XCTAssertTrue($0.body.string.contains("CURSOR_INVALID")) }
        try await lookup(#"{"phone":"\#(phone)","cursor":"\#(cursor)x"}"#) { XCTAssertEqual($0.status, .unprocessableEntity) }
        try await lookup(#"{"phone":"\#(phone)","cursor":"\#(cursor)"}"#) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains(#""next_cursor":null"#))
        }
    }

    func testRateLimitsAndIdentical429() async throws {
        var policy = LookupPolicy()
        policy.floorMilliseconds = 0
        policy.perPhonePerHour = 2
        try await start(policy: policy)
        store.plant(normalised, [.sample(1)])
        var refused: [String] = []
        for _ in 0..<3 { try await lookup(#"{"phone":"\#(phone)"}"#) { if $0.status == .tooManyRequests { refused.append($0.body.string) } } }
        try await lookup(#"{"phone":"0900000002"}"#) { XCTAssertEqual($0.status, .ok) }
        XCTAssertEqual(refused.count, 1)
        // The empty phone is refused in the same way once its budget is spent.
        for _ in 0..<2 { try await lookup(#"{"phone":"0900000002"}"#) { _ in } }
        try await lookup(#"{"phone":"0900000002"}"#) { res in
            XCTAssertEqual(res.status, .tooManyRequests)
            XCTAssertEqual(self.errorBody(res.body.string), self.errorBody(refused[0]))
            XCTAssertNotNil(res.headers.first(name: .retryAfter))
        }
    }

    private func errorBody(_ text: String) -> NSDictionary? {
        var object = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        object?["request_id"] = nil
        return object as NSDictionary?
    }

    func testLogsHoldNeitherPhoneNorCursor() async throws {
        var policy = LookupPolicy()
        policy.floorMilliseconds = 0
        policy.perPhonePerHour = 1
        try await start(policy: policy)
        let marker = "0900000077", cursorMarker = "CURSORMARKER"
        for body in [#"{"phone":"\#(marker)"}"#, #"{"phone":"\#(marker)"}"#, #"{"phone":"12\#(marker)","cursor":"\#(cursorMarker)"}"#] {
            try await lookup(body) { _ in }
        }
        let log = capture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        for needle in [marker, "900000077", cursorMarker] { XCTAssertFalse(log.contains(needle), needle) }
    }
}
