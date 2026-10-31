import BanhContracts
import Foundation
@testable import BanhApp

enum CatalogTestData {
    static func okCatalog() throws -> CatalogResponse {
        try Fixtures.decode(CatalogResponse.self, from: "catalog-ok.json")
    }

    static func catalog(productCount: Int) throws -> CatalogResponse {
        let ok = try okCatalog()
        return CatalogResponse(
            serverDate: ok.serverDate, shop: ok.shop, settings: ok.settings,
            products: Array(ok.products.prefix(productCount)), districts: ok.districts, slots: ok.slots
        )
    }

    static func cached(_ catalog: CatalogResponse, etag: String? = "\"tag-1\"", fetchedAt: Date) -> CachedCatalog {
        CachedCatalog(catalog: catalog, etag: etag, fetchedAt: fetchedAt)
    }
}

/// A catalog API whose answers a test scripts and whose calls it can count.
actor StubCatalogAPI: CatalogAPI {
    private var results: [Result<CatalogFetchResult, APIError>]
    private(set) var etagsSent: [String?] = []
    private let delay: Duration?

    init(_ results: [Result<CatalogFetchResult, APIError>], delay: Duration? = nil) {
        self.results = results
        self.delay = delay
    }

    func fetchCatalog(etag: String?) async throws -> CatalogFetchResult {
        etagsSent.append(etag)
        if let delay { try await Task.sleep(for: delay) }
        let result = results.count > 1 ? results.removeFirst() : results[0]
        return try result.get()
    }
}
