import XCTVapor
import FluentSQL
@testable import App

/// AC-13, BR-14: the review account sees exactly three demo orders and no real one;
/// demo orders are invisible to real accounts and never touch a limit.
final class ReviewAccountDataTests: ReviewAccountTestCase {
    func testTheReviewAccountSeesExactlyThreeDemoOrdersAndNoRealOne() async throws {
        let real = try await place()
        try await switchOn()
        let demo = try await demoCodes()
        XCTAssertEqual(demo.count, 3)
        let reviewer = try await reviewPhone()
        let listed = try await listCodes(reviewer, "status=all")
        XCTAssertEqual(Set(listed), Set(demo))
        XCTAssertEqual(listed.count, 3)
        XCTAssertFalse(listed.contains(real))
        let hidden = try await detail(reviewer, real)
        XCTAssertEqual(hidden.errorCode, "ORDER_NOT_FOUND")
        let search = try await listCodes(reviewer, "q=Tran&status=all")
        XCTAssertEqual(search, [], "a real customer's name finds nothing")
        let changed = try await change(reviewer, real, move("Received", "Processing"))
        XCTAssertEqual(changed.errorCode, "ORDER_NOT_FOUND")
        let stored = try await status(of: real)
        XCTAssertEqual(stored, "Received")
    }

    func testDemoOrdersAreInvisibleToRealStaffAndOwner() async throws {
        let real = try await place(.init(date: day(0)))
        try await switchOn()
        let demo = try await demoCodes()
        for role in [AccountRole.staff, .owner] {
            let phone = try await self.phone(role, role == .owner ? "Chu Mau" : "Nhan Vien")
            let listed = try await listCodes(phone, "status=all")
            XCTAssertEqual(listed, [real])
            let opened = try await detail(phone, demo[0])
            XCTAssertEqual(opened.errorCode, "ORDER_NOT_FOUND")
            let badge = try await list(phone)
            XCTAssertEqual(badge.json["unfinished_count"] as? Int, 1, "only the real order is counted")
        }
    }

    func testDemoRowsHoldFakeDataAndNoRealCustomer() async throws {
        let real = try await place(.init(name: "Tran Real Customer", phone: "+84900000555"))
        try await switchOn()
        let reviewer = try await reviewPhone()
        let reply = try await list(reviewer, "status=all")
        let text = String(decoding: reply.data, as: UTF8.self)
        XCTAssertFalse(text.contains("Real Customer") || text.contains("555") || text.contains(real))
        XCTAssertTrue(text.contains("Demo Customer"))
        let reviewRows = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND kind = 'review'")
        XCTAssertEqual(reviewRows, 1)
    }

    func testDemoOrdersChangeNoLimitAndNoCount() async throws {
        let date = day(1)
        try await addLoad(date, 5)
        try await switchOn()
        let before = try await loaded(date)
        XCTAssertEqual(before, 5, "creating demo orders adds no cakes to day_load")
        let rows = try await count("SELECT count(*)::int AS n FROM day_load WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(rows, 1)
        let reviewer = try await reviewPhone()
        for orderCode in try await demoCodes() {
            let reply = try await change(reviewer, orderCode, move("Received", "Cancelled", reason: "customer_asked"))
            XCTAssertTrue([.ok, .conflict].contains(reply.status), "\(reply.status)")
        }
        let after = try await loaded(date)
        XCTAssertEqual(after, 5, "cancelling demo orders gives nothing back (migration 0005)")
        let phoneCount = try await PostgresOrderRepository(database: app.db)
            .countOrders(shopID: shopID, phone: "+84900000001", since: clock.now().addingTimeInterval(-86_400))
        XCTAssertEqual(phoneCount, 0, "demo orders never count toward the per-phone limit")
    }

    func testTheReviewAccountIsHiddenFromTheOwnersStaffList() async throws {
        try await switchOn()
        let owner = try await phone(.owner, "Chu Mau")
        let reply = try await authed(.GET, "v1/owner/staff", owner.access)
        XCTAssertEqual(reply.status, .ok)
        let text = String(decoding: reply.data, as: UTF8.self)
        XCTAssertFalse(text.contains(reviewEmail) || text.contains(ReviewAccountConfig.displayName))
        XCTAssertEqual((reply.json["accounts"] as? [[String: Any]])?.count, 1)
    }

    func testTheReviewAccountCannotUseOwnerRoutes() async throws {
        try await switchOn()
        let reviewer = try await reviewPhone()
        let reply = try await authed(.GET, "v1/owner/staff", reviewer.access)
        XCTAssertEqual(reply.status, .forbidden)
    }
}
