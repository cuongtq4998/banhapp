package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.testing.MainDispatcherRule
import app.banh.customer.testing.OrderFlowHarness
import app.banh.customer.testing.orderCatalog
import java.time.Duration
import kotlinx.coroutines.ExperimentalCoroutinesApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/** The store and the draft: restore after process death, save after every change, the 24 hour rule (ADR-0011). */
@OptIn(ExperimentalCoroutinesApi::class)
class OrderFlowDraftTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val harness = OrderFlowHarness()
    private val drafts = harness.drafts
    private val clock = harness.clock
    private val catalog = harness.catalog

    private fun viewModel() = harness.viewModel()

    private fun savedDraft() = harness.savedDraft()

    // ADR-0011: after process death "Place order" opens S-5 with the saved data, with no prompt.
    @Test
    fun aFreshSavedDraftIsRestored() {
        drafts.draft = savedDraft()

        val flow = viewModel()

        assertEquals(savedDraft(), flow.state.value.draft)
        assertTrue(flow.state.value.draftLoaded)
    }

    @Test
    fun aDraftOlderThanTwentyFourHoursIsDiscarded() {
        drafts.draft = savedDraft()
        clock.advance(Duration.ofHours(24).plusSeconds(1))

        val flow = viewModel()

        assertTrue(flow.state.value.draft.quantities.isEmpty())
        assertEquals(1, drafts.cleared)
        assertNull(drafts.draft)
    }

    @Test
    fun openingFromACakeStartsANewDraftWithThatCakeAtOne() {
        drafts.draft = savedDraft()
        val flow = viewModel()

        flow.start("product-3")

        assertEquals(mapOf("product-3" to 1), flow.state.value.draft.quantities)
        assertEquals("", flow.state.value.draft.name)
        assertEquals(mapOf("product-3" to 1), drafts.draft?.quantities)
    }

    @Test
    fun openingFromHomeKeepsTheRestoredDraft() {
        drafts.draft = savedDraft()
        val flow = viewModel()

        flow.start(null)

        assertEquals(savedDraft(), flow.state.value.draft)
    }

    // The saved draft must not be overwritten by the empty one that exists before it is read.
    @Test
    fun nothingIsWrittenUntilTheCustomerChangesSomething() {
        drafts.draft = savedDraft()

        viewModel()

        assertTrue(drafts.writes.isEmpty())
    }

    @Test
    fun everyChangeIsSavedWithTheTimeOfTheChange() {
        val flow = viewModel()

        flow.onIntent(OrderIntent.SetQuantity("product-1", 2))
        clock.advance(Duration.ofMinutes(5))
        flow.onIntent(OrderIntent.EditName("An"))

        assertEquals(2, drafts.writes.size)
        assertEquals(mapOf("product-1" to 2), drafts.writes[0].quantities)
        assertEquals("An", drafts.writes[1].name)
        assertEquals(clock.millis(), drafts.writes[1].savedAtEpochMillis)
    }

    @Test
    fun aCakeHiddenWhileTheFlowIsOpenIsDroppedSavedAndReported() {
        drafts.draft = savedDraft()
        val flow = viewModel()

        catalog.emit(Load.Ready(orderCatalog(productCount = 1)))

        val state = flow.state.value
        assertEquals(mapOf("product-1" to 2), state.draft.quantities)
        assertEquals(listOf("Cake 2"), state.removedCakeNames)
        assertEquals(mapOf("product-1" to 2), drafts.draft?.quantities)
        assertEquals("2026-11-06", state.draft.date)
    }
}
