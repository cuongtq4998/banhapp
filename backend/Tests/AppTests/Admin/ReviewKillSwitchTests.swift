import XCTVapor
import FluentSQL
@testable import App

/// F-1, F-3 (ADR-0027): the configuration is the kill switch of the review account.
final class ReviewKillSwitchTests: ReviewAccountTestCase {
    private func setReview(_ review: ReviewAccountConfig?) {
        app.services.adminAuth = AdminAuthConfig(pepper: pepper, emailProvider: .recording, emailMaxPerDay: 1_000_000, review: review)
    }

    func testReviewSessionWorksWhileTheConfigurationNamesItsAddress() async throws {
        try await switchOn()
        let reviewer = try await reviewPhone()
        let listed = try await list(reviewer)
        XCTAssertEqual(listed.status, .ok)
    }

    func testRemovingTheConfigurationEndsAnExistingReviewSessionAtOnce() async throws {
        try await switchOn()
        let reviewer = try await reviewPhone()
        setReview(nil)
        let denied = try await list(reviewer)
        XCTAssertEqual(denied.status, .unauthorized)
        XCTAssertEqual(denied.errorCode, "UNAUTHENTICATED")
        let rows = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review' AND is_active")
        XCTAssertEqual(rows, 1, "no database command is needed; the row stays for `off`")
    }

    func testAChangedAddressEndsAnExistingReviewSession() async throws {
        try await switchOn()
        let reviewer = try await reviewPhone()
        setReview(ReviewAccountConfig(email: "other.\(UUID().uuidString.prefix(8).lowercased())@example.com", code: fixedCode))
        let denied = try await list(reviewer)
        XCTAssertEqual(denied.status, .unauthorized)
        XCTAssertEqual(denied.errorCode, "UNAUTHENTICATED")
    }

    func testNormalStaffAndOwnerSessionsIgnoreTheReviewConfiguration() async throws {
        let owner = try await addAccount(.owner, "Chu Mau"), staff = try await addAccount(.staff)
        let ownerPhone = try await signedIn(owner.email), staffPhone = try await signedIn(staff.email)
        setReview(nil)
        let first = try await list(ownerPhone), second = try await list(staffPhone)
        XCTAssertEqual(first.status, .ok)
        XCTAssertEqual(second.status, .ok)
    }

    func testChangingTheAddressAndRunningOnLeavesTheOldRowInactiveAndCreatesTheNewOne() async throws {
        try await switchOn()
        let changed = "second.\(UUID().uuidString.prefix(8).lowercased())@example.com"
        try await ReviewAccountCommand.enable(on: app.db, shopID: shopID, review: ReviewAccountConfig(email: changed, code: fixedCode), clock: clock)
        let old = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review' AND email = \(bind: reviewEmail) AND is_active")
        let new = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review' AND email = \(bind: changed) AND is_active")
        let active = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review' AND is_active")
        XCTAssertEqual([old, new, active], [0, 1, 1])
    }
}
