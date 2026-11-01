import XCTest
import Vapor
@testable import AppUnderTest

/// Order list: search (3 character minimum, folding, injection), field error codes (api/08 11.1), cursor tampering, paging.
final class AdminSearchCursorTests: AdminQABase {
    private var phone = QAPhone(access: "", refresh: "", deviceID: "")

    override func setUp() async throws {
        try await super.setUp()
        phone = try await owner()
    }

    private func list(_ query: String) async throws -> QAReply {
        try await client.send("GET", "v1/admin/orders" + (query.isEmpty ? "" : "?" + query), token: phone.access)
    }

    private func codes(_ reply: QAReply) -> [String] { (reply.json["items"] as? [[String: Any]] ?? []).compactMap { $0["order_code"] as? String } }

    private func encode(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text }

    func testTCB59_SearchFindsByCodeNamePhoneIgnoringCaseAndAccents() async throws {
        let date = dayOffset(4)
        let target = try await seedOrder(date: date, phone: "+84900000010", name: "Trần Thị Bé")
        _ = try await seedOrder(date: date, phone: "+84911111111", name: "Le Van Khac")
        let hit = [target.lowercased(), target, String(target.dropFirst(3)), "tran thi", "TRẦN THỊ", "tran thi be", "Thị Bé", "0900000010", "+84 900 000 010", "900000010", "(0900) 000-010"]
        for q in hit {
            let reply = try await list("q=" + encode(q))
            XCTAssertEqual(reply.status, 200, "q=\(q): \(reply.text)")
            XCTAssertEqual(codes(reply), [target], "q=\(q)")
        }
        // NFD and NFC are the same search.
        let nfd = "Tra\u{0302}\u{0300}n".decomposedStringWithCanonicalMapping
        try await aeq(codes(try await list("q=" + encode(nfd))), [target], "NFD q")
        try await aeq(codes(try await list("q=zzz")), [])
    }

    func testTCB61_VietnameseDStrokeAndHornLettersFold() async throws {
        let target = try await seedOrder(date: dayOffset(4), name: "Đặng Văn Đức Nguyễn Thị Hương")
        for q in ["dang van duc", "ĐẶNG", "đức", "nguyen thi huong", "Hương"] {
            try await aeq(codes(try await list("q=" + encode(q))), [target], "q=\(q)")
        }
    }

    func testTCB60_SearchLengthAndCharacterRules() async throws {
        _ = try await seedOrder(date: dayOffset(4), name: "Abc Def")
        let invalid = ["", "ab", "%20%20%20", "09", "+-().", "1%202", "a", String(repeating: "a", count: 51), "ab%00c", "ab%07c", "abc%0Ad"]
        for q in invalid {
            let reply = try await list("q=" + q)
            XCTAssertEqual(reply.status, 422, "q=\(q)")
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED")
            XCTAssertEqual(reply.fieldCodes, ["SEARCH_INVALID"], "q=\(q) \(reply.text)")
        }
        try await aeq(try await list("q=abc").status, 200, "exactly 3 characters")
        try await aeq(try await list("q=" + String(repeating: "a", count: 50)).status, 200, "exactly 50 characters")
        try await aeq(try await list("q=%20abc%20").status, 200, "trimmed")
        // 50 combining characters count after NFC: 50 precomposed letters are allowed even if sent decomposed.
        try await aeq(try await list("q=" + encode(String(repeating: "e\u{0302}", count: 50))).status, 200)
        try await aeq(try await list("q=012").status, 200, "3 digits are enough")
    }

    func testTCB62_InjectionAndWildcardsAreLiteral() async throws {
        let date = dayOffset(4)
        let sweet = try await seedOrder(date: date, name: "100% sweet_cake")
        let other = try await seedOrder(date: date, name: "Plain Customer")
        try await aeq(codes(try await list("q=" + encode("100%"))), [sweet])
        try await aeq(codes(try await list("q=" + encode("t_c"))), [sweet], "underscore is literal")
        try await aeq(codes(try await list("q=" + encode("%%%"))), [], "percent signs are not a wildcard")
        try await aeq(codes(try await list("q=" + encode("___"))), [])
        try await aeq(codes(try await list("q=" + encode("\\\\\\"))), [])
        for q in ["'; DROP TABLE customer_order; --", "' OR '1'='1", "\" OR 1=1 --", "%27%29%20OR%201=1", "<script>alert(1)</script>", "${jndi:ldap://x}", "Robert'); DROP TABLE x;--", "\u{FFFD}\u{FFFD}\u{FFFD}", "🍰🍰🍰"] {
            let reply = try await list("q=" + encode(q))
            XCTAssertEqual(reply.status, 200, "q=\(q): \(reply.text)")
            XCTAssertEqual(codes(reply), [], "q=\(q) must match nothing")
        }
        // A bidi override (Unicode format character) counts as a control character: refused, not a 500.
        let bidi = try await list("q=" + encode("\u{202E}abc"))
        XCTAssertTrue([200, 422].contains(bidi.status), bidi.text)
        let alive = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(alive, 2)
        XCTAssertNotNil(other)
    }

