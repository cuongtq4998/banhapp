import BanhContracts
import XCTest
@testable import BanhApp

/// AC-6 and AC-14: the lines list only cakes above 0 and the total is the sum of the lines plus the fee.
final class OrderPricingTests: XCTestCase {
    private func catalog() throws -> CatalogResponse { try CatalogTestData.okCatalog() }

    private func draft(_ quantities: [Int], district: Int? = nil) throws -> OrderDraft {
        let catalog = try catalog()
        var draft = OrderDraft(savedAt: Date(timeIntervalSince1970: 0))
        for (index, quantity) in quantities.enumerated() {
            draft.setQuantity(quantity, of: catalog.products[index].productID, name: catalog.products[index].name)
        }
        draft.districtID = district.map { catalog.districts[$0].districtID }
        return draft
    }

    func testTotalIsTwoOfAPlusOneOfBPlusTheFee() throws {
        let catalog = try catalog()
        let pricing = OrderPricing(draft: try draft([2, 1], district: 2), catalog: catalog)
        let a = catalog.products[0].priceVND, b = catalog.products[1].priceVND, f = catalog.districts[2].deliveryFeeVND
        XCTAssertEqual(pricing.subtotalVND, 2 * a + b)
        XCTAssertEqual(pricing.deliveryFeeVND, f)
        XCTAssertEqual(pricing.totalVND, 2 * a + b + f)
        XCTAssertEqual(pricing.totalVND, 2 * 35_000 + 45_000 + 20_000)
    }

    func testOnlyCakesAboveZeroAreListed() throws {
        let pricing = OrderPricing(draft: try draft([2, 0, 3, 0]), catalog: try catalog())
        XCTAssertEqual(pricing.lines.map(\.quantity), [2, 3])
        XCTAssertEqual(pricing.cakeCount, 5)
    }

    func testNoDistrictMeansNoFeeYet() throws {
        let pricing = OrderPricing(draft: try draft([2]), catalog: try catalog())
        XCTAssertEqual(pricing.deliveryFeeVND, 0)
    }

    func testACakeMissingFromTheCatalogHasNoPrice() throws {
        var draft = try draft([2])
        draft.setQuantity(5, of: OrderTestSupport.id(999), name: "Gone")
        XCTAssertEqual(OrderPricing(draft: draft, catalog: try catalog()).cakeCount, 2)
    }

    func testMoneyAndDateUseTheVietnameseFormats() {
        XCTAssertEqual(MoneyFormatter.format(120_000), "120.000 ₫")
        XCTAssertEqual(ShopDate(iso: "2026-11-04")?.displayText, "04/11/2026")
    }
}
