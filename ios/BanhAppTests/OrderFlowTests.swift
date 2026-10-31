import BanhContracts
import XCTest
@testable import BanhApp

@MainActor
final class OrderFlowTests: XCTestCase {
    func testEveryChangeIsSavedToTheStore() async throws {
        let store = InMemoryDraftStore()
        let flow = try await OrderTestSupport.flow(store: store)
        flow.setQuantity(2, of: OrderTestSupport.product(0, in: flow))
        flow.setName("An")
        flow.setPhone("0912345678")
        flow.setAddress("12 Đường Số 3")
        flow.setNote("Giao sớm")
        flow.setDate(ShopDate(year: 2026, month: 11, day: 4))
        flow.setSlot(OrderTestSupport.id(31))
        flow.setDistrict(OrderTestSupport.id(21))

        XCTAssertEqual(store.load(now: OrderTestSupport.now), flow.draft)
        XCTAssertEqual(flow.draft.totalQuantity, 2)
        XCTAssertEqual(flow.draft.note, "Giao sớm")
    }

    func testQuantitiesOfSeveralCakesAreKeptPerCake() async throws {
        let flow = try await OrderTestSupport.flow()
        flow.setQuantity(2, of: OrderTestSupport.product(0, in: flow))
        flow.setQuantity(3, of: OrderTestSupport.product(2, in: flow))
        flow.setQuantity(0, of: OrderTestSupport.product(0, in: flow))
        XCTAssertEqual(flow.draft.quantity(of: OrderTestSupport.product(0, in: flow).productID), 0)
        XCTAssertEqual(flow.draft.quantity(of: OrderTestSupport.product(2, in: flow).productID), 3)
        XCTAssertEqual(flow.draft.totalQuantity, 3)
    }

    func testAHiddenCakeIsDroppedAloneAndTheRestOfTheDraftStays() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        for (index, quantity) in [2, 1, 0, 3].enumerated() {
            draft.setQuantity(quantity, of: ok.products[index].productID, name: ok.products[index].name)
        }
        draft.date = ShopDate(year: 2026, month: 11, day: 4)
        draft.slotID = OrderTestSupport.id(32)
        draft.name = "An"
        draft.districtID = OrderTestSupport.id(22)
        let oldKey = draft.idempotencyKey

        // The shop hid the second cake (BR-13, AC-34).
        let flow = try await OrderTestSupport.flow(catalog: OrderTestSupport.catalog(without: [1]), draft: draft)
        flow.reconcileWithCatalog()

