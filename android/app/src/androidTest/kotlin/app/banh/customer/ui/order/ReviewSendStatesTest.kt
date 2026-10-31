package app.banh.customer.ui.order

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.NotSentReason
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.PriceUpdate
import app.banh.customer.order.SubmitProblem
import app.banh.customer.order.SubmitRule
import app.banh.customer.order.SubmitState
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.common.groupThousands
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-8 send states (UI document 5.8): sending, every error kind, and the price change. */
class ReviewSendStatesTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val strings = InstrumentationRegistry.getInstrumentation().targetContext
    private val ids = catalog.products.map { it.id }
    private val taps = mutableListOf<String>()

    private val draft = OrderDraft(
        quantities = mapOf(ids[0] to 2, ids[2] to 3),
        date = "2026-11-04",
        slotId = catalog.slots[1].id,
        name = "Nguyễn An",
        phone = "0912 345 678",
        address = "12 Đường Hoa Sen",
        districtId = catalog.districts[2].id,
        idempotencyKey = "key",
    )

    private var current by mutableStateOf<OrderFlowState?>(null)
    private var contentSet = false

    private fun show(submit: SubmitState, priceUpdate: PriceUpdate? = null) {
        current = OrderFlowState(draft = draft, draftLoaded = true, catalog = Load.Ready(catalog), submit = submit, priceUpdate = priceUpdate)
        if (contentSet) return
        contentSet = true
        val actions = ReviewActions(
            onBack = { taps += "back" },
            onEditCakes = { taps += "cakes" },
            onEditDelivery = { taps += "delivery" },
            onEditRecipient = { taps += "recipient" },
            onConfirm = { taps += "confirm" },
        )
        rule.setBanhContent { current?.let { ReviewScreen(it, actions) } }
    }

    private fun failed(problem: SubmitProblem) = SubmitState.Failed(problem)

    // TC-266, AC-19: while sending, confirm and every Edit control are off and the button says so.
    @Test
    fun sendingDisablesConfirmAndEditControls() {
        show(SubmitState.Sending)

        rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsNotEnabled().assertTextContains(strings.getString(R.string.btn_sending))
        rule.onNodeWithTag(TestTags.REVIEW_EDIT_CAKES).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.REVIEW_EDIT_DELIVERY).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.REVIEW_EDIT_RECIPIENT).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.REVIEW_PRIVACY_LINK).performScrollTo().assertIsNotEnabled()
    }

    // TC-113, TC-117, TC-126, TC-138: each rule error names its fix, blocks confirm, and its action opens the step.
    @Test
    fun ruleErrorsBlockConfirmAndTheActionOpensTheRightStep() {
        val cases = listOf(
            Triple(SubmitProblem.Rule(SubmitRule.MIN_QTY, number = 2), R.string.date_empty_action, "cakes"),
            Triple(SubmitProblem.Rule(SubmitRule.DATE_CAPACITY, date = "2026-11-05"), R.string.action_choose_date, "delivery"),
            Triple(SubmitProblem.Rule(SubmitRule.DATE_LEAD, number = 2), R.string.action_choose_date, "delivery"),
            Triple(SubmitProblem.Rule(SubmitRule.DATE_HORIZON, number = 30), R.string.action_choose_date, "delivery"),
            Triple(SubmitProblem.Rule(SubmitRule.SLOT_UNAVAILABLE), R.string.action_choose_slot, "delivery"),
            Triple(SubmitProblem.Rule(SubmitRule.DISTRICT_UNSERVED), R.string.action_choose_district, "recipient"),
            Triple(SubmitProblem.Rule(SubmitRule.PRODUCT_UNAVAILABLE), R.string.date_empty_action, "cakes"),
        )
        cases.forEach { (problem, label, step) ->
            taps.clear()
            show(failed(problem))

            rule.onNodeWithTag(TestTags.REVIEW_ISSUE).performScrollTo().assertIsDisplayed()
            rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsNotEnabled()
            rule.onNodeWithTag(TestTags.REVIEW_MESSAGE_ACTION).performClick().assertTextEquals(strings.getString(label))
            assertEquals(listOf(step), taps)
        }
    }

    @Test
    fun capacityMessageNamesTheDate() {
        show(failed(SubmitProblem.Rule(SubmitRule.DATE_CAPACITY, date = "2026-11-05")))

        rule.onNode(hasText("05/11/2026", substring = true) and hasAnyAncestor(hasTestTag(TestTags.REVIEW_ISSUE))).assertIsDisplayed()
    }

    // TC-124, TC-138: not-sent errors keep confirm on and the retry sends again.
    @Test
    fun notSentErrorsOfferRetryAndKeepConfirmEnabled() {
        NotSentReason.entries.forEach { reason ->
            taps.clear()
            show(failed(SubmitProblem.NotSent(reason)))

            rule.onNodeWithTag(TestTags.REVIEW_ISSUE).performScrollTo().assertIsDisplayed()
            rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsEnabled()
            rule.onNodeWithTag(TestTags.REVIEW_MESSAGE_ACTION).performClick()
            assertEquals(listOf("confirm"), taps)
        }
    }

    // TC-127: the new prices and total are on screen, the message is shown, confirm stays enabled.
    @Test
    fun priceChangeShowsNewTotalAndKeepsConfirmEnabled() {
        val newPrice = catalog.products[0].priceVnd + 5_000L
        val update = PriceUpdate(
            districtId = catalog.districts[2].id,
            pricesVnd = mapOf(ids[0] to newPrice),
            deliveryFeeVnd = catalog.districts[2].deliveryFeeVnd,
            changedProductIds = setOf(ids[0]),
            totalChanged = true,
        )
        show(failed(SubmitProblem.PriceChanged), update)

        val total = 2 * newPrice + 3 * catalog.products[2].priceVnd + catalog.districts[2].deliveryFeeVnd
        rule.onNodeWithTag(TestTags.REVIEW_PRICE_CHANGED).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.REVIEW_TOTAL).assertTextEquals("${groupThousands(total)} ₫")
        rule.onNodeWithTag(TestTags.reviewItemPrice(ids[0])).assertTextEquals("${groupThousands(2 * newPrice)} ₫")
        rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsEnabled()
    }
}
