package app.banh.customer.ui.order

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.common.groupThousands
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-8 (UI document 5.8): the order as the customer entered it, the correct total, and the stubbed confirm. */
class ReviewScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val district = catalog.districts[2]
    private val slot = catalog.slots[1]
    private val ids = catalog.products.map { it.id }

    private val draft = OrderDraft(
        quantities = mapOf(ids[0] to 2, ids[2] to 3),
        date = "2026-11-04",
        slotId = slot.id,
        name = "  Nguyễn An ",
        phone = "0912 345 678",
        address = "12 Đường Hoa Sen",
        districtId = district.id,
        idempotencyKey = "key",
    )

    private val edits = mutableListOf<String>()

    private fun show(draft: OrderDraft = this.draft) {
        val state = OrderFlowState(draft = draft, draftLoaded = true, catalog = Load.Ready(catalog))
        val actions = ReviewActions(
            onBack = { edits += "back" },
            onEditCakes = { edits += "cakes" },
            onEditDelivery = { edits += "delivery" },
            onEditRecipient = { edits += "recipient" },
        )
        rule.setBanhContent { ReviewScreen(state, actions) }
    }

    // TC-109, AC-6: only the cakes with a quantity above 0, each with its line price.
    @Test
    fun onlyCakesWithAQuantityAreListedWithTheirLinePrices() {
        show()

        rule.onNodeWithTag(TestTags.reviewItem(ids[0])).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.reviewItem(ids[2])).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.reviewItem(ids[1])).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.reviewItem(ids[3])).assertDoesNotExist()
    }

    // AC-14: total = 2a + 3c + fee.
    @Test
    fun totalIsTheLinePricesPlusTheDistrictFee() {
        show()

        val cakes = 2 * catalog.products[0].priceVnd + 3 * catalog.products[2].priceVnd
        rule.onNodeWithTag(TestTags.REVIEW_FEE).assertTextEquals("${groupThousands(district.deliveryFeeVnd)} ₫")
        rule.onNodeWithTag(TestTags.REVIEW_TOTAL).assertTextEquals("${groupThousands(cakes + district.deliveryFeeVnd)} ₫")
    }

    // AC-31 (pending owner confirmation): 2026-11-04 shows as 04/11/2026.
    @Test
    fun deliveryDetailsAreShownAsEnteredAndTheDateInDayMonthYear() {
        show()

        rule.onNodeWithTag(TestTags.REVIEW_DATE).assertTextEquals("04/11/2026")
        rule.onNodeWithTag(TestTags.REVIEW_TIME).assertTextEquals("${slot.start} – ${slot.end}")
        rule.onNodeWithTag(TestTags.REVIEW_NAME).assertTextEquals("Nguyễn An")
        rule.onNodeWithTag(TestTags.REVIEW_PHONE).assertTextEquals("0912 345 678")
        rule.onNodeWithTag(TestTags.REVIEW_ADDRESS).assertTextEquals("12 Đường Hoa Sen, ${district.name}")
        rule.onNodeWithTag(TestTags.REVIEW_PRIVACY).performScrollTo().assertIsDisplayed()
    }

    // AC-26: a note of 200 characters is shown in full; without a note the row is absent.
    @Test
    fun noteRowAppearsOnlyWhenANoteWasEntered() {
        show()
        rule.onNodeWithTag(TestTags.REVIEW_NOTE).assertDoesNotExist()
    }

    @Test
    fun aNoteOfTwoHundredCharactersIsShown() {
        val note = "n".repeat(200)
        show(draft.copy(note = note))

        rule.onNodeWithTag(TestTags.REVIEW_NOTE).assertTextEquals(note)
    }

    // Slice 3 enables the send; until then the button is present and off.
    @Test
    fun confirmIsPresentButNotYetEnabled() {
        show()

        rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsDisplayed().assertIsNotEnabled()
    }

    // AC-18: each Edit control leads to the step that holds the data.
    @Test
    fun editControlsLeadToTheMatchingSteps() {
        show()

        rule.onNodeWithTag(TestTags.REVIEW_EDIT_CAKES).performScrollTo().performClick()
        rule.onNodeWithTag(TestTags.REVIEW_EDIT_DELIVERY).performScrollTo().performClick()
        rule.onNodeWithTag(TestTags.REVIEW_EDIT_RECIPIENT).performScrollTo().performClick()
        rule.onNodeWithTag(TestTags.NAV_BACK).performClick()

        assertEquals(listOf("cakes", "delivery", "recipient", "back"), edits)
    }

    // AC-13: fewer cakes than the minimum shows the minimum with a way to the quantities.
    @Test
    fun belowTheMinimumTheMinimumIsStatedWithAWayToFixIt() {
        show(draft.copy(quantities = mapOf(ids[0] to 1)))

        rule.onNodeWithTag(TestTags.REVIEW_ISSUE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.REVIEW_CONFIRM).assertIsNotEnabled()
    }
}
