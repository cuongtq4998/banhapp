import BanhContracts
import XCTest
@testable import BanhApp

@MainActor
final class CatalogScreenModelTests: XCTestCase {
    private let base = URL(string: "http://localhost:8080")!

    private func repository(with catalog: CatalogResponse) async -> CatalogRepository {
        let repository = CatalogRepository(
            api: StubCatalogAPI([.success(.modified(catalog, etag: nil))]), cache: InMemoryCatalogCache()
        )
        await repository.refresh()
        return repository
    }

    func testProductListShowsEveryActiveCakeFromOneToFour() async throws {
        for count in 1...4 {
            let repository = await repository(with: try CatalogTestData.catalog(productCount: count))
            let model = ProductsScreenModel.products(repository: repository, assetBaseURL: base)
            guard case .ready(let items) = model.state else { return XCTFail("\(count) products should be ready") }
            XCTAssertEqual(items.count, count)
        }
    }

    func testProductListIsAnErrorOnlyWhenEmpty() async throws {
        let repository = await repository(with: try CatalogTestData.catalog(productCount: 0))
        let model = ProductsScreenModel.products(repository: repository, assetBaseURL: base)
        XCTAssertEqual(model.state, .failed(.other))
    }

    func testProductItemsCarryFormattedPriceAndTheVersionedImageURL() async throws {
        let repository = await repository(with: try CatalogTestData.okCatalog())
        let model = ProductsScreenModel.products(repository: repository, assetBaseURL: base)
        guard case .ready(let items) = model.state, let first = items.first else { return XCTFail("Expected items") }
        XCTAssertEqual(first.name, "Bánh chuối")
        XCTAssertEqual(first.priceText, "35.000 ₫")
        XCTAssertEqual(first.imageURL?.absoluteString, "http://localhost:8080/assets/images/banana.png?v=a547ade3")
    }

    func testDetailFindsTheCakeById() async throws {
        let catalog = try CatalogTestData.okCatalog()
        let repository = await repository(with: catalog)
        let target = catalog.products[2]
        let model = ProductDetailScreenModel.product(id: target.productID, repository: repository, assetBaseURL: base)
        guard case .ready(let item) = model.state else { return XCTFail("Expected the cake") }
        XCTAssertEqual(item.name, target.name)
    }

    func testDetailOfAnUnknownCakeIsAFailedLoad() async throws {
        let repository = await repository(with: try CatalogTestData.okCatalog())
        let unknown = ResourceID(UUID())
        let model = ProductDetailScreenModel.product(id: unknown, repository: repository, assetBaseURL: base)
        XCTAssertEqual(model.state, .failed(.other))
    }

    func testStateFollowsTheRepositoryWhileLoadingAndAfterFailure() async {
        let failing = CatalogRepository(api: StubCatalogAPI([.failure(.networkUnavailable)]), cache: InMemoryCatalogCache())
        let model = ProductsScreenModel.products(repository: failing, assetBaseURL: base)
        XCTAssertEqual(model.state, .loading)
        await model.retry()
        XCTAssertEqual(model.state, .failed(.network))
    }

    func testLoadFailureTextNamesTheNetworkOnlyOffline() {
        XCTAssertEqual(
            String(localized: Strings.catalogLoadFailure(.network, screenMessage: Strings.productsError)),
            String(localized: Strings.errorNetworkLoad)
        )
        XCTAssertEqual(
            String(localized: Strings.catalogLoadFailure(.other, screenMessage: Strings.productsError)),
            String(localized: Strings.productsError)
        )
    }
}
