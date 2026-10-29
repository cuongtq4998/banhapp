package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.testing.fixtureAvailability
import app.banh.customer.testing.orderCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** ADR-0008 v1.1: new key on every change of a body field, same key for a pure retry. */
class IdempotencyKeyRuleTest {
    private var count = 0
    private val newKey: () -> String = { "fresh-${++count}" }

    private val start = OrderFlowState(
        draft = OrderDraft(
            quantities = mapOf("product-1" to 2),
            date = "2026-11-06",
            slotId = "slot-1",
            name = "An",
            phone = "0912345678",
            address = "12 Duong Hoa Sen",
            districtId = "district-1",
            note = "",
            idempotencyKey = "old-key",
        ),
        draftLoaded = true,
        catalog = Load.Ready(orderCatalog()),
    )

    private fun keyAfter(intent: OrderIntent): String = withKeyRule(start, reduce(start, intent), intent, newKey).draft.idempotencyKey

    @Test
    fun everyBodyFieldChangeReplacesTheKey() {
        listOf(
            OrderIntent.SetQuantity("product-1", 3),
            OrderIntent.SetQuantity("product-2", 1),
            OrderIntent.ChooseDate("2026-11-07"),
            OrderIntent.ChooseSlot("slot-2"),
            OrderIntent.EditName("Binh"),
            OrderIntent.EditPhone("0987654321"),
            OrderIntent.EditAddress("1 Duong Khac"),
            OrderIntent.ChooseDistrict("district-2"),
            OrderIntent.EditNote("Giao sang"),
        ).forEach { assertEquals("$it", "fresh-${count + 1}", keyAfter(it)) }
    }

    @Test
    fun anEditThatChangesNothingKeepsTheKey() {
        assertEquals("old-key", keyAfter(OrderIntent.SetQuantity("product-1", 2)))
        assertEquals("old-key", keyAfter(OrderIntent.ChooseDate("2026-11-06")))
        assertEquals("old-key", keyAfter(OrderIntent.EditName("An")))
    }

    // A retry after ERR_OFFLINE, a timeout, 5xx, 429 or ORDERING_PAUSED, or after a restart, touches no draft field.
    @Test
    fun intentsThatLeaveTheBodyAloneKeepTheKey() {
        listOf(OrderIntent.SubmitRecipient, OrderIntent.RetryCatalog, OrderIntent.DismissRemovedNotice, OrderIntent.LoadAvailability)
            .forEach { assertEquals("$it", "old-key", keyAfter(it)) }
    }

    @Test
    fun aRestoredDraftKeepsItsSavedKey() {
        val saved = start.draft.copy(idempotencyKey = "saved-key")
        val intent = OrderIntent.DraftRestored(saved, "fresh")

        val result = withKeyRule(start, reduce(start, intent), intent, newKey)

        assertEquals("saved-key", result.draft.idempotencyKey)
    }

    @Test
    fun aDateClearedByNewAvailabilityReplacesTheKey() {
        val chosen = reduce(
            reduce(start.copy(draft = start.draft.copy(date = "2026-11-05", quantities = mapOf("product-1" to 3))), OrderIntent.LoadAvailability),
            OrderIntent.ChooseSlot("slot-1"),
        )
        val intent = OrderIntent.AvailabilityLoaded(3, Load.Ready(fixtureAvailability()))

        val result = withKeyRule(chosen, reduce(chosen, intent), intent, newKey)

        assertNull(result.draft.date)
        assertNotEquals("old-key", result.draft.idempotencyKey)
    }

    @Test
    fun theCatalogReplacesTheKeyWhenItClearsADistrictOrSlot() {
        val draft = start.draft.copy(districtId = "gone", slotId = "gone")

        val result = reduce(start.copy(draft = draft), OrderIntent.CatalogChanged(Load.Ready(orderCatalog()), "fresh"))

        assertEquals("fresh", result.draft.idempotencyKey)
    }
}
