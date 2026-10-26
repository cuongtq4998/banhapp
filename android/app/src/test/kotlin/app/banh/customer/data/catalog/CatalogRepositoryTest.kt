package app.banh.customer.data.catalog

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.testing.FakeCatalogApi
import app.banh.customer.testing.InMemoryCatalogCache
import app.banh.customer.testing.MutableClock
import app.banh.customer.testing.TestCatalogs
import java.io.IOException
import java.time.Duration
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class CatalogRepositoryTest {
    private val clock = MutableClock()
    private val fresh = TestCatalogs.catalog(shopName = "Fresh")
    private val cached = TestCatalogs.catalog(shopName = "Cached")

    private fun cacheEntry(age: Duration = Duration.ZERO, etag: String? = "\"v1\"") =
        CachedCatalog(cached, etag, clock.millis() - age.toMillis())

    private fun repository(api: CatalogApi, cache: CatalogCache) = DefaultCatalogRepository(api, cache, clock)

    @Test
    fun startsLoading() {
        val repository = repository(FakeCatalogApi(), InMemoryCatalogCache())
        assertEquals(Load.Loading, repository.catalog.value)
    }

    @Test
    fun coldStartShowsServerCatalogAndStoresIt() = runTest {
        val cache = InMemoryCatalogCache()
        val repository = repository(FakeCatalogApi(CatalogResponse.Modified(fresh, "\"v2\"")), cache)

        repository.refresh()

        assertEquals(Load.Ready(fresh), repository.catalog.value)
        assertEquals("\"v2\"", cache.entry?.etag)
        assertEquals(clock.millis(), cache.entry?.fetchedAtEpochMillis)
    }

    @Test
    fun cacheIsRevalidatedWithItsEtagAndKeptOnNotModified() = runTest {
        val api = FakeCatalogApi(CatalogResponse.NotModified)
        val cache = InMemoryCatalogCache(cacheEntry(age = Duration.ofDays(3)))
        val repository = repository(api, cache)

        repository.refresh()

        assertEquals(listOf<String?>("\"v1\""), api.requestedEtags)
        assertEquals(Load.Ready(cached), repository.catalog.value)
        // A confirmed copy starts its 7 days again.
        assertEquals(clock.millis(), cache.entry?.fetchedAtEpochMillis)
    }

    @Test
    fun failedRefreshIsSilentWhenACacheIsShown() = runTest {
        val api = FakeCatalogApi(ApiException.NetworkUnavailable(IOException("offline")))
        val repository = repository(api, InMemoryCatalogCache(cacheEntry()))

        repository.refresh()

        assertEquals(Load.Ready(cached), repository.catalog.value)
    }

    @Test
    fun offlineWithoutCacheIsANetworkFailure() = runTest {
        val api = FakeCatalogApi(ApiException.NetworkUnavailable(IOException("offline")))
        val repository = repository(api, InMemoryCatalogCache())

        repository.refresh()

        assertEquals(Load.Failed(LoadFailure.NETWORK), repository.catalog.value)
    }

    @Test
    fun serverErrorWithoutCacheIsAnOtherFailure() = runTest {
        val error = ApiException.Service(ApiErrorCode.SERVICE_UNAVAILABLE, "ERR_SERVER", 503, null)
        val repository = repository(FakeCatalogApi(error), InMemoryCatalogCache())

        repository.refresh()

        assertEquals(Load.Failed(LoadFailure.OTHER), repository.catalog.value)
    }

    @Test
    fun cacheOlderThanSevenDaysCountsAsNoCache() = runTest {
        val api = FakeCatalogApi(ApiException.NetworkUnavailable(IOException("offline")))
        val repository = repository(api, InMemoryCatalogCache(cacheEntry(age = Duration.ofDays(7).plusSeconds(1))))

        repository.refresh()

        assertEquals(Load.Failed(LoadFailure.NETWORK), repository.catalog.value)
        // An expired copy is not revalidated either: the server must send the full body.
        assertEquals(listOf<String?>(null), api.requestedEtags)
    }

    @Test
    fun cacheOfExactlySevenDaysIsStillShown() = runTest {
        val api = FakeCatalogApi(ApiException.NetworkUnavailable(IOException("offline")))
        val repository = repository(api, InMemoryCatalogCache(cacheEntry(age = Duration.ofDays(7))))

        repository.refresh()

        assertEquals(Load.Ready(cached), repository.catalog.value)
    }

    @Test
    fun retryAfterAFailureLoadsAgain() = runTest {
        val api = FakeCatalogApi(
            ApiException.NetworkUnavailable(IOException("offline")),
            CatalogResponse.Modified(fresh, null),
        )
        val repository = repository(api, InMemoryCatalogCache())

        repository.refresh()
        assertEquals(Load.Failed(LoadFailure.NETWORK), repository.catalog.value)
        repository.refresh()

        assertEquals(Load.Ready(fresh), repository.catalog.value)
    }

    @Test
    fun notModifiedWithoutACopyIsAnInvalidResponse() = runTest {
        val repository = repository(FakeCatalogApi(CatalogResponse.NotModified), InMemoryCatalogCache())

        repository.refresh()

        assertEquals(Load.Failed(LoadFailure.OTHER), repository.catalog.value)
    }

    @Test
    fun serverCatalogReplacesTheCachedOneOnScreen() = runTest {
        val api = FakeCatalogApi(CatalogResponse.Modified(fresh, "\"v2\""))
        val repository = repository(api, InMemoryCatalogCache(cacheEntry()))

        repository.refresh()

        assertEquals(Load.Ready(fresh), repository.catalog.value)
    }

    @Test
    fun rateLimitKeepsTheCachedCatalogVisible() = runTest {
        val api = FakeCatalogApi(ApiException.RateLimited(retryAfterSeconds = 30, requestId = null))
        val repository = repository(api, InMemoryCatalogCache(cacheEntry()))

        repository.refresh()

        assertEquals(Load.Ready(cached), repository.catalog.value)
    }

    @Test
    fun rateLimitWithoutCacheIsAnOtherFailure() = runTest {
        val repository = repository(FakeCatalogApi(ApiException.RateLimited(30, null)), InMemoryCatalogCache())

        repository.refresh()

        assertEquals(Load.Failed(LoadFailure.OTHER), repository.catalog.value)
    }
}
