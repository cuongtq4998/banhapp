import BanhContracts
import XCTest
@testable import BanhApp

/// Sending the order from S-8: AC-9, AC-19, AC-20, AC-22, AC-23, ADR-0008 v1.1 (key rules), ADR-0010.
@MainActor
final class OrderSubmitterTests: XCTestCase {
    private let created = PlacedOrder(code: "BT-7K3M9Q", isReplay: false)

    private func make(_ replies: [ScriptedOrderAPI.Reply], delay: Duration? = nil) async throws -> SubmitterFixture.Setup {
        try await SubmitterFixture.make(replies, delay: delay)
    }

    // MARK: Success

    func testASuccessfulSendPassesTheCodeOnAndForgetsTheDraft() async throws {
        let s = try await make([.success(created)])
        await s.submitter.send()

        XCTAssertEqual(s.placed.orders, [created])
        XCTAssertNil(s.store.load(now: OrderTestSupport.now), "the draft is deleted once the order is received")
        XCTAssertEqual(s.flow.draft.totalQuantity, 0)
        XCTAssertNil(s.submitter.activeNotice)
    }

    func testTheBodyHoldsWhatTheCustomerEnteredAndTheTotalTheyConfirmed() async throws {
        let s = try await make([.success(created)])
        await s.submitter.send()

        let body = try XCTUnwrap(s.api.calls.first?.body)
        XCTAssertEqual(body.items.map(\.quantity), [2, 1])
        XCTAssertEqual(body.items.map(\.productID), [OrderTestSupport.id(11), OrderTestSupport.id(12)])
        XCTAssertEqual(body.deliveryDate, "2026-11-04")
        XCTAssertEqual(body.slotID, OrderTestSupport.id(33))
        XCTAssertEqual(body.customer.name, "Nguyễn Văn An")
        XCTAssertEqual(body.customer.phone, "0912 345 678")
        XCTAssertEqual(body.customer.districtID, OrderTestSupport.id(23))
        XCTAssertNil(body.note)
        XCTAssertEqual(body.expectedTotalVND, 135_000)
    }

    // MARK: No double send (AC-19)

    func testTappingConfirmAgainWhileSendingSendsOnce() async throws {
        let s = try await make([.success(created)], delay: .milliseconds(200))
        async let first: Void = s.submitter.send()
        async let second: Void = s.submitter.send()
        async let third: Void = s.submitter.send()
        _ = await (first, second, third)

        XCTAssertEqual(s.api.calls.count, 1)
        XCTAssertEqual(s.placed.orders.count, 1)
    }

    func testTheButtonIsOffWhileSendingAndAfterItsAnswer() async throws {
        let s = try await make([.success(created)], delay: .milliseconds(200))
        let model = ReviewViewModel(flow: s.flow, submitter: s.submitter)
        XCTAssertTrue(model.canConfirm)
        let task = Task { await model.confirm() }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(model.isSending)
        XCTAssertFalse(model.canConfirm)
        await task.value
        XCTAssertFalse(model.canConfirm, "stays off until the screen is replaced")
    }

    // MARK: Not sent: the key stays (AC-20, ADR-0008)

    func testOfflineKeepsTheDataAndTheKeyAndARetrySendsTheSameKey() async throws {
        let s = try await make([.failure(.offline), .success(created)])
        let model = ReviewViewModel(flow: s.flow, submitter: s.submitter)

        await model.confirm()
        let key = s.flow.draft.idempotencyKey
        XCTAssertEqual(model.notice, .offline)
        XCTAssertTrue(model.canConfirm, "retry is possible")
        XCTAssertTrue(s.placed.orders.isEmpty)
        XCTAssertEqual(s.flow.draft.name, " Nguyễn Văn An ")

        await model.confirm()
        XCTAssertEqual(s.api.keys, [key, key], "a pure retry keeps the key")
        XCTAssertEqual(s.placed.orders, [created])
    }

    func testATimeoutThenARetryUsesTheSameKeyAndTheServerReplays() async throws {
        let replay = PlacedOrder(code: "BT-7K3M9Q", isReplay: true)
        let s = try await make([.failure(.timeout), .success(replay)])
        await s.submitter.send()
        XCTAssertEqual(s.submitter.activeNotice, .timeout)
        await s.submitter.send()

        XCTAssertEqual(Set(s.api.keys).count, 1)
        XCTAssertEqual(s.placed.orders, [replay])
    }

    func testServerAndRateLimitErrorsAreNotSentMessagesWithRetry() async throws {
        let s = try await make([.failure(.server(.serviceUnavailable)), .failure(.rateLimited(retryAfterSeconds: 3600)), .success(created)])
        await s.submitter.send()
        let key = s.flow.draft.idempotencyKey
        XCTAssertEqual(s.submitter.activeNotice, .server)
        await s.submitter.send()
        XCTAssertEqual(s.submitter.activeNotice, .rateLimited(retryAfterSeconds: 3600))
        XCTAssertFalse(s.submitter.isBlocked)
        await s.submitter.send()
        XCTAssertEqual(s.api.keys, [key, key, key])
        XCTAssertEqual(s.placed.orders.count, 1)
    }

    func testAnAnswerThatCannotBeUsedNeverShowsTheConfirmation() async throws {
        let s = try await make([.failure(.server(.internalError))])
        await s.submitter.send()
        XCTAssertTrue(s.placed.orders.isEmpty)
        XCTAssertEqual(s.submitter.activeNotice, .server)
    }

    // MARK: Key rules (ADR-0008 v1.1)

    func testAReusedKeyIsReplacedAndSentOnceMore() async throws {
        let s = try await make([.failure(.keyReused), .success(created)])
        let key = s.flow.draft.idempotencyKey
        await s.submitter.send()

        XCTAssertEqual(s.api.calls.count, 2)
        XCTAssertNotEqual(s.api.keys[1], key)
        XCTAssertEqual(s.placed.orders, [created])
    }

    func testAKeyReusedTwiceStopsWithTheServerMessage() async throws {
        let s = try await make([.failure(.keyReused)])
        await s.submitter.send()
        XCTAssertEqual(s.api.calls.count, 2, "one retry only")
        XCTAssertEqual(s.submitter.activeNotice, .server)
        XCTAssertTrue(s.placed.orders.isEmpty)
    }

    func testChangingTheOrderAfterAFailureSendsANewKey() async throws {
        let s = try await make([.failure(.timeout), .success(created)])
        await s.submitter.send()
        s.flow.setNote("Giao sớm")
        await s.submitter.send()
        XCTAssertNotEqual(s.api.keys[0], s.api.keys[1])
    }

}
