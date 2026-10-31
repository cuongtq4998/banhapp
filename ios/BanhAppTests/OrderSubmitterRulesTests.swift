import BanhContracts
import XCTest
@testable import BanhApp

/// Price change, rule errors and field errors of a send: AC-9, AC-13, AC-22, AC-23, ADR-0010.
@MainActor
final class OrderSubmitterRulesTests: XCTestCase {
    private let created = PlacedOrder(code: "BT-7K3M9Q", isReplay: false)

    private func make(_ replies: [ScriptedOrderAPI.Reply], delay: Duration? = nil) async throws -> SubmitterFixture.Setup {
        try await SubmitterFixture.make(replies, delay: delay)
    }

    private func priceChange() -> PriceChangedDetails {
        PriceChangedDetails(
            items: [.init(productID: OrderTestSupport.id(11), priceVND: 40_000),
                    .init(productID: OrderTestSupport.id(12), priceVND: 45_000)],
            deliveryFeeVND: 20_000, totalVND: 145_000
        )
    }

    // MARK: Price changed (AC-23, ADR-0010)

    func testPriceChangedReplacesThePricesAndTheNextConfirmSendsTheNewTotal() async throws {
        let s = try await make([.failure(.priceChanged(priceChange())), .success(created)])
        let model = ReviewViewModel(flow: s.flow, submitter: s.submitter)
        let firstKey = s.flow.draft.idempotencyKey

        await model.confirm()

        XCTAssertEqual(model.notice, .priceChanged)
        XCTAssertTrue(model.canConfirm, "confirm stays enabled")
        guard case .ready(let summary) = model.summary else { return XCTFail("summary") }
        XCTAssertEqual(summary.totalText, "145.000 ₫")
        XCTAssertEqual(summary.lines.map(\.unitPriceVND), [40_000, 45_000])
        XCTAssertEqual(model.highlight, PriceHighlight(productIDs: [OrderTestSupport.id(11)], fee: false, total: true))
        XCTAssertNotEqual(s.flow.draft.idempotencyKey, firstKey, "the body changed: a new key")
        XCTAssertEqual(s.flow.draft.expectedTotalVND, 145_000)
        XCTAssertTrue(s.placed.orders.isEmpty)

        await model.confirm()
        XCTAssertEqual(s.api.calls[1].body.expectedTotalVND, 145_000)
        XCTAssertNotEqual(s.api.keys[1], firstKey)
        XCTAssertEqual(s.placed.orders, [created])
    }

    func testChangingQuantitiesDropsTheServerPricesAndTheHighlight() async throws {
        let s = try await make([.failure(.priceChanged(priceChange()))])
        let model = ReviewViewModel(flow: s.flow, submitter: s.submitter)
        await model.confirm()
        model.edit()
        XCTAssertNil(model.notice)
        XCTAssertTrue(model.highlight.isEmpty)
        s.flow.setQuantity(3, of: OrderTestSupport.product(0, in: s.flow))
        XCTAssertNil(s.flow.priceOverride)
    }

    // MARK: Rule errors (AC-9, AC-13, AC-22)

    func testARuleErrorBlocksConfirmUntilTheOrderChanges() async throws {
        let s = try await make([.failure(.dateCapacity(deliveryDate: "2026-11-04")), .success(created)])
        let model = ReviewViewModel(flow: s.flow, submitter: s.submitter)
        await model.confirm()

        XCTAssertEqual(model.notice, .dateCapacity(deliveryDate: "04/11/2026"))
        XCTAssertTrue(model.notice?.message.contains("04/11/2026") == true)
        XCTAssertEqual(model.notice?.fixStep, .date)
        XCTAssertFalse(model.canConfirm)
        await model.confirm()
        XCTAssertEqual(s.api.calls.count, 1, "blocked: nothing is sent")

        s.flow.setDate(ShopDate(year: 2026, month: 11, day: 6))
        XCTAssertNil(model.notice)
        XCTAssertTrue(model.canConfirm)
        XCTAssertEqual(s.flow.draft.name, " Nguyễn Văn An ", "all entered data is kept")
    }

