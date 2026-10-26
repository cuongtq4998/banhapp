#if DEBUG
import BanhContracts
import Foundation

/// An in-process backend for the UI tests, chosen by the launch argument `-BanhStubBackend <mode>`.
/// Compiled into debug builds only, so a release build cannot be pointed away from the real API.
/// The data is fake and mirrors `contracts/fixtures/catalog-ok.json`.
enum UITestStub {
    /// Pictures resolve to a port nothing listens on, so they fail at once and the placeholder shows.
    private static let unreachableAssetBase = URL(string: "http://localhost:9")!

    @MainActor
    static func environment(for mode: String?) -> AppEnvironment? {
        let api: any CatalogAPI
        switch mode {
        case LaunchArgument.stubModeCatalog: api = StubCatalogAPI(result: .success(fakeCatalog))
        case LaunchArgument.stubModeUnavailable: api = StubCatalogAPI(result: .failure(.networkUnavailable))
        default: return nil
        }
        return AppEnvironment(
            catalogRepository: CatalogRepository(api: api, cache: InMemoryCatalogCache()),
            urlOpener: AcceptingURLOpener(),
            assetBaseURL: unreachableAssetBase
        )
    }

    private struct StubCatalogAPI: CatalogAPI {
        let result: Result<CatalogResponse, APIError>

        func fetchCatalog(etag: String?) async throws -> CatalogFetchResult {
            .modified(try result.get(), etag: nil)
        }
    }

    /// Pretends every link opens, so a UI test never leaves the app for Safari or the dialer.
    private struct AcceptingURLOpener: URLOpener {
        func open(_ url: URL) async -> Bool { true }
    }

    private static func id(_ suffix: Int) -> ResourceID {
        ResourceID(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", suffix))!)
    }

    private static let fakeCatalog = CatalogResponse(
        serverDate: "2026-11-02",
        shop: CatalogShop(
            name: "Tiệm Bánh An Nhiên",
            greeting: "Bánh làm thủ công, giao tận nơi.",
            phoneContact: "+84900000000",
            zaloContact: "84900000000"
        ),
        settings: CatalogSettings(minQty: 2, leadDays: 2, maxDaysAhead: 30, maxQtyPerCake: 99, noteMaxLength: 200),
        products: [
            CatalogProduct(productID: id(11), slug: "banana", name: "Bánh chuối",
                           description: "Bánh chuối nướng thơm béo.", priceVND: 35_000,
                           imageURL: "/assets/images/banana.png?v=a547ade3"),
            CatalogProduct(productID: id(12), slug: "mung-bean-pork-fat", name: "Bánh đậu xanh nhân mỡ",
                           description: "Đậu xanh nghiền mịn, nhân mỡ.", priceVND: 45_000,
                           imageURL: "/assets/images/mung-bean-pork-fat.png?v=400d407e"),
            CatalogProduct(productID: id(13), slug: "mung-bean-vegetarian", name: "Bánh đậu xanh chay",
                           description: "Đậu xanh nghiền mịn, không nhân mỡ.", priceVND: 45_000,
                           imageURL: "/assets/images/mung-bean-vegetarian.png?v=f49a203d"),
            CatalogProduct(productID: id(14), slug: "mung-bean-egg-yolk-pork-fat", name: "Bánh đậu xanh trứng mỡ",
                           description: "Đậu xanh, trứng muối và mỡ.", priceVND: 55_000,
                           imageURL: "/assets/images/mung-bean-egg-yolk-pork-fat.png?v=6f699e7f"),
        ],
        districts: [],
        slots: []
    )
}
#endif
