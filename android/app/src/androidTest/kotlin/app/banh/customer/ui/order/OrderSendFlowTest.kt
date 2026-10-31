package app.banh.customer.ui.order

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.rememberNavController
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.OrderDependencies
import app.banh.customer.order.OrderDraft
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.FakeAvailabilityApi
import app.banh.customer.testing.FakeCatalogRepository
import app.banh.customer.testing.FakeOrderApi
import app.banh.customer.testing.InMemoryDraftStore
import app.banh.customer.testing.setBanhContent
import java.time.Clock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test

/** From a saved complete draft: confirm on S-8, the code on S-9, Home clears everything (TC-119, TC-139, AC-15). */
class OrderSendFlowTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val orders = FakeOrderApi()
    private val drafts = InMemoryDraftStore(
        OrderDraft(
            quantities = mapOf(catalog.products[0].id to 2, catalog.products[1].id to 1),
            date = "2026-11-06",
            slotId = catalog.slots[1].id,
            name = "Nguyễn An",
            phone = "0912345678",
            address = "12 Đường Hoa Sen",
            districtId = catalog.districts[2].id,
            idempotencyKey = "saved-key",
            savedAtEpochMillis = System.currentTimeMillis(),
        ),
    )
    private var finished = 0
    private lateinit var navController: NavHostController

    private fun count(tag: String) = rule.onAllNodesWithTag(tag).fetchSemanticsNodes().size

    private fun open() {
        val dependencies = OrderDependencies(FakeCatalogRepository(Load.Ready(catalog)), FakeAvailabilityApi(), drafts, Clock.systemUTC(), orders)
        rule.setBanhContent {
            navController = rememberNavController()
            NavHost(navController, startDestination = OrderRoutes.GRAPH) {
                orderGraph(navController, dependencies, onFinished = { finished++ })
            }
        }
        rule.waitForIdle()
        rule.runOnUiThread { navController.navigate(OrderRoutes.REVIEW) }
        rule.waitUntil(WAIT_MILLIS) { count(TestTags.REVIEW_CONFIRM) > 0 }
    }

    @Test
    fun confirmShowsTheCodeAndHomeClearsTheDraft() {
        open()
        rule.waitUntil(WAIT_MILLIS) { runCatching { rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsEnabled() }.isSuccess }

        rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).performClick()
        rule.waitUntil(WAIT_MILLIS) { count(TestTags.CONF_CODE) > 0 }

        rule.onNodeWithTag(TestTags.CONF_CODE).assertTextEquals("BT-7K3M9Q")
        assertEquals(1, orders.calls.size)
        assertEquals("saved-key", orders.calls.single().second)
        assertEquals(0, count(TestTags.REVIEW_CONFIRM))
        assertNull(drafts.draft)

        rule.onNodeWithTag(TestTags.CONF_HOME).performClick()
        rule.waitUntil(WAIT_MILLIS) { finished == 1 }
    }

    private companion object {
        const val WAIT_MILLIS = 5_000L
    }
}
