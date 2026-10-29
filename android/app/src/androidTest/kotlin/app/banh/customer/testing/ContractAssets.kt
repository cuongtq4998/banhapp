package app.banh.customer.testing

import androidx.test.platform.app.InstrumentationRegistry
import app.banh.customer.data.availability.Availability
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.network.ApiJson
import kotlinx.serialization.decodeFromString

/**
 * Reads the shared contract fixtures from the assets of the test APK; the `copyContractFixtures` Gradle task puts
 * `contracts/fixtures` there, so the tests never hold their own copy of the API data.
 */
object ContractAssets {
    private const val CATALOG_OK = "catalog-ok.json"
    private const val CATALOG_EMPTY = "catalog-empty.json"
    private const val AVAILABILITY_OK = "availability-ok.json"

    /** The catalog of the contract with its four cakes. */
    fun catalog(): Catalog = decode(CATALOG_OK)

    /** The catalog the shop answers with when it has hidden every cake. */
    fun catalogWithoutCakes(): Catalog = decode(CATALOG_EMPTY)

    /** The first [count] cakes of the contract catalog, as when the shop hides the others. */
    fun catalogWithCakes(count: Int): Catalog = catalog().let { it.copy(products = it.products.take(count)) }

    /** `GET /v1/availability?cakes=3` for server date 2026-11-02 (api.md 4.2): 2026-11-05 and 2026-11-20 are full. */
    fun availability(): Availability = ApiJson.decodeFromString(read(AVAILABILITY_OK))

    private fun decode(name: String): Catalog = ApiJson.decodeFromString(read(name))

    private fun read(name: String): String {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        return assets.open(name).bufferedReader().use { it.readText() }
    }
}
