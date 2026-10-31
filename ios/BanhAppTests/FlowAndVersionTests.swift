import BanhContracts
import XCTest
@testable import BanhApp

/// Smaller pieces of slice 3: the version header, the timeout helper, the draft's request body, S-9.
@MainActor
final class SendSupportTests: XCTestCase {
    func testTheVersionHeaderIsThreeGroupsOfDigits() {
        XCTAssertEqual(BuildConfiguration.headerVersion("1.0"), "1.0.0")
        XCTAssertEqual(BuildConfiguration.headerVersion("2"), "2.0.0")
        XCTAssertEqual(BuildConfiguration.headerVersion("1.2.3"), "1.2.3")
        for bad in ["1.2.3.4", "1.0-beta", "v1.0", "", "1..2", "123456.0", "a.b.c"] {
            XCTAssertEqual(BuildConfiguration.headerVersion(bad), "0.0.0", bad)
        }
    }

    func testTheBuildVersionPassesTheServersHeaderRule() throws {
        let host = try XCTUnwrap(Bundle(identifier: "app.banh.customer"))
        let version = BuildConfiguration.appVersion(in: host)
        XCTAssertNotNil(version.wholeMatch(of: /[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}/), version)
    }

    func testTimeoutReturnsAFastResultAndCutsASlowOne() async throws {
        let fast = try await withTimeout(.seconds(5)) { 7 }
        XCTAssertEqual(fast, 7)
        do {
            _ = try await withTimeout(.milliseconds(50)) {
                try await Task.sleep(for: .seconds(30))
                return 1
            }
            XCTFail("Expected a timeout")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testAnEmptyNoteIsSentAsNullAndTextsAreTrimmed() throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        draft.setQuantity(2, of: OrderTestSupport.id(11), name: "Bánh chuối")
        draft.setQuantity(0, of: OrderTestSupport.id(12), name: "x")
        draft.date = ShopDate(year: 2026, month: 11, day: 4)
        draft.slotID = OrderTestSupport.id(33)
        draft.name = "  An "
        draft.phone = "0912345678"
        draft.address = " 1 Đường Số 5 "
        draft.districtID = OrderTestSupport.id(21)
        draft.note = "   "
        XCTAssertNil(draft.orderRequest(), "no acknowledged total yet")
        draft.expectedTotalVND = 85_000
        let body = try XCTUnwrap(draft.orderRequest())
        XCTAssertEqual(body.items, [OrderItemRequest(productID: OrderTestSupport.id(11), quantity: 2)])
        XCTAssertNil(body.note)
        XCTAssertEqual(body.customer.name, "An")
        XCTAssertEqual(body.customer.address, "1 Đường Số 5")
        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        XCTAssertTrue(json.contains("\"note\":null"))
    }

    func testPriceChangedFixtureFeedsThePricing() async throws {
        let details = try JSONDecoder().decode(
            APIErrorResponse.self, from: Fixtures.data("order-error-price-changed.json")
        ).error.details
        XCTAssertNotNil(details["items"])
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        draft.setQuantity(2, of: OrderTestSupport.id(11), name: "Bánh chuối")
        draft.districtID = OrderTestSupport.id(23)
        let pricing = OrderPricing(draft: draft, catalog: try CatalogTestData.okCatalog())
        let changed = pricing.applying(PriceChangedDetails(
            items: [.init(productID: OrderTestSupport.id(11), priceVND: 55_000)], deliveryFeeVND: 20_000, totalVND: 130_000
        ))
        XCTAssertEqual(changed.totalVND, 130_000)
    }

    func testTheConfirmationHoldsTheCodeAndOpensTheShopContacts() async throws {
        let opener = RecordingOpener()
        let model = ConfirmationViewModel(
            code: "BT-7K3M9Q", repository: await OrderTestSupport.repository(try CatalogTestData.okCatalog()),
            contact: ContactActions(opener: opener)
        )
        XCTAssertEqual(model.code, "BT-7K3M9Q")
        XCTAssertEqual(model.spokenLabel, "Mã đơn hàng BT-7K3M9Q")
        XCTAssertTrue(model.contactsEnabled)
        await model.openZalo()
        await model.openPhone()
        XCTAssertEqual(opener.opened.map(\.scheme), ["https", "tel"])
        XCTAssertNil(model.contact.failure)
    }

    func testAContactThatCannotOpenShowsTheToastMessage() async throws {
        let opener = RecordingOpener(opens: false)
        let model = ConfirmationViewModel(
            code: "BT-7K3M9Q", repository: await OrderTestSupport.repository(try CatalogTestData.okCatalog()),
            contact: ContactActions(opener: opener)
        )
        await model.openZalo()
        XCTAssertEqual(model.contact.failure, .zalo)
    }

    func testTheConfirmationTextsMakeNoPromiseAndMentionNoPayment() {
        let texts = [SendStrings.confirmationTitle, SendStrings.confirmationMessage, SendStrings.confirmationHome]
            .map { String(localized: $0).lowercased() }
        for forbidden in ["chấp nhận", "đảm bảo", "thanh toán", "chuyển khoản"] {
            XCTAssertFalse(texts.contains { $0.contains(forbidden) }, forbidden)
        }
    }
}

@MainActor
private final class RecordingOpener: URLOpener {
    private(set) var opened: [URL] = []
    private let opens: Bool

    init(opens: Bool = true) { self.opens = opens }

    func open(_ url: URL) async -> Bool {
        opened.append(url)
        return opens
    }
}
