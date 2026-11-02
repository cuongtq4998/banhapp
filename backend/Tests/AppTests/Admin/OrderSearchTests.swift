import XCTVapor
@testable import App

/// TC-B59 to TC-B62 (BR-10): contains, ignoring case and accents, code with or
/// without "BT-", phone digits, wildcards literal, combined with filters.
final class OrderSearchTests: AdminOrderTestCase {
    private var target = ""
    private var staff: Phone!

    override func setUp() async throws {
        try await super.setUp()
        target = try await place(.init(number: 77, name: "Trần Thị Bé", phone: "+84900000010"))
        try await place(.init(name: "Le Van C", phone: "+84911111111"))
        staff = try await phone(.staff)
    }

    func testFindsByCodeNameAndPhoneInEveryWrittenForm() async throws {
        let suffix = String(target.dropFirst(3))
        for query in [suffix.lowercased(), target, target.lowercased(), "tran thi", "TRẦN", "thi%20be", "0900000010", "%2B84%20900%20000%20010", "900000010", "090"] {
            try await expectCodes(staff, "q=\(query)", [target])
        }
        try await expectCodes(staff, "q=zzz", [])
    }

    func testPlusInTheQueryIsASpaceAsInFormDecoding() async throws {
        try await expectCodes(staff, "q=tran+thi", [target])
    }

    func testDecomposedAndComposedAccentsMatchTheSame() async throws {
        let nfd = "Tra\u{0302}\u{0300}n".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        try await expectCodes(staff, "q=\(nfd)", [target])
        try await expectCodes(staff, "q=%C4%91", [])
        try await place(.init(name: "Đỗ Văn Đức"))
        let hits = try await listCodes(staff, "q=do%20van%20duc")
        XCTAssertEqual(hits.count, 1)
    }

    func testWildcardsAndOddInputAreLiteralAndNeverFail() async throws {
        for query in ["%25%25%25", "___", "%5C%5C%5C", "'%3B%20--", String(repeating: "a", count: 50)] {
            try await expectCodes(staff, "q=\(query)", [])
        }
        let reply = try await list(staff, "q=" + String(repeating: "a", count: 200))
        XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED")
        let control = try await list(staff, "q=ab%00c")
        XCTAssertEqual(control.errorCode, "VALIDATION_FAILED")
        let tab = try await list(staff, "q=ab%09c")
        XCTAssertEqual(tab.errorCode, "VALIDATION_FAILED")
    }

    func testRealWildcardCharactersInANameAreMatchedLiterally() async throws {
        let odd = try await place(.init(name: "100% Banh_Mau"))
        try await expectCodes(staff, "q=100%25", [odd])
        try await expectCodes(staff, "q=h_M", [odd])
        try await expectCodes(staff, "q=h_X", [])
    }

    func testThreeCharactersIsTheMinimumAndAPhoneNeedsThreeDigits() async throws {
        let short = try await list(staff, "q=ab")
        XCTAssertEqual(short.status, .unprocessableEntity)
        let digits = try await list(staff, "q=09")
        XCTAssertEqual(digits.status, .unprocessableEntity)
        let sign = try await list(staff, "q=%2B-8")
        XCTAssertEqual(sign.status, .unprocessableEntity)
        let ok = try await list(staff, "q=tra")
        XCTAssertEqual(ok.status, .ok)
        let padded = try await list(staff, "q=%20%20a%20")
        XCTAssertEqual(padded.status, .unprocessableEntity)
    }

    func testSearchCombinesWithFiltersAsAnd() async throws {
        let done = try await place(.init(status: "Finished", name: "Tran Van Done"))
        try await expectCodes(staff, "q=tran", [target])
        let both = Set(try await listCodes(staff, "q=tran&status=all"))
        XCTAssertEqual(both, [target, done])
        try await expectCodes(staff, "q=tran&status=Finished", [done])
        try await expectCodes(staff, "q=tran&status=Finished&delivery_date=2031-01-01", [])
    }
}
