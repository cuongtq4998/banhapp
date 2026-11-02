import XCTest
import Vapor
@testable import AppUnderTest

/// FR-27, BR-8, TC-B98 to TC-B104: which cancelled orders still count toward the 5 orders per phone in 24 hours.
final class AdminPhoneLimitTests: AdminQABase {
    override var useRealClock: Bool { true }

    private func place(_ phone: String, _ index: Int = 0) async throws -> QAReply {
        try await customerOrder(date: dayOffset(4 + index % 20), cakes: 2, phone: phone)
    }

    private func fill(_ phone: String, _ count: Int) async throws -> [String] {
        var codes: [String] = []
        for index in 0..<count {
            let reply = try await place(phone, index)
            XCTAssertEqual(reply.status, 201, "order \(index + 1): \(reply.text)")
            codes.append(reply.string("order_code"))
        }
        return codes
    }

    private func cancel(_ codes: [String], reasons: [String]) async throws {
        let phone = try await owner()
        for (code, reason) in zip(codes, reasons) {
            let reply = try await changeStatus(phone, code, from: "Received", to: "Cancelled", reason: reason)
            XCTAssertEqual(reply.status, 200, "\(reason): \(reply.text)")
        }
    }

    func testTCB98_CustomerAskedAndCannotDeliverAndCannotReachDoNotCount() async throws {
        for (index, reason) in ["customer_asked", "cannot_deliver", "cannot_reach_customer"].enumerated() {
            let phone = "090000002\(index)"
            let codes = try await fill(phone, 5)
            let refused = try await place(phone)
            XCTAssertEqual(refused.status, 429, "6th order before any cancel")
            XCTAssertEqual(refused.errorCode, "RATE_LIMITED")
            try await cancel([codes[0]], reasons: [reason])
            let accepted = try await place(phone)
            XCTAssertEqual(accepted.status, 201, "6th order after cancel as \(reason): \(accepted.text)")
        }
    }

    func testTCB100_FakeSpamStillCountsForTwentyFourHoursThenStops() async throws {
        let phone = "0900000030"
        let codes = try await fill(phone, 5)
        try await cancel([codes[0]], reasons: ["fake_spam"])
        let refused = try await place(phone)
        XCTAssertEqual(refused.status, 429, refused.text)
        XCTAssertEqual(refused.errorCode, "RATE_LIMITED")
        clock.advance(24 * 3_600 + 60)
        let later = try await place(phone)
        XCTAssertEqual(later.status, 201, "after the 24 hour window: \(later.text)")
    }

    func testTCB101_MixOfReasonsAndNormalisedPhone() async throws {
        let codes = try await fill("0900000040", 5)
        try await cancel(Array(codes[0..<3]), reasons: ["cannot_deliver", "cannot_deliver", "fake_spam"])
        // counted: 1 spam + 2 open = 3, so two more fit, from either phone spelling
        let first = try await place("+84 900 000 040")
        let second = try await place("0900000040")
        let third = try await place("+84900000040")
        XCTAssertEqual([first.status, second.status, third.status], [201, 201, 429])
    }

    func testTCB103_SpamCancelAfterTheLimitWasHitCountsAtOnce() async throws {
        let phone = "0900000050"
        let codes = try await fill(phone, 5)
        try await cancel([codes[0]], reasons: ["customer_asked"])
        let accepted = try await place(phone)
        XCTAssertEqual(accepted.status, 201)
        // Now 5 counted again; marking one of the open orders spam changes nothing, a second cancel keeps its first reason.
        let owner = try await self.owner()
        let again = try await changeStatus(owner, codes[0], from: "Received", to: "Cancelled", reason: "fake_spam")
        XCTAssertNotEqual(again.status, 500)
        let stillRefused = try await place(phone)
        XCTAssertEqual(stillRefused.status, 429, "the first cancel reason is kept, so the second spam call must not add a counted order")
        let reason = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code = \(bind: codes[0]) AND cancel_reason = 'customer_asked'")
        XCTAssertEqual(reason, 1)
    }

    func testTCB104_ReplayWithSameKeyIsNotACountedOrderAndPerPhoneIsPerShopPhoneNotPerIp() async throws {
        let key = UUID(), phone = "0900000060"
        let first = try await customerOrder(date: dayOffset(4), phone: phone, key: key)
        let replay = try await customerOrder(date: dayOffset(4), phone: phone, key: key)
        XCTAssertEqual(first.status, 201)
        XCTAssertEqual(replay.status, 200)
        XCTAssertEqual(replay.header("Idempotent-Replay"), "true")
        XCTAssertEqual(replay.string("order_code"), first.string("order_code"))
        let stored = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID) AND customer_phone = '+84900000060'")
        XCTAssertEqual(stored, 1)
    }
}
