import BanhContracts
import XCTest
@testable import BanhApp

/// S-8: AC-6, AC-13, AC-14, AC-26, AC-31 and the blocking rules shown at the top.
@MainActor
final class ReviewViewModelTests: XCTestCase {
    private func complete(quantities: [Int] = [2, 1, 0, 0]) async throws -> (ReviewViewModel, OrderFlow) {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        for (index, quantity) in quantities.enumerated() {
            draft.setQuantity(quantity, of: ok.products[index].productID, name: ok.products[index].name)
        }
        draft.date = ShopDate(year: 2026, month: 11, day: 4)
        draft.slotID = OrderTestSupport.id(33)
        draft.name = " Nguyễn Văn An "
        draft.phone = "0912345678"
        draft.address = "12 Đường Số 3"
        draft.districtID = OrderTestSupport.id(23)
        draft.note = "Giao sau 14 giờ"
        let flow = try await OrderTestSupport.flow(draft: draft)
        return (ReviewViewModel(flow: flow), flow)
    }

    private func summary(_ model: ReviewViewModel) throws -> ReviewViewModel.Summary {
        guard case .ready(let summary) = model.summary else { throw XCTSkip("Not ready") }
        return summary
    }

    func testTotalIsTwoAPlusBPlusTheDistrictFee() async throws {
        let (model, _) = try await complete()
        let summary = try summary(model)
        XCTAssertEqual(summary.totalText, "\(MoneyFormatter.grouped(2 * 35_000 + 45_000 + 20_000)) ₫")
        XCTAssertEqual(summary.feeText, "20.000 ₫")
        XCTAssertEqual(summary.lines.map(\.quantity), [2, 1])
    }

    func testShowsDateTimeAndRecipientInTheVietnameseFormats() async throws {
        let (model, _) = try await complete()
        let summary = try summary(model)
        XCTAssertEqual(summary.dateText, "04/11/2026")
        XCTAssertEqual(summary.timeText, "14:00 – 16:00")
        XCTAssertEqual(summary.name, "Nguyễn Văn An")
        XCTAssertEqual(summary.phone, "0912345678")
        XCTAssertEqual(summary.address, "12 Đường Số 3, Quận 5")
        XCTAssertEqual(summary.note, "Giao sau 14 giờ")
    }

    func testTheNoteRowIsAbsentWithoutANote() async throws {
        let (model, flow) = try await complete()
        flow.setNote("  ")
        XCTAssertNil(try summary(model).note)
    }

    func testACompleteOrderHasNoBlocker() async throws {
        let (model, _) = try await complete()
        XCTAssertNil(model.blocker)
    }

    func testConfirmStaysDisabledUntilTheOrderCreationSliceWiresIt() async throws {
        let (model, _) = try await complete()
        XCTAssertFalse(model.canConfirm)
        model.confirm()
        var sent = 0
        let wired = ReviewViewModel(flow: try await complete().1, confirmAction: { sent += 1 })
        XCTAssertTrue(wired.canConfirm)
        wired.confirm()
        XCTAssertEqual(sent, 1)
    }

    func testOneCakeIsBlockedWithTheMinimumMessage() async throws {
        let (model, _) = try await complete(quantities: [1, 0, 0, 0])
        let blocker = try XCTUnwrap(model.blocker)
        XCTAssertEqual(blocker.step, .cakes)
        XCTAssertEqual(blocker.message, "Đơn hàng cần ít nhất 2 bánh. Vui lòng thêm bánh.")
        let wired = ReviewViewModel(flow: try await complete(quantities: [1, 0, 0, 0]).1, confirmAction: {})
        XCTAssertFalse(wired.canConfirm)
    }

    func testTwoCakesRaiseNoQuantityError() async throws {
        let (model, _) = try await complete(quantities: [2, 0, 0, 0])
        XCTAssertNil(model.blocker)
    }

    func testACakeHiddenByTheShopBlocksAndKeepsTheData() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(2, of: ok.products[1].productID, name: ok.products[1].name)
        draft.setQuantity(2, of: ok.products[0].productID, name: ok.products[0].name)
        draft.name = "An"
        let flow = try await OrderTestSupport.flow(catalog: OrderTestSupport.catalog(without: [1]), draft: draft)
        let model = ReviewViewModel(flow: flow)
        XCTAssertEqual(model.blocker?.step, .cakes)
        XCTAssertEqual(try summary(model).lines.count, 1)
        XCTAssertEqual(flow.draft.name, "An")
    }

    func testMissingDateSlotOrDistrictSendBackToTheStepThatFixesIt() async throws {
        let (model, flow) = try await complete()
        flow.setDistrict(OrderTestSupport.id(999))
        XCTAssertEqual(model.blocker?.step, .recipient)
        flow.setSlot(OrderTestSupport.id(999))
        XCTAssertEqual(model.blocker?.step, .date)
        flow.setDate(nil)
        XCTAssertEqual(model.blocker?.step, .date)
    }

    func testNoTextOnTheReviewMentionsPayment() async throws {
        let (model, _) = try await complete()
        let texts = [OrderStrings.reviewPrivacy, OrderStrings.confirm].map { String(localized: $0).lowercased() }
        for forbidden in ["thanh toán", "chuyển khoản", "payment"] {
            XCTAssertFalse(texts.contains { $0.contains(forbidden) })
        }
        XCTAssertNil(model.blocker)
    }
}
