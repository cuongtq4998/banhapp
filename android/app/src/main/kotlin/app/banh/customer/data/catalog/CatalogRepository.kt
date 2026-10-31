package app.banh.customer.data.catalog

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.network.ApiException
import java.time.Clock
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Single source of the catalog for every screen. */
interface CatalogRepository {
    val catalog: StateFlow<Load<Catalog>>

    /**
     * Shows the cached copy at once when there is one, then revalidates with the server.
     * A failed refresh is silent when something is already shown (ADR-0011). Also serves as retry.
     */
    suspend fun refresh()
}

/** A cache older than this counts as no cache (ADR-0011). */
val CATALOG_MAX_CACHE_AGE: Duration = Duration.ofDays(7)

class DefaultCatalogRepository(
    private val api: CatalogApi,
    private val cache: CatalogCache,
    private val clock: Clock,
) : CatalogRepository {
    private val state = MutableStateFlow<Load<Catalog>>(Load.Loading)
    override val catalog: StateFlow<Load<Catalog>> = state.asStateFlow()

    // Concurrent refreshes (launch and a retry tap) run one after the other, never interleaved.
    private val refreshLock = Mutex()

    override suspend fun refresh() = refreshLock.withLock {
        val cached = cache.read()?.takeIf(::isUsable)
        showCacheOrLoading(cached)
        try {
            apply(api.fetchCatalog(cached?.etag), cached)
        } catch (e: ApiException) {
            showFailureIfNothingShown(e)
        }
    }

    private fun isUsable(entry: CachedCatalog): Boolean {
        val age = Duration.between(Instant.ofEpochMilli(entry.fetchedAtEpochMillis), clock.instant())
        return age <= CATALOG_MAX_CACHE_AGE
    }

    private fun showCacheOrLoading(cached: CachedCatalog?) {
        when {
            state.value is Load.Ready -> Unit
            cached != null -> state.value = Load.Ready(cached.catalog)
            // After a failure a retry shows the loading state again.
            else -> state.value = Load.Loading
        }
    }

    private suspend fun apply(response: CatalogResponse, cached: CachedCatalog?) {
        val now = clock.millis()
        when (response) {
            is CatalogResponse.Modified -> {
                cache.write(CachedCatalog(response.catalog, response.etag, now))
                state.value = Load.Ready(response.catalog)
            }
            // The copy was confirmed current, so its age starts again.
            CatalogResponse.NotModified -> {
                val confirmed = cached ?: throw ApiException.InvalidResponse()
                cache.write(confirmed.copy(fetchedAtEpochMillis = now))
                state.value = Load.Ready(confirmed.catalog)
            }
        }
    }

    private fun showFailureIfNothingShown(error: ApiException) {
        if (state.value is Load.Ready) return
        val failure = if (error is ApiException.NetworkUnavailable) LoadFailure.NETWORK else LoadFailure.OTHER
        state.value = Load.Failed(failure)
    }
}
