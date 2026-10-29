package app.banh.customer.ui.order

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.rememberNavController
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.OrderDependencies
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.FakeAvailabilityApi
import app.banh.customer.testing.FakeCatalogRepository
import app.banh.customer.testing.InMemoryDraftStore
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.common.groupThousands
import java.time.Clock
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/**
 * The whole order graph with the real store, the real reducer and the availability fixture: S-5 to S-8 as a customer
 * walks them. Slice 2 is done when this passes with correct dates and total, and going back keeps the data.
 */
class OrderFlowTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val first = catalog.products[0]
    private val second = catalog.products[1]
    private val district = catalog.districts[2]
    private val drafts = InMemoryDraftStore()
    private val availability = FakeAvailabilityApi()

    private fun open() {
        val dependencies = OrderDependencies(FakeCatalogRepository(Load.Ready(catalog)), availability, drafts, Clock.systemUTC())
        rule.setBanhContent {
            val navController = rememberNavController()
            NavHost(navController, startDestination = OrderRoutes.GRAPH) { orderGraph(navController, dependencies) }
        }
        rule.waitForIdle()
    }

    private fun tap(tag: String) {
        rule.onNodeWithTag(tag).performScrollTo().performClick()
    }

    private fun tapNext() {
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsEnabled().performClick()
        rule.waitForIdle()
    }

    private fun count(tag: String): Int = rule.onAllNodesWithTag(tag).fetchSemanticsNodes().size

    // Navigation and availability finish on the main thread after the tap; wait for what the next step shows.
    private fun awaitTag(tag: String) {
        rule.waitUntil(WAIT_MILLIS) { count(tag) > 0 }
    }

    private fun chooseCakes() {
        tap(TestTags.orderQtyIncrease(first.id))
        tap(TestTags.orderQtyIncrease(first.id))
        tap(TestTags.orderQtyIncrease(second.id))
        tapNext()
    }

    private fun chooseDateAndSlot() {
        awaitTag(TestTags.orderDate("2026-11-06"))
        tap(TestTags.orderDate("2026-11-06"))
        tap(TestTags.orderSlot(catalog.slots[1].id))
        tapNext()
        awaitTag(TestTags.ORDER_FIELD_NAME)
    }

    private fun fillRecipient() {
        rule.onNodeWithTag(TestTags.ORDER_FIELD_NAME).performTextInput("Nguyễn An")
        rule.onNodeWithTag(TestTags.ORDER_FIELD_PHONE).performTextInput("0912 345 678")
        rule.onNodeWithTag(TestTags.ORDER_FIELD_ADDRESS).performTextInput("12 Đường Hoa Sen")
        tap(TestTags.ORDER_FIELD_DISTRICT)
        rule.onNodeWithTag(TestTags.orderDistrictRow(district.id)).performClick()
    }

    @Test
    fun customerWalksFromTheCakesToTheReviewWithTheCorrectTotal() {
        open()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        chooseCakes()
        chooseDateAndSlot()
        // AC-12: nothing entered yet, so Next stays on S-7 and shows the errors.
        tapNext()
        rule.onNodeWithTag(TestTags.orderFieldError("name")).assertExists()
        fillRecipient()
        tapNext()
        awaitTag(TestTags.REVIEW_TOTAL)

        val cakes = 2 * first.priceVnd + second.priceVnd
        rule.onNodeWithTag(TestTags.REVIEW_TOTAL).assertTextEquals("${groupThousands(cakes + district.deliveryFeeVnd)} ₫")
        rule.onNodeWithTag(TestTags.REVIEW_DATE).assertTextEquals("06/11/2026")
        rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsNotEnabled()
        // The server was asked for the total number of cakes (api.md 4.2).
        assertEquals(listOf(3), availability.requestedCakes)
    }

    // AC-18: from the review back to the cakes and forward again, everything is still there.
    @Test
    fun goingBackToTheCakesAndForwardKeepsEveryEntry() {
        open()
        chooseCakes()
        chooseDateAndSlot()
        fillRecipient()
        tapNext()
        awaitTag(TestTags.REVIEW_NAME)

        tap(TestTags.REVIEW_EDIT_CAKES)
        awaitTag(TestTags.orderQtyValue(first.id))
        rule.onNodeWithTag(TestTags.orderQtyValue(first.id)).assertTextEquals("2")
        rule.onNodeWithTag(TestTags.orderQtyValue(second.id)).assertTextEquals("1")
        tapNext()
        awaitTag(TestTags.orderDate("2026-11-06"))
        tapNext()
        awaitTag(TestTags.ORDER_FIELD_NAME)
        tapNext()
        awaitTag(TestTags.REVIEW_NAME)

        rule.onNodeWithTag(TestTags.REVIEW_NAME).assertTextEquals("Nguyễn An")
        rule.onNodeWithTag(TestTags.REVIEW_PHONE).assertTextEquals("0912 345 678")
    }

    // ADR-0011: the draft is saved after every change, with the date, slot and recipient.
    @Test
    fun everyStepIsSavedAsTheDraft() {
        open()
        chooseCakes()
        chooseDateAndSlot()
        fillRecipient()
        rule.waitForIdle()

        val saved = checkNotNull(drafts.draft)
        assertEquals(mapOf(first.id to 2, second.id to 1), saved.quantities)
        assertEquals("2026-11-06", saved.date)
        assertEquals(catalog.slots[1].id, saved.slotId)
        assertEquals("Nguyễn An", saved.name)
        assertEquals(district.id, saved.districtId)
    }
}

private const val WAIT_MILLIS = 5_000L
