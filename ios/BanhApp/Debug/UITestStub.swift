#if DEBUG
import BanhContracts
import Foundation

/// An in-process backend for the UI tests, chosen by the launch argument `-BanhStubBackend <mode>`.
/// Compiled into debug builds only, so a release build cannot be pointed away from the real API.
/// The data is fake and mirrors `contracts/fixtures/catalog-ok.json` and `availability-ok.json`.
enum UITestStub {
    /// Pictures resolve to a port nothing listens on, so they fail at once and the placeholder shows.
    private static let unreachableAssetBase = URL(string: "http://localhost:9")!

    @MainActor
    static func environment(for mode: String?) -> AppEnvironment? {
        let catalog: Result<CatalogResponse, APIError>
        var availability: any AvailabilityAPI = StubAvailabilityAPI(result: nil)
        var orders = StubOrderAPI(.success)
        switch mode {
        case LaunchArgument.stubModeCatalog: catalog = .success(UITestStubData.catalog)
        case LaunchArgument.stubModeUnavailable: catalog = .failure(.networkUnavailable)
        case LaunchArgument.stubModeAvailabilityFails:
            catalog = .success(UITestStubData.catalog)
            availability = StubAvailabilityAPI(result: .failure(.networkUnavailable))
        case let mode? where mode.hasPrefix(LaunchArgument.stubOrderPrefix):
            catalog = .success(UITestStubData.catalog)
            orders = StubOrderAPI(.init(String(mode.dropFirst(LaunchArgument.stubOrderPrefix.count))))
        default: return nil
        }
        return AppEnvironment(
            catalogRepository: CatalogRepository(api: StubCatalogAPI(result: catalog), cache: InMemoryCatalogCache()),
            availabilityAPI: availability,
            orderAPI: orders,
            draftStore: InMemoryDraftStore(),
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
}
#endif
