import XCTest
@testable import App

final class EntityTagTests: XCTestCase {
    private let tag = EntityTag(hashing: Data("body".utf8))

    func testTagIsAQuotedTruncatedSHA256HexDigest() throws {
        XCTAssertEqual(tag.headerValue.count, 32 + 2)
        XCTAssertTrue(tag.headerValue.hasPrefix("\"") && tag.headerValue.hasSuffix("\""))
        let digits = tag.headerValue.dropFirst().dropLast()
        XCTAssertTrue(digits.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    func testTagIsThePrefixOfTheKnownDigest() {
        // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        XCTAssertEqual(EntityTag(hashing: Data("abc".utf8)).headerValue, "\"ba7816bf8f01cfea414140de5dae2223\"")
    }

    func testSameBytesSameTagDifferentBytesDifferentTag() {
        XCTAssertEqual(tag, EntityTag(hashing: Data("body".utf8)))
        XCTAssertNotEqual(tag, EntityTag(hashing: Data("body ".utf8)))
    }

    func testMatchesTheHeaderForms() {
        XCTAssertTrue(tag.isListed(inIfNoneMatch: tag.headerValue))
        XCTAssertTrue(tag.isListed(inIfNoneMatch: "W/" + tag.headerValue))
        XCTAssertTrue(tag.isListed(inIfNoneMatch: "\"other\", " + tag.headerValue))
        XCTAssertTrue(tag.isListed(inIfNoneMatch: "*"))
    }

    func testDoesNotMatchOtherValues() {
        XCTAssertFalse(tag.isListed(inIfNoneMatch: nil))
        XCTAssertFalse(tag.isListed(inIfNoneMatch: ""))
        XCTAssertFalse(tag.isListed(inIfNoneMatch: "\"other\""))
        XCTAssertFalse(tag.isListed(inIfNoneMatch: String(tag.headerValue.dropFirst().dropLast())), "unquoted is not a tag")
    }
}
