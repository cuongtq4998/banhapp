package app.banh.admin.orders

import app.banh.admin.testing.Fixtures
import app.banh.admin.testing.OrderFixtures
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrdersPage
import app.banh.core.network.ApiJson
import java.io.File
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OrderFixturesTest {
    private val dir = File(checkNotNull(System.getProperty("contracts.fixtures.dir")), "admin")

    @Test
    fun everyOrderDetailFixtureDecodes() {
        val names = dir.list().orEmpty().map { it.removeSuffix(".json") }.filter { it.startsWith("order-detail") }.sorted()
        assertTrue(names.size >= 6)
        names.forEach { assertTrue(it, OrderFixtures.detail(it).orderCode.isNotEmpty()) }
        OrderFixtures.detail("order-status-change")
    }

    @Test
    fun theListFixtureDecodesWithListDateAndOpaqueCursor() {
        val page = ApiJson.decodeFromString(OrdersPage.serializer(), Fixtures.body("orders-list"))
        assertEquals("2026-11-02", page.items.first().listDate)
        assertNull(page.items.first().expectedDeliveryDate)
    }

    @Test
    fun everyConflictFixtureCarriesTheCurrentOrder() {
        listOf("error-order-state-changed", "error-order-state-changed-date", "error-order-state-changed-fee").forEach {
            val order = ApiJson.parseToJsonElement(Fixtures.text(it)).jsonObject.getValue("error").jsonObject.getValue("details").jsonObject.getValue("order")
            assertEquals(it, true, ApiJson.decodeFromJsonElement(OrderDetail.serializer(), order).orderCode.isNotEmpty())
        }
    }

    @Test
    fun feeAndAmountToCollectAreKeptAsTheServerSentThem() {
        val started = OrderFixtures.detail("order-detail-delivery-started")
        assertEquals(started.itemsSubtotalVnd + started.deliveryFeeFinalVnd!!, started.amountToCollectVnd)
        assertEquals(0L, OrderFixtures.detail("order-detail-delivery-started-free").deliveryFeeFinalVnd)
        val received = OrderFixtures.detail("order-detail-received")
        assertNull(received.deliveryFeeFinalVnd)
        assertNull(received.amountToCollectVnd)
        assertEquals(listOf(OrderAction.CANCEL, OrderAction.PROCESS), received.allowedActions)
    }

    @Test
    fun legacyAndUnknownWordsNeverCrash() {
        assertEquals(OrderStatus.Received, OrderStatus.fromWire("New"))
        assertEquals(OrderStatus.Processing, OrderStatus.fromWire("Confirmed"))
        assertEquals(OrderStatus.Finished, OrderStatus.fromWire("Completed"))
        assertEquals(OrderStatus.Unknown("Packed"), OrderStatus.fromWire("Packed"))
        val json = Fixtures.body("order-detail-received").replace("\"Received\"", "\"Packed\"").replace("\"process\"", "\"teleport\"")
        val order = ApiJson.decodeFromString(OrderDetail.serializer(), json)
        assertEquals(OrderStatus.Unknown("Packed"), order.status)
        assertEquals(listOf(OrderAction.CANCEL), order.allowedActions)
    }
}