    func testEachRuleErrorSendsTheCustomerToTheStepThatFixesIt() async throws {
        let cases: [(OrderFailure, SendNotice, OrderStep)] = [
            (.minQty(2), .minQty(2), .cakes), (.dateLead(days: 2), .dateLead(days: 2), .date),
            (.dateHorizon(maxDays: 30), .dateHorizon(maxDays: 30), .date),
            (.districtUnserved, .districtUnserved, .recipient), (.slotUnavailable, .slotUnavailable, .date),
        ]
        for (failure, notice, step) in cases {
            let s = try await make([.failure(failure)])
            await s.submitter.send()
            XCTAssertEqual(s.submitter.activeNotice, notice)
            XCTAssertEqual(s.submitter.activeNotice?.fixStep, step)
            XCTAssertEqual(s.submitter.activeNotice?.kind, .rule)
            XCTAssertNotNil(s.submitter.activeNotice?.actionTitle)
        }
    }

    func testAMissingCakeIsDroppedAloneAndTheRestIsKept() async throws {
        let s = try await make([.failure(.productUnavailable([OrderTestSupport.id(12)]))])
        let key = s.flow.draft.idempotencyKey
        await s.submitter.send()

        XCTAssertEqual(s.flow.draft.quantity(of: OrderTestSupport.id(12)), 0)
        XCTAssertEqual(s.flow.draft.quantity(of: OrderTestSupport.id(11)), 2)
        XCTAssertEqual(s.flow.removedCakeNames, ["Bánh đậu xanh nhân mỡ"])
        XCTAssertEqual(s.submitter.activeNotice, .productUnavailable, "the banner stays, with the action to S-5")
        XCTAssertNotEqual(s.flow.draft.idempotencyKey, key)
        XCTAssertEqual(s.flow.draft.name, " Nguyễn Văn An ")
    }

    // MARK: Field errors (VALIDATION_FAILED)

    func testFieldErrorsGoToTheRecipientStepAndShowNextToTheirFields() async throws {
        let fields = [
            APIErrorResponse.FieldError(field: "customer.name", code: "NAME_REQUIRED", messageKey: "ERR_NAME_REQUIRED"),
            APIErrorResponse.FieldError(field: "customer.phone", code: "PHONE_INVALID", messageKey: "ERR_PHONE_INVALID"),
            APIErrorResponse.FieldError(field: "items", code: "ITEMS_INVALID", messageKey: "ERR_SERVER"),
        ]
        let s = try await make([.failure(.validation(fields))])
        await s.submitter.send()
        XCTAssertTrue(s.submitter.fieldsRejected)
        XCTAssertFalse(s.submitter.isSending)

        let recipient = RecipientViewModel(flow: s.flow)
        recipient.adoptServerErrors()
        XCTAssertEqual(recipient.problems[.name], .nameRequired)
        XCTAssertEqual(recipient.problems[.phone], .phoneInvalid)
        XCTAssertEqual(recipient.problems.count, 2)
        XCTAssertEqual(recipient.focusRequest, .name)
        XCTAssertTrue(s.flow.serverFieldErrors.isEmpty, "shown once")
    }

    func testFieldErrorsS7CannotShowBecomeANotSentMessage() async throws {
        let odd = APIErrorResponse.FieldError(field: "items[0].quantity", code: "QUANTITY_INVALID", messageKey: "ERR_SERVER")
        let s = try await make([.failure(.validation([odd]))])
        await s.submitter.send()
        XCTAssertFalse(s.submitter.fieldsRejected)
        XCTAssertEqual(s.submitter.activeNotice, .server)
    }

    func testEveryNoticeHasItsOwnTextAndOnlyTheSendErrorsOfKindBHaveRetry() {
        let notices: [SendNotice] = [
            .minQty(2), .dateCapacity(deliveryDate: "04/11/2026"), .dateLead(days: 2), .dateHorizon(maxDays: 30),
            .districtUnserved, .productUnavailable, .slotUnavailable, .offline, .timeout, .server,
            .rateLimited(retryAfterSeconds: 60), .priceChanged,
        ]
        XCTAssertEqual(Set(notices.map(\.message)).count, notices.count)
        for notice in notices where notice.kind == .notSent {
            XCTAssertNil(notice.fixStep)
            XCTAssertEqual(String(localized: try XCTUnwrap(notice.actionTitle)), "Thử lại")
        }
        XCTAssertNil(SendNotice.priceChanged.actionTitle)
    }
}
