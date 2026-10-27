import XCTest
import XCTVapor
@testable import AppUnderTest

/// Slice 1: `/privacy` (api.md 4.5), `/assets/*` (4.6), asset files in the
/// repository, and the contract fixtures `catalog-*.json` (architecture.md 11).
/// Needs no database. Rules of api.md v1.6 and ADR-0017 (images under
/// `/assets/images/`, privacy page only at `/privacy`).
final class PrivacyPageTests: StaticContentBase {

    // MARK: Privacy page (TC-67, deployment 4)

    func testTC67_PrivacyPageIsServedAsUtf8Html() async throws {
        let r = try await app.qaSend(.GET, "privacy")
        XCTAssertEqual(r.status, .ok)
        let contentType = r.header("Content-Type")?.lowercased() ?? ""
        XCTAssertTrue(contentType.hasPrefix("text/html"), contentType)
        XCTAssertTrue(contentType.contains("utf-8"), "Vietnamese text needs an explicit charset: \(contentType)")
        XCTAssertTrue(r.text.lowercased().contains("<html"))
        XCTAssertTrue(r.text.lowercased().contains("lang=\"vi\""), "page language must be Vietnamese (AC-21 spirit)")
        XCTAssertNotNil(r.header("X-Request-Id"))
    }

    func testTC67_PrivacyPageNamesEveryCollectedItemAndPurposeAndRecipient() async throws {
        let r = try await app.qaSend(.GET, "privacy")
        let folded = Slice1.fold(r.text)
        for (label, needle) in [("name", "ho ten"), ("phone", "so dien thoai"), ("address", "dia chi"), ("note", "ghi chu"),
                                ("purpose", "muc dich"), ("who sees it", "ai xem"), ("storage place", "noi luu tru"),
                                ("retention", "luu giu")] {
            XCTAssertTrue(folded.contains(needle), "privacy page does not mention \(label) (api.md 4.5)")
        }
    }

    func testTC67_PrivacyPageHasNoPaymentWordsNoRemoteScriptsAndNoTrackers() async throws {
        let r = try await app.qaSend(.GET, "privacy")
        XCTAssertEqual(r.status, .ok)
        let paymentHits = Slice1.forbiddenHits(in: [r.text]).filter { !$0.hasPrefix("test") }
        XCTAssertEqual(paymentHits, [], "AC-27 / AC-29 apply to every customer-visible page")
        let lower = r.text.lowercased()
        XCTAssertFalse(lower.contains("<script"), "a static statement needs no script")
        XCTAssertFalse(lower.contains("http://"), "no cleartext links")
        for tracker in ["googletagmanager", "google-analytics", "facebook.net", "doubleclick"] {
            XCTAssertFalse(lower.contains(tracker), tracker)
        }
    }

    func testExtra_PrivacyHeadAndMethods() async throws {
        let head = try await app.qaSend(.HEAD, "privacy")
        XCTAssertEqual(head.status, .ok)
        for method in [HTTPMethod.POST, .PUT, .DELETE] {
            let r = try await app.qaSend(method, "privacy")
            XCTAssertEqual(r.status, .notFound, "\(method)")
        }
        for path in ["privacy/", "Privacy", "privacy.html", "privacy?x=1"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertLessThan(r.status.code, 500, path)
        }
    }

    func testTC67_PrivacySourceFileExistsAndIsFakeFreeOfSecrets() throws {
        let url = QAPaths.backend.appendingPathComponent("assets/privacy.html")
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(text.isEmpty)
        for pattern in ["password", "secret", "token=", "postgres://", "@fpt.com"] {
            XCTAssertFalse(text.lowercased().contains(pattern), pattern)
        }
    }

}
