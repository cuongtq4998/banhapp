import BanhContracts
import XCTest
@testable import BanhApp

/// S-5: AC-6, AC-13 (Next needs the minimum), the 99 bound, and the 1 to 4 cake cases of BR-13.
@MainActor
final class CakesViewModelTests: XCTestCase {
    private let assetBase = URL(string: "http://localhost:9")!

    private func model(catalog: CatalogResponse? = nil, draft: OrderDraft? = nil) async throws -> (CakesViewModel, OrderFlow) {
        let flow = try await OrderTestSupport.flow(catalog: catalog, draft: draft)
        return (CakesViewModel(flow: flow, assetBaseURL: assetBase), flow)
    }

    private func rows(_ model: CakesViewModel) throws -> [CakesViewModel.Row] {
        guard case .ready(let rows) = model.rows else { throw XCTSkip("Not ready") }
        return rows
    }

    func testFirstStateHasEveryCakeAtZeroAndNextDisabled() async throws {
        let (model, _) = try await model()
        let rows = try rows(model)
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows.allSatisfy { $0.quantity == 0 && !$0.canDecrease })
        XCTAssertEqual(model.totalCakes, 0)
        XCTAssertTrue(model.showsMinHint)
        XCTAssertFalse(model.canContinue)
    }

    func testNextNeedsTheMinimumOfTwoCakes() async throws {
        let (model, _) = try await model()
        model.increase(try rows(model)[0])
        XCTAssertEqual(model.totalCakes, 1)
        XCTAssertFalse(model.canContinue)
        XCTAssertTrue(model.showsMinHint)
        XCTAssertEqual(model.minQty, 2)

        model.increase(try rows(model)[0])
        XCTAssertTrue(model.canContinue)
        XCTAssertFalse(model.showsMinHint)
    }

    func testQuantitiesTwoZeroThreeZeroGiveTwoLinesInThePricing() async throws {
        let (model, flow) = try await model()
        for (index, quantity) in [2, 0, 3, 0].enumerated() {
            for _ in 0..<quantity { model.increase(try rows(model)[index]) }
        }
        XCTAssertEqual(flow.pricing?.lines.map(\.quantity), [2, 3])
        XCTAssertEqual(model.subtotalText, "\(MoneyFormatter.grouped(2 * 35_000 + 3 * 45_000)) ₫")
    }

    func testMinusStopsAtZeroAndPlusStopsAtNinetyNineWithoutAMessage() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(99, of: ok.products[0].productID, name: ok.products[0].name)
        let (model, _) = try await model(draft: draft)
        let first = try rows(model)[0]
        XCTAssertFalse(first.canIncrease)
        model.increase(first)
        XCTAssertEqual(try rows(model)[0].quantity, 99)

        let second = try rows(model)[1]
        model.decrease(second)
        XCTAssertEqual(try rows(model)[1].quantity, 0)
    }

    func testOneToFourActiveCakesEachShowOnlyTheirOwnRows() async throws {
        for count in 1...4 {
            let hidden = Set(count..<4)
            let (model, _) = try await model(catalog: OrderTestSupport.catalog(without: hidden))
            XCTAssertEqual(try rows(model).count, count)
        }
    }

    func testZeroActiveCakesIsTheEmptyStateAndNextStaysDisabled() async throws {
        let empty = try Fixtures.decode(CatalogResponse.self, from: "catalog-empty.json")
        let (model, _) = try await model(catalog: empty)
        XCTAssertEqual(try rows(model), [])
        XCTAssertFalse(model.canContinue)
    }

    func testRestoredDraftQuantitiesAreShown() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(4, of: ok.products[3].productID, name: ok.products[3].name)
        let (model, _) = try await model(draft: draft)
        XCTAssertEqual(try rows(model).map(\.quantity), [0, 0, 0, 4])
        XCTAssertTrue(model.canContinue)
    }

    func testRowsCarryTheFormattedPrice() async throws {
        let (model, _) = try await model()
        XCTAssertEqual(try rows(model)[0].priceText, "35.000 ₫")
    }
}
