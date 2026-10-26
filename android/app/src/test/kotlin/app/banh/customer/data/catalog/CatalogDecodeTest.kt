package app.banh.customer.data.catalog

import app.banh.customer.data.network.ApiJson
import app.banh.customer.testing.ContractFixtures
import app.banh.customer.testing.SampleCatalogJson
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test

class CatalogDecodeTest {
    @Test
    fun decodesTheExampleOfTheApiDocument() {
        val catalog = ApiJson.decodeFromString<Catalog>(SampleCatalogJson.BODY)

        assertEquals("Tiệm Bánh Mẫu", catalog.shop.name)
        assertEquals("+84900000000", catalog.shop.phoneContact)
        assertEquals("84900000000", catalog.shop.zaloContact)
        assertEquals(2, catalog.settings.minQty)
        assertEquals(50_000L, catalog.products.single().priceVnd)
        assertEquals("/assets/products/banana.jpg", catalog.products.single().imageUrl)
        assertEquals("0b8f1f0e-2222-4a00-8000-000000000001", catalog.districts.single().id)
        assertEquals("08:00", catalog.slots.single().start)
    }

    @Test
    fun ignoresFieldsAddedLaterByTheServer() {
        val withExtra = SampleCatalogJson.BODY.replace("\"server_date\"", "\"added_later\": 1, \"server_date\"")

        assertEquals("2026-11-02", ApiJson.decodeFromString<Catalog>(withExtra).serverDate)
    }

    @Test
    fun decodesEveryCatalogFixtureOfTheContract() {
        val names = ContractFixtures.names("catalog-")
        // The backend creates these fixtures; until they are merged this test reports itself as skipped.
        assumeTrue("no catalog-*.json fixture in contracts/fixtures yet", names.isNotEmpty())
        names.forEach { name ->
            val root = ApiJson.parseToJsonElement(ContractFixtures.read(name)).jsonObject
            // The fixture kind comes from the content, so a new kind fails here with a clear message
            // instead of a MissingFieldException deep inside the decoder.
            when {
                root.containsKey(EXCHANGE_STATUS_KEY) -> assertNotModifiedExchange(name, root)
                root.containsKey(CATALOG_SHOP_KEY) -> ApiJson.decodeFromJsonElement<Catalog>(root)
                else -> fail("$name is neither a catalog nor a revalidation exchange; teach this test the new fixture kind")
            }
        }
    }

    private fun assertNotModifiedExchange(name: String, exchange: JsonObject) {
        assertEquals("$name status", HTTP_NOT_MODIFIED, exchange.getValue(EXCHANGE_STATUS_KEY).jsonPrimitive.int)
        assertEquals("$name body", JsonNull, exchange.getValue("body"))
        val headers = exchange.getValue("response_headers").jsonObject
        assertTrue("$name repeats the ETag", headers.getValue("ETag").jsonPrimitive.content.isNotEmpty())
        assertEquals("$name Cache-Control", "no-cache", headers.getValue("Cache-Control").jsonPrimitive.content)
    }

    private companion object {
        const val EXCHANGE_STATUS_KEY = "status"
        const val CATALOG_SHOP_KEY = "shop"
        const val HTTP_NOT_MODIFIED = 304
    }
}
