package app.banh.customer.ui.order

import androidx.compose.ui.test.assertContentDescriptionContains
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.availability.Availability
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.LoadedAvailability
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderIntent
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.ReducerHost
import app.banh.customer.testing.setBanhContent
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-6 with the availability fixture: server date 2026-11-02, lead 2, horizon 30, 11-05 and 11-20 full (cakes 3). */
class DateScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val slots = catalog.slots
    private val orderOfThree = OrderDraft(quantities = mapOf(catalog.products[0].id to 3), idempotencyKey = "key")

    private fun stateOf(
        availability: Load<LoadedAvailability>? = Load.Ready(LoadedAvailability(3, ContractAssets.availability())),
        draft: OrderDraft = orderOfThree,
        dateCleared: Boolean = false,
    ) = OrderFlowState(draft = draft, draftLoaded = true, catalog = Load.Ready(catalog), availability = availability, dateCleared = dateCleared)

    private fun show(state: OrderFlowState, onIntent: (OrderIntent) -> Unit = {}, onBack: () -> Unit = {}) {
        rule.setBanhContent {
            ReducerHost(state, onIntent) { current, send -> DateScreen(current, send, onBack = onBack, onNext = {}) }
        }
    }

    private fun tap(tag: String) {
        rule.onNodeWithTag(tag).performScrollTo().performClick()
    }

    // TC-110, AC-7: nothing before server date + lead days can be chosen; the first allowed day can.
    @Test
    fun datesInTheLeadWindowAreDisabledAndTheFirstAllowedDayIsNot() {
        show(stateOf())

        rule.onNodeWithTag(TestTags.orderDate("2026-11-02")).assertIsNotEnabled().assertContentDescriptionContains("ít nhất 2 ngày", substring = true)
        rule.onNodeWithTag(TestTags.orderDate("2026-11-03")).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.orderDate("2026-11-04")).assertIsEnabled()
    }

    // TC-111, AC-8: a date without room for the order is disabled and spoken as full; others stay selectable.
    @Test
    fun aFullDateIsDisabledAndSpokenAsFull() {
        show(stateOf())

        rule.onNodeWithTag(TestTags.orderDate("2026-11-05")).assertIsNotEnabled().assertContentDescriptionContains("không còn đủ chỗ", substring = true)
        rule.onNodeWithTag(TestTags.orderDate("2026-11-06")).assertIsEnabled()
    }

    // TC-112, AC-24: the last month holds the last allowed day and refuses the day after; next-month is disabled there.
    @Test
    fun theLastAllowedDayIsSelectableAndTheDayAfterIsNot() {
        show(stateOf())

        rule.onNodeWithTag(TestTags.ORDER_DATE_PREVIOUS).assertIsNotEnabled()
        tap(TestTags.ORDER_DATE_NEXT)

        rule.onNodeWithTag(TestTags.ORDER_DATE_NEXT).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.ORDER_DATE_PREVIOUS).assertIsEnabled()
        rule.onNodeWithTag(TestTags.orderDate("2026-12-02")).assertIsEnabled()
        rule.onNodeWithTag(TestTags.orderDate("2026-12-03")).assertIsNotEnabled().assertContentDescriptionContains("tối đa 30 ngày", substring = true)
    }

    @Test
    fun tappingAnotherDateReplacesTheSelection() {
        show(stateOf())

        tap(TestTags.orderDate("2026-11-06"))
        rule.onNodeWithTag(TestTags.orderDate("2026-11-06")).assertIsSelected()
        tap(TestTags.orderDate("2026-11-07"))

        rule.onNodeWithTag(TestTags.orderDate("2026-11-07")).assertIsSelected()
        rule.onNodeWithTag(TestTags.orderDate("2026-11-06")).assertIsNotSelected()
    }

    // TC-114, AC-10: Next needs both; the same slots serve every date; a slot changes no date's availability.
    @Test
    fun nextNeedsADateAndASlotAndASlotChangesNoAvailability() {
        show(stateOf())
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.ORDER_DATE_HINT).performScrollTo().assertIsDisplayed()

        tap(TestTags.orderDate("2026-11-06"))
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        tap(TestTags.orderSlot(slots[1].id))

        rule.onNodeWithTag(TestTags.orderSlot(slots[1].id)).assertIsSelected()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsEnabled()
        rule.onNodeWithTag(TestTags.ORDER_DATE_HINT).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.orderDate("2026-11-05")).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.orderDate("2026-11-04")).assertIsEnabled()
        slots.forEach { rule.onNodeWithTag(TestTags.orderSlot(it.id)).performScrollTo().assertIsDisplayed() }
    }

    @Test
    fun restoredDateAndSlotAreShownSelected() {
        val draft = orderOfThree.copy(date = "2026-11-06", slotId = slots[0].id)
        show(stateOf(draft = draft))

        rule.onNodeWithTag(TestTags.orderDate("2026-11-06")).assertIsSelected()
        rule.onNodeWithTag(TestTags.orderSlot(slots[0].id)).assertIsSelected()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsEnabled()
    }

    // UI 5.6 Validation: the date lost its room; the slot stays and the message shows.
    @Test
    fun clearedDateMessageShowsAndTheSlotStays() {
        val draft = orderOfThree.copy(slotId = slots[0].id)
        show(stateOf(draft = draft, dateCleared = true))

        rule.onNodeWithTag(TestTags.ORDER_DATE_CLEARED).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.orderSlot(slots[0].id)).assertIsSelected()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
    }

    // UI 5.6 Empty: every date unavailable for this size; the action returns to S-5.
    @Test
    fun noSelectableDateShowsTheMessageAndAWayBackToTheQuantities() {
        val allFull = Availability("2026-11-02", ContractAssets.availability().dates.map { it.copy(available = false, reason = "FULL") })
        var wentBack = 0
        show(stateOf(availability = Load.Ready(LoadedAvailability(3, allFull))), onBack = { wentBack++ })

        rule.onNodeWithTag(TestTags.ORDER_DATE_EMPTY).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        tap(TestTags.ORDER_DATE_EMPTY_ACTION)

        assertEquals(1, wentBack)
    }

    @Test
    fun loadingShowsTheSkeletonAndNoWayForward() {
        show(stateOf(availability = Load.Loading))

        rule.onNodeWithTag(TestTags.ORDER_DATE_LOADING).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.orderDate("2026-11-04")).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
    }

    @Test
    fun failedAvailabilityShowsTheErrorAndRetryLoadsAgain() {
        val intents = mutableListOf<OrderIntent>()
        show(stateOf(availability = Load.Failed(LoadFailure.NETWORK)), onIntent = { intents += it })

        rule.onNodeWithTag(TestTags.ERROR_STATE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        tap(TestTags.STATE_RETRY)

        assertEquals(listOf<OrderIntent>(OrderIntent.LoadAvailability), intents)
    }
}
