import BanhContracts

/// Edge to the backend's catalog endpoint; the repository and the tests depend on this protocol.
nonisolated protocol CatalogAPI: Sendable {
    /// Fetches the catalog, revalidating with `etag` when given. Throws `APIError` on every failure.
    func fetchCatalog(etag: String?) async throws -> CatalogFetchResult
}

nonisolated enum CatalogFetchResult: Equatable, Sendable {
    case modified(CatalogResponse, etag: String?)
    /// 304: the copy the caller already holds is still current.
    case notModified
}
