import XCTVapor
import FluentSQL
@testable import App

/// `review-account on|off` (ADR-0027, architecture/07): what the operator command does to the database.
final class ReviewAccountCommandTests: ReviewAccountTestCase {
    func testOnTwiceStillLeavesExactlyThreeDemoOrders() async throws {
        try await switchOn()
        let first = try await demoCodes()
        try await switchOn()
        let second = try await demoCodes()
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(second.count, 3)
        let statuses = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo AND status IN ('New', 'Confirmed')")
        XCTAssertEqual(statuses, 3)
        let accounts = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review' AND is_active")
        XCTAssertEqual(accounts, 1)
    }

    func testOffRemovesDemoOrdersAndSessionsAndSwitchesTheAccountOff() async throws {
        let real = try await place()
        try await switchOn()
        let reviewer = try await reviewPhone()
        // The reviewer confirms one demo order, so it has history that must go too.
        let row = try await sql.raw("SELECT order_code FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo AND status = 'New' LIMIT 1").first()
        let target = try XCTUnwrap(row).decode(column: "order_code", as: String.self)
        let confirmed = try await change(reviewer, target, move("New", "Confirmed"))
        XCTAssertEqual(confirmed.status, .ok)
        try await switchOff()
        let demo = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo")
        let items = try await count("SELECT count(*)::int AS n FROM customer_order_item i LEFT JOIN customer_order o ON o.id = i.order_id WHERE o.id IS NULL")
        let sessions = try await count("SELECT count(*)::int AS n FROM device_session s JOIN account a ON a.id = s.account_id WHERE a.kind = 'review' AND a.shop_id = \(bind: shopID)")
        let active = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review' AND is_active")
        XCTAssertEqual([demo, items, sessions, active], [0, 0, 0, 0])
        let denied = try await list(reviewer)
        XCTAssertEqual(denied.status, .unauthorized, "the reviewer's phone is signed out")
        let stored = try await status(of: real)
        XCTAssertEqual(stored, "New", "the real order is untouched")
        let realCount = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID) AND NOT is_demo")
        XCTAssertEqual(realCount, 1)
        let audit = try await count("SELECT count(*)::int AS n FROM security_event e JOIN account a ON a.id = e.account_id WHERE a.kind = 'review' AND a.shop_id = \(bind: shopID)")
        XCTAssertEqual(audit, 1, "the append-only audit keeps its row")
    }

    func testOffThenOnGivesANewSetAndSignInWorksAgain() async throws {
        try await switchOn()
        try await switchOff()
        try await switchOn()
        let demo = try await demoCodes()
        XCTAssertEqual(demo.count, 3)
        let reviewer = try await reviewPhone()
        let listed = try await listCodes(reviewer)
        XCTAssertEqual(Set(listed), Set(demo))
    }

    func testRealOrderHistoryStaysAppendOnly() async throws {
        let real = try await place()
        let staff = try await phone(.staff)
        let moved = try await change(staff, real, move("New", "Confirmed"))
        XCTAssertEqual(moved.status, .ok)
        try await switchOn()
        try await switchOff()
        let events = try await events(of: real)
        XCTAssertEqual(events, 1)
        do {
            try await run("DELETE FROM order_event WHERE order_id IN (SELECT id FROM customer_order WHERE order_code = \(bind: real))")
            XCTFail("a real order's history must stay append-only")
        } catch {}
        do {
            try await run("UPDATE order_event SET reason = NULL WHERE order_id IN (SELECT id FROM customer_order WHERE is_demo)")
        } catch {}
    }

    func testAnAddressThatIsANormalAccountIsRefused() async throws {
        try await run("INSERT INTO account (shop_id, role, email, display_name) VALUES (\(bind: shopID), 'staff', \(bind: reviewEmail), 'Nhan Vien')")
        do {
            try await switchOn()
            XCTFail("a normal account must not become the review account")
        } catch let error as ReviewAccountError {
            XCTAssertEqual(error, .addressTaken)
            XCTAssertFalse("\(error)".contains(reviewEmail))
        }
        let demo = try await demoCodes()
        XCTAssertEqual(demo, [], "nothing is left behind")
    }

    func testAShopWithoutCakesIsRefusedAndRolledBack() async throws {
        try await run("UPDATE product SET is_active = false WHERE shop_id = \(bind: shopID)")
        do {
            try await switchOn()
            XCTFail("demo orders need a cake")
        } catch let error as ReviewAccountError {
            XCTAssertEqual(error, .shopNotReady)
        }
        let accounts = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review'")
        XCTAssertEqual(accounts, 0)
    }
}
