package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.testing.orderCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** S-7 rules: AC-11, AC-12, AC-26. */
class RecipientReducerTest {
    private val catalog = orderCatalog()
    private val start = OrderFlowState(draft = OrderDraft.blank("k"), draftLoaded = true, catalog = Load.Ready(catalog))

    private fun OrderFlowState.then(vararg intents: OrderIntent) = intents.fold(this) { acc, intent -> reduce(acc, intent) }

    // AC-12: every failing field gets an error at once, in screen order, and the first one takes the focus.
    @Test
    fun nextOnAnEmptyFormFailsEveryRequiredFieldInScreenOrder() {
        val result = start.then(OrderIntent.SubmitRecipient)

        assertEquals(
            listOf(RecipientField.NAME, RecipientField.PHONE, RecipientField.ADDRESS, RecipientField.DISTRICT),
            result.recipientErrors.keys.toList(),
        )
        assertEquals(RecipientError.PHONE_REQUIRED, result.recipientErrors[RecipientField.PHONE])
    }

    @Test
    fun aLandlineNumberIsInvalidNotMissing() {
        val result = start.then(OrderIntent.EditPhone("0212345678"), OrderIntent.SubmitRecipient)

        assertEquals(RecipientError.PHONE_INVALID, result.recipientErrors[RecipientField.PHONE])
    }

    @Test
    fun aCompleteFormHasNoErrors() {
        val result = start.then(
            OrderIntent.EditName("An"),
            OrderIntent.EditPhone("0912 345 678"),
            OrderIntent.EditAddress("12 Duong Hoa Sen"),
            OrderIntent.ChooseDistrict("district-2"),
            OrderIntent.SubmitRecipient,
        )

        assertTrue(result.recipientErrors.isEmpty())
        assertEquals("district-2", result.draft.districtId)
    }

    @Test
    fun anErrorGoesAwayAsSoonAsItsFieldIsValidAndOthersStay() {
        val failed = start.then(OrderIntent.SubmitRecipient)

        val result = failed.then(OrderIntent.EditName("An"))

        assertFalse(RecipientField.NAME in result.recipientErrors)
        assertTrue(RecipientField.PHONE in result.recipientErrors)
    }

    @Test
    fun anErrorChangesWhenAnotherRuleNowFails() {
        val failed = start.then(OrderIntent.SubmitRecipient)

        val result = failed.then(OrderIntent.EditPhone("091"))

        assertEquals(RecipientError.PHONE_INVALID, result.recipientErrors[RecipientField.PHONE])
    }

    @Test
    fun typingInAFieldWithoutAnErrorDoesNotInventOne() {
        assertTrue(start.then(OrderIntent.EditPhone("09")).recipientErrors.isEmpty())
    }

    // AC-11: a district that is not on the list counts as missing.
    @Test
    fun aDistrictOutsideTheListIsNotAcceptable() {
        val result = start.then(OrderIntent.ChooseDistrict("elsewhere"), OrderIntent.SubmitRecipient)

        assertEquals(RecipientError.DISTRICT_REQUIRED, result.recipientErrors[RecipientField.DISTRICT])
    }

    @Test
    fun nameAndAddressAreCutAtTheirLimitsWithoutAMessage() {
        val result = start.then(OrderIntent.EditName("n".repeat(120)), OrderIntent.EditAddress("a".repeat(300)))

        assertEquals(100, result.draft.name.length)
        assertEquals(250, result.draft.address.length)
        assertFalse(result.noteLimitHit)
    }

    // AC-26: 200 characters are accepted; the 201st is not inserted and the message shows.
    @Test
    fun noteAcceptsTwoHundredAndRejectsTheTwoHundredAndFirstCharacter() {
        val atLimit = start.then(OrderIntent.EditNote("x".repeat(200)))
        assertEquals(200, atLimit.draft.note.length)
        assertFalse(atLimit.noteLimitHit)

        val over = atLimit.then(OrderIntent.EditNote("x".repeat(201)))
        assertEquals(200, over.draft.note.length)
        assertTrue(over.noteLimitHit)

        assertFalse(over.then(OrderIntent.EditNote("x".repeat(150))).noteLimitHit)
    }

    @Test
    fun theNoteLimitFollowsTheCatalogSetting() {
        val longer = catalog.copy(settings = catalog.settings.copy(noteMaxLength = 300))
        val state = start.copy(catalog = Load.Ready(longer))

        assertEquals(300, state.then(OrderIntent.EditNote("x".repeat(400))).draft.note.length)
    }

    @Test
    fun theNoteIsOptional() {
        val result = start.then(
            OrderIntent.EditName("An"),
            OrderIntent.EditPhone("0912345678"),
            OrderIntent.EditAddress("12 Duong Hoa Sen"),
            OrderIntent.ChooseDistrict("district-1"),
            OrderIntent.SubmitRecipient,
        )

        assertEquals("", result.draft.note)
        assertTrue(result.recipientErrors.isEmpty())
    }
}
