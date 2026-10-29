package app.banh.customer.order

import app.banh.customer.testing.orderCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OrderSummaryTest {
    private val catalog = orderCatalog()
    private fun draft(vararg quantities: Pair<String, Int>, districtId: String? = null) =
        OrderDraft(quantities = mapOf(*quantities), districtId = districtId, idempotencyKey = "key")

    // AC-6: quantities 2, 0, 3, 0 list only the two cakes with a quantity above 0.
    @Test
    fun onlyCakesWithAQuantityAreListed() {
        val summary = OrderSummary.of(draft("product-1" to 2, "product-3" to 3), catalog)

        assertEquals(listOf("product-1", "product-3"), summary.lines.map { it.product.id })
        assertEquals(5, summary.totalQuantity)
    }

    // AC-14: 2 of cake A at a, 1 of cake B at b, fee f gives 2a + b + f.
    @Test
    fun totalIsLinePricesPlusTheDeliveryFee() {
        val a = catalog.products[0].priceVnd
        val b = catalog.products[1].priceVnd
        val fee = catalog.districts[1].deliveryFeeVnd

        val summary = OrderSummary.of(draft("product-1" to 2, "product-2" to 1, districtId = "district-2"), catalog)

        assertEquals(2 * a + b, summary.cakesSubtotalVnd)
        assertEquals(fee, summary.deliveryFeeVnd)
        assertEquals(2 * a + b + fee, summary.totalVnd)
        assertEquals(2 * a, summary.lines.first().lineTotalVnd)
    }

    @Test
    fun feeIsZeroUntilADistrictIsChosenAndNeverFreeAfterwards() {
        val withoutDistrict = OrderSummary.of(draft("product-1" to 2), catalog)
        val withDistrict = OrderSummary.of(draft("product-1" to 2, districtId = "district-1"), catalog)

        assertNull(withoutDistrict.district)
        assertEquals(0L, withoutDistrict.deliveryFeeVnd)
        assertEquals(20_000L, withDistrict.deliveryFeeVnd)
    }

    @Test
    fun aCakeThatIsNotActiveIsNotCounted() {
        val summary = OrderSummary.of(draft("product-1" to 2, "hidden" to 5), catalog)

        assertEquals(2, summary.totalQuantity)
    }
}
