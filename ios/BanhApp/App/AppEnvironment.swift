import Foundation

/// Composition root (ADR-0007: manual wiring, no DI framework). One instance lives as long as the process.
struct AppEnvironment {
    let catalogRepository: CatalogRepository
    let availabilityAPI: any AvailabilityAPI
    let draftStore: any DraftStore
    let urlOpener: any URLOpener
    /// Pictures and other assets are resolved against this address (ADR-0017).
    let assetBaseURL: URL

    /// Disk space for product pictures (ADR-0011: the platform HTTP cache). The default cache is too
    /// small to keep a picture of normal size.
    private static let imageCacheMemoryBytes = 20 * 1024 * 1024
    private static let imageCacheDiskBytes = 50 * 1024 * 1024

    @MainActor
    static func make(launchArguments: UserDefaults = .standard, bundle: Bundle = .main) -> AppEnvironment {
        #if DEBUG
        if let stub = UITestStub.environment(for: launchArguments.string(forKey: LaunchArgument.stubBackend)) {
            return stub
        }
        #endif
        return live(bundle: bundle)
    }

    @MainActor
    private static func live(bundle: Bundle) -> AppEnvironment {
        URLCache.shared = URLCache(
            memoryCapacity: imageCacheMemoryBytes, diskCapacity: imageCacheDiskBytes
        )
        let baseURL = BuildConfiguration.apiBaseURL(in: bundle)
        let client = APIClient(
            baseURL: baseURL,
            appVersion: BuildConfiguration.appVersion(in: bundle),
            transport: URLSessionTransport()
        )
        let cache = (try? FileCatalogCache.inApplicationSupport()).map { $0 as any CatalogCache }
            ?? InMemoryCatalogCache()
        let draftStore = (try? FileDraftStore.inApplicationSupport()).map { $0 as any DraftStore }
            ?? InMemoryDraftStore()
        return AppEnvironment(
            catalogRepository: CatalogRepository(api: HTTPCatalogAPI(client: client), cache: cache),
            availabilityAPI: HTTPAvailabilityAPI(client: client),
            draftStore: draftStore,
            urlOpener: SystemURLOpener(),
            assetBaseURL: baseURL
        )
    }
}
