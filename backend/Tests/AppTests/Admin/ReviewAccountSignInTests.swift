import XCTVapor
import FluentSQL
@testable import App

/// AC-13, FR-8, BR-14 (ADR-0027): the fixed code signs in the review address only,
/// as staff, while the account is on; nothing else accepts it.
final class ReviewAccountSignInTests: ReviewAccountTestCase {
    func testTheFixedCodeSignsTheReviewAddressInAsStaffWithoutAMail() async throws {
        try await switchOn()
        let requested = try await requestCode(reviewEmail)
        XCTAssertEqual(requested.status, .accepted)
        await app.services.background.drain()
        XCTAssertNil(mail.lastCode(to: reviewEmail), "no mail is sent; the code is fixed")
        let reply = try await signIn(reviewEmail, fixedCode)
        XCTAssertEqual(reply.status, .created)
        XCTAssertEqual((reply.json["account"] as? [String: Any])?["role"] as? String, "staff")
        let method = try await count("SELECT count(*)::int AS n FROM device_session s JOIN account a ON a.id = s.account_id WHERE a.shop_id = \(bind: shopID) AND a.kind = 'review' AND s.sign_in_method = 'review'")
        XCTAssertEqual(method, 1)
        let events = try await count("SELECT count(*)::int AS n FROM security_event e JOIN account a ON a.id = e.account_id WHERE a.shop_id = \(bind: shopID) AND e.event_type = 'sign_in_review'")
        XCTAssertEqual(events, 1, "the use of the account is a security event")
    }

    func testAWrongCodeIsRefusedAndFiveVoidTheCode() async throws {
        try await switchOn()
        let requested = try await requestCode(reviewEmail)
        XCTAssertEqual(requested.status, .accepted)
        for _ in 0..<4 {
            let wrong = try await signIn(reviewEmail, "000000")
            XCTAssertEqual(wrong.errorCode, "CODE_INVALID")
        }
        let fifth = try await signIn(reviewEmail, "000000")
        XCTAssertEqual(fifth.errorCode, "CODE_EXPIRED")
        let late = try await signIn(reviewEmail, fixedCode)
        XCTAssertEqual(late.errorCode, "CODE_EXPIRED", "the normal limits apply to the review address too")
    }

    func testNoOtherAddressAcceptsTheFixedCode() async throws {
        try await switchOn()
        let staff = try await addAccount(.staff), owner = try await addAccount(.owner, "Chu Mau")
        let unknown = "nobody.\(UUID().uuidString.prefix(8).lowercased())@example.com"
        for email in [staff.email, owner.email, unknown] {
            let requested = try await requestCode(email)
            XCTAssertEqual(requested.status, .accepted)
            await app.services.background.drain()
            let reply = try await signIn(email, fixedCode)
            XCTAssertEqual(reply.errorCode, "CODE_INVALID", "the fixed code works for the review address only")
            XCTAssertEqual(reply.status, .unprocessableEntity)
        }
        let sessions = try await count("SELECT count(*)::int AS n FROM device_session s JOIN account a ON a.id = s.account_id WHERE a.shop_id = \(bind: shopID)")
        XCTAssertEqual(sessions, 0)
    }

    func testNormalSignInStillWorksWhileTheReviewAccountIsOn() async throws {
        try await switchOn()
        let account = try await addAccount(.owner, "Chu Mau")
        let phone = try await signedIn(account.email)
        let listed = try await list(phone)
        XCTAssertEqual(listed.status, .ok)
    }

    func testFixedCodeIsRefusedLikeAnUnregisteredAddressWhenTheAccountIsOff() async throws {
        try await switchOn()
        try await switchOff()
        let off = try await reviewSignIn()
        let unknown = "nobody.\(UUID().uuidString.prefix(8).lowercased())@example.com"
        let requested = try await requestCode(unknown)
        XCTAssertEqual(requested.status, .accepted)
        let other = try await signIn(unknown, fixedCode)
        XCTAssertEqual(off.status, other.status)
        XCTAssertEqual(off.errorCode, "CODE_INVALID")
        XCTAssertEqual(off.json["error"] as? NSDictionary, other.json["error"] as? NSDictionary)
    }

    func testWithoutTheAccountRowTheFixedCodeIsRefused() async throws {
        let reply = try await reviewSignIn()
        XCTAssertEqual(reply.errorCode, "CODE_INVALID", "configured but `review-account on` never ran")
    }

    func testTheFixedCodeAndTheAddressNeverReachTheLogAtTraceLevel() async throws {
        try await switchOn()
        _ = try await reviewPhone()
        let log = capture.lines.map { "\($0.message) \($0.metadata)" }.joined(separator: "\n")
        XCTAssertGreaterThan(capture.lines.count, 2)
        XCTAssertFalse(log.contains(fixedCode))
        XCTAssertFalse(log.contains(reviewEmail))
    }

    let capture = LogCapture()
    override var testLogger: Logger? { capture.makeLogger() }
}
