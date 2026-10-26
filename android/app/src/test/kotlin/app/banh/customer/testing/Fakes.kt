package app.banh.customer.testing

import app.banh.customer.data.Load
import app.banh.customer.data.catalog.CachedCatalog
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogApi
import app.banh.customer.data.catalog.CatalogCache
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.CatalogResponse
import app.banh.customer.data.catalog.District
import app.banh.customer.data.catalog.Product
import app.banh.customer.data.catalog.Settings
import app.banh.customer.data.catalog.Shop
import app.banh.customer.data.catalog.Slot
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Fake sample data only (the repository is public). */
object TestCatalogs {
    fun product(n: Int) = Product(
        id = "product-$n",
        slug = "cake-$n",
        name = "Cake $n",
        description = "Sample description $n.",
        priceVnd = 50_000L + n * 1_000L,
        imageUrl = "/assets/images/cake-$n.jpg?v=0123abcd",
    )

    fun catalog(productCount: Int = 4, shopName: String = "Sample Shop") = Catalog(
        serverDate = "2026-11-02",
        shop = Shop(name = shopName, greeting = "Sample greeting.", phoneContact = "+84900000000", zaloContact = "84900000000"),
        settings = Settings(minQty = 2, leadDays = 2, maxDaysAhead = 30, maxQtyPerCake = 99, noteMaxLength = 200),
        products = (1..productCount).map(::product),
        districts = listOf(District("district-1", "Sample District", 20_000L)),
        slots = listOf(Slot("slot-1", "08:00", "10:00")),
    )
}

/** Time that only moves when a test says so. */
class MutableClock(private var now: Instant = Instant.parse("2026-11-02T03:00:00Z")) : Clock() {
    override fun getZone(): ZoneId = ZoneOffset.UTC

    override fun withZone(zone: ZoneId?): Clock = this

    override fun instant(): Instant = now

    fun advance(duration: Duration) {
        now = now.plus(duration)
    }
}

class InMemoryCatalogCache(var entry: CachedCatalog? = null) : CatalogCache {
    var writes = 0
        private set

    override suspend fun read(): CachedCatalog? = entry

    override suspend fun write(entry: CachedCatalog) {
        writes++
        this.entry = entry
    }
}

/** Answers with the next scripted outcome; a [Throwable] outcome is thrown. */
class FakeCatalogApi(vararg outcomes: Any) : CatalogApi {
    private val queue = ArrayDeque(outcomes.toList())
    val requestedEtags = mutableListOf<String?>()

    override suspend fun fetchCatalog(etag: String?): CatalogResponse {
        requestedEtags += etag
        return when (val outcome = queue.removeFirst()) {
            is Throwable -> throw outcome
            is CatalogResponse -> outcome
            else -> error("Unsupported scripted outcome $outcome")
        }
    }
}

class FakeCatalogRepository(initial: Load<Catalog> = Load.Loading) : CatalogRepository {
    private val state = MutableStateFlow(initial)
    override val catalog: StateFlow<Load<Catalog>> = state
    var refreshCount = 0
        private set

    fun emit(value: Load<Catalog>) {
        state.value = value
    }

    /** Runs inside [refresh], to script the answer that a refresh brings. */
    var onRefresh: () -> Unit = {}

    override suspend fun refresh() {
        refreshCount++
        onRefresh()
    }
}
