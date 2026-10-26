import BanhContracts
import XCTest
@testable import BanhApp

@MainActor
final class CatalogRepositoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func makeRepository(
        api: StubCatalogAPI, cache: InMemoryCatalogCache = InMemoryCatalogCache()
    ) -> CatalogRepository {
        let now = now
        return CatalogRepository(api: api, cache: cache, now: { now })
    }

    func testWithoutACacheTheCatalogLoadsThenIsStored() async throws {
        let fresh = try CatalogTestData.okCatalog()
        let cache = InMemoryCatalogCache()
        let repository = makeRepository(api: StubCatalogAPI([.success(.modified(fresh, etag: "\"a\""))]), cache: cache)
        XCTAssertTrue(repository.catalog.isLoading)

        await repository.refresh()

        XCTAssertEqual(repository.catalog, .ready(fresh))
        let stored = await cache.read()
        XCTAssertEqual(stored, CachedCatalog(catalog: fresh, etag: "\"a\"", fetchedAt: now))
    }

    func testACachedCatalogShowsBeforeTheServerAnswers() async throws {
        let cached = try CatalogTestData.cached(CatalogTestData.catalog(productCount: 2), fetchedAt: now)
        let api = StubCatalogAPI([.success(.notModified)], delay: .milliseconds(300))
        let repository = makeRepository(api: api, cache: InMemoryCatalogCache(entry: cached))

        let refreshing = Task { await repository.refresh() }
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(repository.catalog, .ready(cached.catalog), "cache shows while the request is in flight")
        await refreshing.value
    }

    func testTheStoredETagIsSentAndA304KeepsTheCacheAndRestartsItsAge() async throws {
        let cached = try CatalogTestData.cached(CatalogTestData.okCatalog(), etag: "\"stored\"", fetchedAt: now - 3 * day)
        let cache = InMemoryCatalogCache(entry: cached)
        let api = StubCatalogAPI([.success(.notModified)])
        let repository = makeRepository(api: api, cache: cache)

        await repository.refresh()

        let sent = await api.etagsSent
        XCTAssertEqual(sent, ["\"stored\""])
        XCTAssertEqual(repository.catalog, .ready(cached.catalog))
        let stored = await cache.read()
        XCTAssertEqual(stored?.fetchedAt, now)
        XCTAssertEqual(stored?.etag, "\"stored\"")
    }

    func testACacheExactlySevenDaysOldIsStillValid() async throws {
        let cached = try CatalogTestData.cached(CatalogTestData.okCatalog(), fetchedAt: now - 7 * day)
        let api = StubCatalogAPI([.failure(.networkUnavailable)])
        let repository = makeRepository(api: api, cache: InMemoryCatalogCache(entry: cached))

        await repository.refresh()

        XCTAssertEqual(repository.catalog, .ready(cached.catalog), "the failed refresh is silent")
        let sent = await api.etagsSent
        XCTAssertEqual(sent, ["\"tag-1\""])
    }

    func testACacheOlderThanSevenDaysCountsAsNoCache() async throws {
        let stale = try CatalogTestData.cached(CatalogTestData.okCatalog(), fetchedAt: now - 7 * day - 1)
        let api = StubCatalogAPI([.failure(.networkUnavailable)])
        let repository = makeRepository(api: api, cache: InMemoryCatalogCache(entry: stale))

        await repository.refresh()

        XCTAssertEqual(repository.catalog, .failed(.network))
        let sent = await api.etagsSent
        XCTAssertEqual(sent, [nil], "an expired copy is not revalidated")
    }

    func testAFailureWithoutACacheNamesTheNetworkOnlyWhenOffline() async {
        let offline = makeRepository(api: StubCatalogAPI([.failure(.networkUnavailable)]))
        await offline.refresh()
        XCTAssertEqual(offline.catalog, .failed(.network))

        let broken = makeRepository(api: StubCatalogAPI([.failure(.invalidResponse)]))
        await broken.refresh()
        XCTAssertEqual(broken.catalog, .failed(.other))
    }

    func testRateLimitedKeepsTheCachedCatalogVisible() async throws {
        let cached = try CatalogTestData.cached(CatalogTestData.okCatalog(), fetchedAt: now - day)
        let limited = APIError.rateLimited(retryAfterSeconds: 30, requestID: nil)
        let repository = makeRepository(api: StubCatalogAPI([.failure(limited)]), cache: InMemoryCatalogCache(entry: cached))

        await repository.refresh()

        XCTAssertEqual(repository.catalog, .ready(cached.catalog))
    }

    func testRateLimitedWithoutACacheIsAFailedLoad() async {
        let limited = APIError.rateLimited(retryAfterSeconds: 30, requestID: nil)
        let repository = makeRepository(api: StubCatalogAPI([.failure(limited)]))
        await repository.refresh()
        XCTAssertEqual(repository.catalog, .failed(.other))
    }

    func testRetryAfterAFailureShowsLoadingThenTheData() async throws {
        let fresh = try CatalogTestData.okCatalog()
        let api = StubCatalogAPI([.failure(.networkUnavailable), .success(.modified(fresh, etag: nil))])
        let repository = makeRepository(api: api)

        await repository.refresh()
        XCTAssertEqual(repository.catalog, .failed(.network))
        await repository.refresh()

        XCTAssertEqual(repository.catalog, .ready(fresh))
    }

    func testANotModifiedAnswerWithoutAStoredCopyIsAFailure() async {
        let repository = makeRepository(api: StubCatalogAPI([.success(.notModified)]))
        await repository.refresh()
        XCTAssertEqual(repository.catalog, .failed(.other))
    }

    func testConcurrentRefreshesShareOneRequest() async throws {
        let fresh = try CatalogTestData.okCatalog()
        let api = StubCatalogAPI([.success(.modified(fresh, etag: nil))], delay: .milliseconds(100))
        let repository = makeRepository(api: api)

        async let first: Void = repository.refresh()
        async let second: Void = repository.refresh()
        _ = await (first, second)

        let sent = await api.etagsSent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(repository.catalog, .ready(fresh))
    }
}
