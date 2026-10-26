import BanhContracts
import Foundation
import Observation

/// Single source of the catalog for every screen.
@MainActor
@Observable
final class CatalogRepository {
    private(set) var catalog: Load<CatalogResponse> = .loading

    private let api: any CatalogAPI
    private let cache: any CatalogCache
    private let now: @Sendable () -> Date

    // Concurrent refreshes (launch and a retry tap) are joined into one, never interleaved.
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    init(api: any CatalogAPI, cache: any CatalogCache, now: @escaping @Sendable () -> Date = { Date() }) {
        self.api = api
        self.cache = cache
        self.now = now
    }

    /// Shows the cached copy at once when there is one, then revalidates with the server. A failed
    /// refresh is silent when something is already shown (ADR-0011). Also serves as retry.
    func refresh() async {
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task { await performRefresh() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func performRefresh() async {
        let cached = await cache.read().flatMap { $0.isUsable(at: now()) ? $0 : nil }
        showCacheOrLoading(cached)
        do {
            let result = try await api.fetchCatalog(etag: cached?.etag)
            await apply(result, over: cached)
        } catch {
            showFailureIfNothingShown(error)
        }
    }

    private func showCacheOrLoading(_ cached: CachedCatalog?) {
        if case .ready = catalog { return }
        // After a failure a retry shows the loading state again.
        catalog = cached.map { .ready($0.catalog) } ?? .loading
    }

    private func apply(_ result: CatalogFetchResult, over cached: CachedCatalog?) async {
        let fetchedAt = now()
        switch result {
        case .modified(let fresh, let etag):
            await cache.write(CachedCatalog(catalog: fresh, etag: etag, fetchedAt: fetchedAt))
            catalog = .ready(fresh)
        case .notModified:
            guard let confirmed = cached?.confirmed(at: fetchedAt) else {
                // A 304 without a conditional request is a contract breach.
                showFailureIfNothingShown(APIError.invalidResponse)
                return
            }
            await cache.write(confirmed)
            catalog = .ready(confirmed.catalog)
        }
    }

    private func showFailureIfNothingShown(_ error: Error) {
        if case .ready = catalog { return }
        catalog = .failed((error as? APIError) == .networkUnavailable ? .network : .other)
    }
}
