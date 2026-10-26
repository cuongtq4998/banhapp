package app.banh.customer.testing

import androidx.test.platform.app.InstrumentationRegistry
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

    /** The catalog of the contract with its four cakes. */
    fun catalog(): Catalog = decode(CATALOG_OK)

    /** The catalog the shop answers with when it has hidden every cake. */
    fun catalogWithoutCakes(): Catalog = decode(CATALOG_EMPTY)

    /** The first [count] cakes of the contract catalog, as when the shop hides the others. */
    fun catalogWithCakes(count: Int): Catalog = catalog().let { it.copy(products = it.products.take(count)) }

    private fun decode(name: String): Catalog {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        return ApiJson.decodeFromString(assets.open(name).bufferedReader().use { it.readText() })
    }
}
