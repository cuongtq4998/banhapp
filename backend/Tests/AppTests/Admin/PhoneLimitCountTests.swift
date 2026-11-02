import XCTVapor
@testable import App

/// TC-B98 to TC-B103, TC-B102 (ADR-0030): a stored order counts toward the
/// per-phone limit unless it is Cancelled for a reason other than fake_spam.
final class PhoneLimitCountTests: AdminOrderTestCase {
    private let number = "+84900000010"

    private func counted(since hours: Double = 24) async throws -> Int {
        let repository = PostgresOrderRepository(database: app.db)
        return try await repository.countOrders(shopID: shopID, phone: number, since: clock.now().addingTimeInterval(-hours * 3_600))
    }

    private func cancelled(_ reason: String) async throws {
        try await place(.init(status: "Cancelled", phone: number, reason: reason))
    }

    func testOpenAndFinishedOrdersCount() async throws {
        for status in ["Received", "Processing", "Finished"] { try await place(.init(status: status, phone: number)) }
        let total = try await counted()
        XCTAssertEqual(total, 3)
    }

    func testOrdersCancelledForAnyReasonButSpamStopCounting() async throws {
        for reason in ["customer_asked", "cannot_deliver", "cannot_reach_customer"] { try await cancelled(reason) }
        let freed = try await counted()
        XCTAssertEqual(freed, 0)
        try await cancelled("fake_spam")
        let spam = try await counted()
        XCTAssertEqual(spam, 1)
    }

    func testMixedFiveOrdersLeaveRoomForTwoMore() async throws {
        try await cancelled("cannot_deliver"); try await cancelled("cannot_deliver"); try await cancelled("fake_spam")
        try await place(.init(status: "Received", phone: number)); try await place(.init(status: "Processing", phone: number))
        let total = try await counted()
        XCTAssertEqual(total, 3)
    }

    func testTheTwentyFourHourWindowIsMeasuredOnThePlacedTime() async throws {
        let now = clock.now()
        try await place(.init(placed: now.addingTimeInterval(-(24 * 3_600 - 60)), phone: number))
        try await place(.init(placed: now.addingTimeInterval(-(24 * 3_600 + 60)), phone: number))
        let total = try await counted()
        XCTAssertEqual(total, 1)
    }

    func testAnotherPhoneAndAnotherShopAreNotCounted() async throws {
        try await place(.init(phone: "+84911111111"))
        let total = try await counted()
        XCTAssertEqual(total, 0)
    }

    func testCancellingAsSpamLaterCountsTheOrderAtOnceAndTheFirstReasonStays() async throws {
        let orderCode = try await place(.init(phone: number))
        let staff = try await phone(.staff)
        let reply = try await change(staff, orderCode, move("Received", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(reply.status, .ok)
        let afterCancel = try await counted()
        XCTAssertEqual(afterCancel, 0)
        let again = try await change(staff, orderCode, move("Received", "Cancelled", reason: "fake_spam"))
        XCTAssertEqual(again.string("cancel_reason"), "customer_asked")
        let stillFree = try await counted()
        XCTAssertEqual(stillFree, 0)
        let spamCode = try await place(.init(phone: number))
        _ = try await change(staff, spamCode, move("Received", "Cancelled", reason: "fake_spam"))
        let nowCounted = try await counted()
        XCTAssertEqual(nowCounted, 1)
    }
}
