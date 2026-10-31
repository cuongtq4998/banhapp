import XCTest
@testable import BanhApp

/// FR-20, AC-30: the privacy page address and the open/fail behaviour shared by S-7 and S-8.
@MainActor
final class PrivacyLinkTests: XCTestCase {
    func testTheAddressIsThePrivacyPathUnderTheApiBase() {
        XCTAssertEqual(
            PrivacyLink.privacyURL(apiBaseURL: URL(string: "https://api.example.test")!)?.absoluteString,
            "https://api.example.test/privacy"
        )
    }

    func testABaseWithAPathKeepsItAndAppendsOnce() {
        XCTAssertEqual(
            PrivacyLink.privacyURL(apiBaseURL: URL(string: "http://localhost:8080/shop/")!)?.absoluteString,
            "http://localhost:8080/shop/privacy"
        )
    }

    func testABaseThatIsNotHttpHasNoAddress() {
        XCTAssertNil(PrivacyLink.privacyURL(apiBaseURL: URL(string: "file:///none")!))
        XCTAssertNil(PrivacyLink.privacyURL(apiBaseURL: URL(string: "mailto:a@b.c")!))
    }

    func testOpeningPresentsTheAddressWithoutAFailure() {
        let link = PrivacyLink(apiBaseURL: URL(string: "https://api.example.test")!)
        link.open()
        XCTAssertEqual(link.presented?.absoluteString, "https://api.example.test/privacy")
        XCTAssertFalse(link.failed)
        link.dismiss()
        XCTAssertNil(link.presented)
    }

    func testOpeningWithAnUnusableBaseReportsTheFailure() {
        let link = PrivacyLink(apiBaseURL: URL(string: "file:///none")!)
        link.open()
        XCTAssertNil(link.presented)
        XCTAssertTrue(link.failed)
    }

    func testTheNewKeysResolveToTheVietnameseText() {
        XCTAssertEqual(String(localized: OrderStrings.privacyTitle), "Thông tin của bạn được dùng như thế nào")
        XCTAssertEqual(String(localized: OrderStrings.reviewPrivacyLink), "Xem chính sách đầy đủ")
        XCTAssertTrue(String(localized: OrderStrings.reviewPrivacy).contains("ghi chú"))
    }
}
