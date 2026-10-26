package app.banh.customer.data.catalog

import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.ErrorEnvelope
import app.banh.customer.testing.ContractFixtures
import app.banh.customer.testing.SampleCatalogJson
import org.junit.Assert.assertEquals
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
            val body = ContractFixtures.read(name)
            if (body.contains("\"error\"")) {
                ApiJson.decodeFromString<ErrorEnvelope>(body)
            } else {
                ApiJson.decodeFromString<Catalog>(body)
            }
        }
    }
}
