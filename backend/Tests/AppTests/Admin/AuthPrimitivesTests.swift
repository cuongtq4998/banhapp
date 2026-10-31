import XCTest
@testable import App

final class AuthPrimitivesTests: XCTestCase {
    func testAddressIsStoredTrimmedLowerCaseAndNFC() {
        XCTAssertEqual(EmailAddress("  NhanVien.A@Example.com ")?.value, "nhanvien.a@example.com")
        XCTAssertEqual(EmailAddress("nhanvien.a+x@example.com")?.value, "nhanvien.a+x@example.com")
        // Decomposed and composed spellings of the same letters match.
        XCTAssertEqual(EmailAddress("e\u{301}@example.com"), EmailAddress("\u{e9}@example.com"))
    }

    func testBadAddressesAreRefused() {
        for bad in ["", "a", "a@b", "a@@b.com", "a b@example.com", "no-at.example.com", "a@b..com", "a@.com", "a\n@example.com", "a@b.com\r\nBcc: x"] {
            XCTAssertNil(EmailAddress(bad), bad)
        }
    }

    func testLookAlikeLettersNeverMatch() {
        // Cyrillic "a" is not Latin "a".
        XCTAssertNotEqual(EmailAddress("\u{430}@example.com"), EmailAddress("a@example.com"))
    }

    func testAddressLengthBoundary() throws {
        let domain = "@example.com"
        let ok = String(repeating: "a", count: 254 - domain.count) + domain
        XCTAssertEqual(try XCTUnwrap(EmailAddress(ok)).value.count, 254)
        XCTAssertNil(EmailAddress("a" + ok))
    }

    func testTokenRoundTripAndShape() throws {
        let id = UUID()
        let token = SessionToken.issue(.access, sessionID: id)
        XCTAssertTrue(token.text.hasPrefix("at_\(id.uuidString.lowercased())_"))
        XCTAssertEqual(token.text.count, 3 + 36 + 1 + 64)
        XCTAssertEqual(SessionToken.parse(token.text), token)
        XCTAssertEqual(token.hash.count, 32)
        XCTAssertNotEqual(SessionToken.issue(.access, sessionID: id).text, token.text)
        XCTAssertEqual(SessionToken.parse(token.text.replacingOccurrences(of: "at_", with: "rt_"))?.kind, .refresh)
    }

    func testMalformedTokensAreRejected() {
        let good = SessionToken.issue(.refresh, sessionID: UUID()).text
        for bad in ["", "x", good + "0", String(good.dropLast()), good.uppercased(), "xx" + good.dropFirst(2), "at_nope_" + String(repeating: "a", count: 64)] {
            XCTAssertNil(SessionToken.parse(bad), bad)
        }
    }

    func testCodesAreSixDigitsAndCheckedByKeyedHash() throws {
        let codes = SignInCodes(pepper: String(repeating: "p", count: 32))
        let other = SignInCodes(pepper: String(repeating: "q", count: 32))
        let email = try XCTUnwrap(EmailAddress("a@example.com"))
        for _ in 0..<50 { XCTAssertTrue(SignInCodes.isWellFormed(SignInCodes.makeCode())) }
        let hash = codes.hmac(email: email, code: "012345")
        XCTAssertEqual(hash.count, 32)
        XCTAssertTrue(codes.matches(hash, email: email, code: "012345"))
        XCTAssertFalse(codes.matches(hash, email: email, code: "012346"))
        XCTAssertFalse(codes.matches(hash, email: try XCTUnwrap(EmailAddress("b@example.com")), code: "012345"))
        XCTAssertFalse(other.matches(hash, email: email, code: "012345"))
        XCTAssertEqual(SignInCodes.phantomHash().count, 32)
    }

    func testOnlySixAsciiDigitsAreWellFormed() {
        for bad in ["12345", "1234567", "abcdef", "", " 123456", "12345\u{0663}", "1' OR 1=1"] {
            XCTAssertFalse(SignInCodes.isWellFormed(bad), bad)
        }
    }
}
