import XCTVapor
import FluentSQL
@testable import App

/// FR-27, ADR-0030, TC-B98 to TC-B101: a cancelled order stops counting toward
/// the per-phone limit unless it was cancelled as fake_spam. Through the real
/// `POST /v1/orders` route.
final class OrderPhoneRuleTests: OrderDatabaseTestCase {
    /// Orders that are not cancelled yet. Several orders may share a placed time,
    /// so tests never rely on their position, only on being open.
    private func openIDs(_ seed: Seed) async throws -> [UUID] {
        try await sql.raw("SELECT id FROM customer_order WHERE shop_id = \(bind: seed.shopID) AND status <> 'Cancelled' ORDER BY created_at, id")
            .all().map { try $0.decode(column: "id", as: UUID.self) }
    }

    private func cancel(_ id: UUID, _ reason: String) async throws {
        try await sql.raw("UPDATE customer_order SET status = 'Cancelled', cancel_reason = \(bind: reason) WHERE id = \(bind: id)").run()
    }

    private func place(_ seed: Seed) async throws -> HTTPResponseStatus {
        try await send(body(seed, phone: "0900000007")).status
    }

    func testCancelledOrdersFreeThePhoneExceptFakeSpam() async throws {
        let seed = try await start(dailyLimit: 100, orders: OrderPolicy(perAddressPerHour: 10_000, perPhonePerDay: 2))
        for _ in 0..<2 { let ok = try await place(seed); XCTAssertEqual(ok, .created) }
        let limited = try await place(seed)
        XCTAssertEqual(limited, .tooManyRequests)

        try await cancel(try await openIDs(seed)[0], "customer_asked")
        let afterAsked = try await place(seed)
        XCTAssertEqual(afterAsked, .created, "cancelled by customer request no longer counts")
        let full = try await place(seed)
        XCTAssertEqual(full, .tooManyRequests)

        try await cancel(try await openIDs(seed)[0], "fake_spam")
        let afterSpam = try await place(seed)
        XCTAssertEqual(afterSpam, .tooManyRequests, "a fake or spam order keeps counting")

        try await cancel(try await openIDs(seed)[0], "cannot_deliver")
        let afterDeliver = try await place(seed)
        XCTAssertEqual(afterDeliver, .created, "cannot deliver no longer counts")
    }

    func testCancelledOrderReturnsItsCakesAndTheCountOfTheOtherPhoneIsUntouched() async throws {
        let seed = try await start(dailyLimit: 100, orders: OrderPolicy(perAddressPerHour: 10_000, perPhonePerDay: 1))
        let first = try await send(body(seed, cakes: 3, phone: "0900000007"))
        XCTAssertEqual(first.status, .created)
        let before = try await cakes(seed)
        XCTAssertEqual(before, 3)
        try await cancel(try await openIDs(seed)[0], "cannot_reach_customer")
        let after = try await cakes(seed)
        XCTAssertEqual(after, 0)
        let again = try await place(seed)
        XCTAssertEqual(again, .created)
    }
}