        XCTAssertEqual(flow.removedCakeNames, [ok.products[1].name])
        XCTAssertEqual(flow.draft.items.map(\.quantity), [2, 0, 3])
        XCTAssertEqual(flow.draft.date, ShopDate(year: 2026, month: 11, day: 4))
        XCTAssertEqual(flow.draft.slotID, OrderTestSupport.id(32))
        XCTAssertEqual(flow.draft.name, "An")
        XCTAssertEqual(flow.draft.districtID, OrderTestSupport.id(22))
        XCTAssertNotEqual(flow.draft.idempotencyKey, oldKey)
    }

    func testAHiddenCakeWithQuantityZeroIsDroppedWithoutANoticeOrNewKey() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(0, of: ok.products[1].productID, name: ok.products[1].name)
        let key = draft.idempotencyKey
        let flow = try await OrderTestSupport.flow(catalog: OrderTestSupport.catalog(without: [1]), draft: draft)
        flow.reconcileWithCatalog()
        XCTAssertTrue(flow.removedCakeNames.isEmpty)
        XCTAssertEqual(flow.draft.idempotencyKey, key)
    }

    func testChangingAQuantityDismissesTheRemovedNotice() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(2, of: ok.products[1].productID, name: ok.products[1].name)
        let flow = try await OrderTestSupport.flow(catalog: OrderTestSupport.catalog(without: [1]), draft: draft)
        flow.reconcileWithCatalog()
        XCTAssertFalse(flow.removedCakeNames.isEmpty)
        flow.setQuantity(1, of: OrderTestSupport.product(0, in: flow))
        XCTAssertTrue(flow.removedCakeNames.isEmpty)
    }

    func testAnEmptyCatalogKeepsTheDraft() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(2, of: ok.products[0].productID, name: ok.products[0].name)
        let empty = try Fixtures.decode(CatalogResponse.self, from: "catalog-empty.json")
        let flow = try await OrderTestSupport.flow(catalog: empty, draft: draft)
        flow.reconcileWithCatalog()
        XCTAssertEqual(flow.draft.totalQuantity, 2)
        XCTAssertTrue(flow.removedCakeNames.isEmpty)
    }

    func testDiscardClearsTheStoreAndStartsEmpty() async throws {
        let store = InMemoryDraftStore()
        let flow = try await OrderTestSupport.flow(store: store)
        flow.setName("An")
        flow.discardDraft()
        XCTAssertNil(store.load(now: OrderTestSupport.now))
        XCTAssertEqual(flow.draft.name, "")
    }

    // MARK: Idempotency key (ADR-0008 v1.1)

    func testEveryBodyFieldChangeReplacesTheKey() async throws {
        let flow = try await OrderTestSupport.flow()
        let product = OrderTestSupport.product(0, in: flow)
        let changes: [(String, () -> Void)] = [
            ("quantity", { flow.setQuantity(2, of: product) }),
            ("quantity again", { flow.setQuantity(3, of: product) }),
            ("date", { flow.setDate(ShopDate(year: 2026, month: 11, day: 4)) }),
            ("slot", { flow.setSlot(OrderTestSupport.id(31)) }),
            ("name", { flow.setName("An") }),
            ("phone", { flow.setPhone("0912345678") }),
            ("address", { flow.setAddress("12 Đường Số 3") }),
            ("district", { flow.setDistrict(OrderTestSupport.id(21)) }),
            ("note", { flow.setNote("Giao sớm") }),
            ("expected total", { flow.applyPriceChange(expectedTotalVND: 135_000) })
        ]
        for (field, change) in changes {
            let before = flow.draft.idempotencyKey
            change()
            XCTAssertNotEqual(flow.draft.idempotencyKey, before, "\(field) must replace the key")
        }
    }

    func testAPureRetryKeepsTheKey() async throws {
        let store = InMemoryDraftStore()
        let flow = try await OrderTestSupport.flow(store: store)
        flow.setQuantity(2, of: OrderTestSupport.product(0, in: flow))
        flow.setName("An")
        let key = flow.draft.idempotencyKey
        // Same values written again, a quantity-0 cake added, a catalog refresh: the body is the same.
        flow.setName("An")
        flow.setQuantity(2, of: OrderTestSupport.product(0, in: flow))
        flow.setQuantity(0, of: OrderTestSupport.product(1, in: flow))
        flow.reconcileWithCatalog()
        XCTAssertEqual(flow.draft.idempotencyKey, key)
        // An app restart reloads the same draft with the same key.
        XCTAssertEqual(store.load(now: OrderTestSupport.now)?.idempotencyKey, key)
    }

    func testTheSavedDraftAlwaysHoldsTheKeyOfItsContent() async throws {
        let store = InMemoryDraftStore()
        let flow = try await OrderTestSupport.flow(store: store)
        flow.setNote("a")
        XCTAssertEqual(store.load(now: OrderTestSupport.now)?.idempotencyKey, flow.draft.idempotencyKey)
    }

    func testKeyReusedReplacesTheKeyWithoutChangingTheBody() async throws {
        let flow = try await OrderTestSupport.flow()
        flow.setName("An")
        let body = flow.draft.requestBody
        let key = flow.draft.idempotencyKey
        flow.replaceIdempotencyKey()
        XCTAssertNotEqual(flow.draft.idempotencyKey, key)
        XCTAssertEqual(flow.draft.requestBody, body)
    }
}
