package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.testing.fixtureAvailability
import app.banh.customer.testing.orderCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class OrderFlowReducerTest {
    private val catalog = orderCatalog()

    private fun state(draft: OrderDraft = OrderDraft.blank("key-1")) =
        OrderFlowState(draft = draft, draftLoaded = true, catalog = Load.Ready(catalog))

    private fun OrderFlowState.then(vararg intents: OrderIntent) = intents.fold(this) { acc, intent -> reduce(acc, intent) }

    // AC-5: from a cake detail the flow starts with that cake at 1.
    @Test
    fun startingFromACakeGivesANewDraftWithThatCakeAtOne() {
        val old = OrderDraft(quantities = mapOf("product-2" to 4), name = "Old", idempotencyKey = "old")

        val result = reduce(state(old), OrderIntent.StartNew("product-3", "new-key"))

        assertEquals(mapOf("product-3" to 1), result.draft.quantities)
        assertEquals("", result.draft.name)
        assertEquals("new-key", result.draft.idempotencyKey)
    }

    @Test
    fun quantityStopsAtZeroAndAtTheConfiguredMaximum() {
        val result = state().then(
            OrderIntent.SetQuantity("product-1", 150),
            OrderIntent.SetQuantity("product-2", 3),
            OrderIntent.SetQuantity("product-2", -1),
        )

        assertEquals(99, result.draft.quantityOf("product-1"))
        assertEquals(0, result.draft.quantityOf("product-2"))
        assertEquals(mapOf("product-1" to 99), result.draft.quantities)
    }

    @Test
    fun changingAQuantityDropsTheAvailabilityOfTheOldOrderSize() {
        val loaded = state().then(OrderIntent.SetQuantity("product-1", 3), OrderIntent.LoadAvailability)
        assertEquals(Load.Loading, loaded.availability)

        assertNull(reduce(loaded, OrderIntent.SetQuantity("product-1", 4)).availability)
    }

    @Test
    fun availabilityIsNotAskedForAnEmptyOrder() {
        assertNull(reduce(state(), OrderIntent.LoadAvailability).availability)
    }

    @Test
    fun anAnswerForAnotherOrderSizeIsIgnored() {
        val asked = state().then(OrderIntent.SetQuantity("product-1", 3), OrderIntent.LoadAvailability)

        val result = reduce(asked, OrderIntent.AvailabilityLoaded(cakes = 2, result = Load.Ready(fixtureAvailability())))

        assertSame(asked, result)
    }

    // UI 5.6: the chosen date lost its room after a quantity change: date cleared, slot kept, message on.
    @Test
    fun aChosenDateThatIsNowFullIsClearedAndTheSlotIsKept() {
        val chosen = state().then(
            OrderIntent.SetQuantity("product-1", 3),
            OrderIntent.ChooseDate("2026-11-05"),
            OrderIntent.ChooseSlot("slot-2"),
            OrderIntent.LoadAvailability,
        )

        val result = reduce(chosen, OrderIntent.AvailabilityLoaded(3, Load.Ready(fixtureAvailability())))

        assertNull(result.draft.date)
        assertEquals("slot-2", result.draft.slotId)
        assertTrue(result.dateCleared)
    }

    @Test
    fun aChosenDateThatStillHasRoomIsKept() {
        val chosen = state().then(
            OrderIntent.SetQuantity("product-1", 3),
            OrderIntent.ChooseDate("2026-11-06"),
            OrderIntent.LoadAvailability,
        )

        val result = reduce(chosen, OrderIntent.AvailabilityLoaded(3, Load.Ready(fixtureAvailability())))

        assertEquals("2026-11-06", result.draft.date)
        assertEquals(false, result.dateCleared)
    }

    @Test
    fun choosingADateRemovesTheClearedMessage() {
        val cleared = state().copy(dateCleared = true)

        assertEquals(false, reduce(cleared, OrderIntent.ChooseDate("2026-11-06")).dateCleared)
    }

    @Test
    fun aFailedAvailabilityLoadIsKeptForTheScreenToShow() {
        val asked = state().then(OrderIntent.SetQuantity("product-1", 3), OrderIntent.LoadAvailability)

        val result = reduce(asked, OrderIntent.AvailabilityLoaded(3, Load.Failed(LoadFailure.NETWORK)))

        assertEquals(Load.Failed(LoadFailure.NETWORK), result.availability)
    }

    // BR-13, ADR-0011: a hidden cake is dropped and named, everything else stays, the key is replaced.
    @Test
    fun aHiddenCakeIsDroppedOnceAndTheRestOfTheDraftStays() {
        val draft = OrderDraft(
            quantities = mapOf("product-1" to 2, "product-4" to 3),
            date = "2026-11-06",
            slotId = "slot-1",
            name = "An",
            districtId = "district-1",
            idempotencyKey = "old-key",
        )
        val seen = state(draft).copy(knownCakeNames = mapOf("product-4" to "Cake 4"))
        val fewer = orderCatalog(productCount = 3)

        val result = reduce(seen, OrderIntent.CatalogChanged(Load.Ready(fewer), "fresh-key"))

        assertEquals(mapOf("product-1" to 2), result.draft.quantities)
        assertEquals(listOf("Cake 4"), result.removedCakeNames)
        assertEquals("fresh-key", result.draft.idempotencyKey)
        assertEquals("2026-11-06", result.draft.date)
        assertEquals("An", result.draft.name)
        assertEquals("district-1", result.draft.districtId)
    }

    @Test
    fun theRemovedNoticeLastsUntilTheCustomerChangesAQuantity() {
        val removed = state().copy(removedCakeNames = listOf("Cake 4"))

        assertEquals(emptyList<String>(), reduce(removed, OrderIntent.DismissRemovedNotice).removedCakeNames)
        assertEquals(emptyList<String>(), reduce(removed, OrderIntent.SetQuantity("product-1", 1)).removedCakeNames)
    }

    @Test
    fun anUnchangedCatalogKeepsTheKeyAndReportsNothing() {
        val draft = OrderDraft(quantities = mapOf("product-1" to 2), idempotencyKey = "old-key")

        val result = reduce(state(draft), OrderIntent.CatalogChanged(Load.Ready(catalog), "fresh-key"))

        assertEquals("old-key", result.draft.idempotencyKey)
        assertTrue(result.removedCakeNames.isEmpty())
    }

    @Test
    fun nothingIsReconciledBeforeTheSavedDraftIsRead() {
        val waiting = OrderFlowState(draft = OrderDraft.blank("k"), draftLoaded = false)
        val saved = OrderDraft(quantities = mapOf("product-9" to 1), idempotencyKey = "saved")

        val afterCatalog = reduce(waiting, OrderIntent.CatalogChanged(Load.Ready(catalog), "fresh"))
        val afterRestore = reduce(afterCatalog, OrderIntent.DraftRestored(saved, "fresh"))

        assertEquals("k", afterCatalog.draft.idempotencyKey)
        assertTrue(afterRestore.draftLoaded)
        assertTrue(afterRestore.draft.quantities.isEmpty())
        assertEquals(listOf(""), afterRestore.removedCakeNames)
    }

    @Test
    fun aDistrictOrSlotThatIsNoLongerOfferedIsCleared() {
        val draft = OrderDraft(districtId = "gone", slotId = "gone", date = "2026-11-06", idempotencyKey = "k")

        val result = reduce(state(draft), OrderIntent.CatalogChanged(Load.Ready(catalog), "fresh"))

        assertNull(result.draft.districtId)
        assertNull(result.draft.slotId)
        assertEquals("2026-11-06", result.draft.date)
    }
}