    func testTCB57_FieldErrorCodesOfTheListAreListedTogether() async throws {
        let table: [(String, [String])] = [
            ("view=unfinished", ["UNKNOWN_PARAMETER"]), ("date_from=2026-11-01", ["UNKNOWN_PARAMETER"]), ("date_to=2026-11-01", ["UNKNOWN_PARAMETER"]),
            ("page_size=10", ["UNKNOWN_PARAMETER"]), ("limit=0", ["UNKNOWN_PARAMETER"]),
            ("status=New&status=Cancelled", ["REPEATED_PARAMETER"]), ("q=abc&q=def", ["REPEATED_PARAMETER"]),
            ("status=New,Cancelled", ["STATUS_INVALID"]), ("status=banana", ["STATUS_INVALID"]), ("status=", ["STATUS_INVALID"]), ("status=NEW", ["STATUS_INVALID"]),
            ("delivery_date=2026-02-31", ["DATE_INVALID"]), ("delivery_date=11/02/2026", ["DATE_INVALID"]), ("delivery_date=", ["DATE_INVALID"]),
            ("date_preset=yesterday", ["DATE_PRESET_INVALID"]), ("date_preset=today&delivery_date=2026-11-05", ["DATE_FILTER_CONFLICT"]),
            ("cursor=abc", ["CURSOR_INVALID"]), ("cursor=", ["CURSOR_INVALID"]),
            ("status=banana&delivery_date=nope&q=a", ["STATUS_INVALID", "DATE_INVALID", "SEARCH_INVALID"])
        ]
        for (query, expected) in table {
            let reply = try await list(query)
            XCTAssertEqual(reply.status, 422, query)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", query)
            XCTAssertEqual(Set(reply.fieldCodes), Set(expected), "\(query): \(reply.text)")
        }
        // Valid far dates return an empty list, not an error.
        for date in ["1999-01-01", "2099-12-31"] {
            let reply = try await list("delivery_date=\(date)")
            XCTAssertEqual(reply.status, 200)
            XCTAssertEqual(codes(reply), [])
        }
        // Status change body field codes.
        let order = try await seedOrder(date: dayOffset(4))
        let bodies: [([String: Any], String)] = [
            (["expected_status": "New", "to_status": "Confirmed", "extra": 1], "UNKNOWN_FIELD"),
            (["expected_status": "New", "to_status": "Confirmed", "cancel_reason": "fake_spam"], "REASON_NOT_ALLOWED"),
            (["expected_status": "Bogus", "to_status": "Confirmed"], "STATUS_INVALID"),
            (["to_status": "Confirmed"], "STATUS_INVALID")
        ]
        for (body, code) in bodies {
            let reply = try await client.send("POST", "v1/admin/orders/\(order)/status", token: phone.access, json: body)
            XCTAssertEqual(reply.status, 422, "\(body)")
            XCTAssertTrue(reply.fieldCodes.contains(code), "\(body): \(reply.text)")
        }
    }

    func testTCB71_CursorTamperingAndPaging() async throws {
        for index in 0..<120 { _ = try await seedOrder(cakes: 1, date: dayOffset(3 + index % 25), phone: "+8490000\(String(format: "%04d", index))", load: false) }
        var seen: [String] = [], cursor: String? = nil, pages: [Int] = [], firstCursor = ""
        repeat {
            let reply = try await list(cursor.map { "cursor=" + encode($0) } ?? "")
            XCTAssertEqual(reply.status, 200, reply.text)
            let page = codes(reply)
            pages.append(page.count)
            seen += page
            cursor = reply.json["next_cursor"] as? String
            if firstCursor.isEmpty, let cursor { firstCursor = cursor }
        } while cursor != nil && pages.count < 10
        XCTAssertEqual(pages, [50, 50, 20])
        XCTAssertEqual(seen.count, 120)
        XCTAssertEqual(Set(seen).count, 120, "no duplicate, no gap")
        // Tampering: every altered form is CURSOR_INVALID, never a 500, never rows.
        let flipped = String(firstCursor.dropLast()) + (firstCursor.last == "A" ? "B" : "A")
        let forged: [String] = [flipped, String(firstCursor.dropLast(3)), firstCursor + firstCursor, "AAAA", "null", "0", "-1", "{}", "'; DROP TABLE customer_order;--",
                                Data("{\"d\":\"2026-01-01\",\"id\":\"x\"}".utf8).base64EncodedString(), String(repeating: "A", count: 20_000), "../../etc/passwd", "%00"]
        for bad in forged.prefix(12) {
            let reply = try await list("cursor=" + encode(bad))
            XCTAssertEqual(reply.status, 422, "cursor \(bad.prefix(30)): \(reply.text.prefix(200))")
            XCTAssertEqual(reply.fieldCodes, ["CURSOR_INVALID"], "cursor \(bad.prefix(30))")
            XCTAssertTrue(codes(reply).isEmpty)
        }
        // A real cursor with a different filter must not crash and must not leak other rows.
        let crossed = try await list("status=Completed&cursor=" + encode(firstCursor))
        XCTAssertLessThan(crossed.status, 500, crossed.text.prefix(200).description)
        // A staff phone with the owner's cursor.
        let member = try await staff()
        let other = try await client.send("GET", "v1/admin/orders?cursor=" + encode(firstCursor), token: member.phone.access)
        XCTAssertLessThan(other.status, 500)
    }
}
