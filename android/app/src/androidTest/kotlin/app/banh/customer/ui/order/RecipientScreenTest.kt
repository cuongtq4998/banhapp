package app.banh.customer.ui.order

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderIntent
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.ReducerHost
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.common.groupThousands
import kotlinx.coroutines.flow.emptyFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-7 (UI document 5.7): required fields, the phone rule, the district list with its fee, and the note limit. */
class RecipientScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val district = catalog.districts[2]

    private fun show(catalog: Load<Catalog> = Load.Ready(this.catalog), onIntent: (OrderIntent) -> Unit = {}) {
        val state = OrderFlowState(draft = OrderDraft.blank("key"), draftLoaded = true, catalog = catalog)
        rule.setBanhContent {
            ReducerHost(state, onIntent) { current, send -> RecipientScreen(current, send, onBack = {}, focusEvents = emptyFlow()) }
        }
    }

    private fun type(tag: String, text: String) {
        rule.onNodeWithTag(tag).performTextInput(text)
    }

    private fun tapNext() {
        rule.onNodeWithTag(TestTags.ORDER_NEXT).performClick()
    }

    // AC-12: Next with empty fields shows an error next to every required field at once.
    @Test
    fun nextOnAnEmptyFormShowsAnErrorBesideEachRequiredField() {
        show()

        tapNext()

        listOf("name", "phone", "address", "district").forEach {
            rule.onNodeWithTag(TestTags.orderFieldError(it), useUnmergedTree = true).performScrollTo().assertIsDisplayed()
        }
        rule.onNodeWithTag(TestTags.ORDER_NOTE_ERROR, useUnmergedTree = true).assertDoesNotExist()
    }

    @Test
    fun anErrorClearsWhenItsFieldBecomesValid() {
        show()
        tapNext()

        type(TestTags.ORDER_FIELD_NAME, "An")

        rule.onNodeWithTag(TestTags.orderFieldError("name"), useUnmergedTree = true).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.orderFieldError("phone"), useUnmergedTree = true).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun aLandlineNumberGetsTheInvalidPhoneMessage() {
        show()
        type(TestTags.ORDER_FIELD_PHONE, "0212345678")

        tapNext()

        rule.onNodeWithTag(TestTags.orderFieldError("phone"), useUnmergedTree = true).assertTextEquals("Vui lòng nhập số điện thoại di động Việt Nam (10 số, ví dụ 09xx xxx xxx).")
    }

    @Test
    fun aMobileNumberWithSeparatorsRaisesNoPhoneError() {
        show()
        type(TestTags.ORDER_FIELD_PHONE, "0912 345 678")

        tapNext()

        rule.onNodeWithTag(TestTags.orderFieldError("phone"), useUnmergedTree = true).assertDoesNotExist()
    }

    // AC-11: only listed districts, each with its flat fee; the fee shows once one is chosen.
    @Test
    fun choosingADistrictShowsItsFee() {
        show()
        rule.onNodeWithTag(TestTags.ORDER_DISTRICT_FEE).assertDoesNotExist()

        rule.onNodeWithTag(TestTags.ORDER_FIELD_DISTRICT).performScrollTo().performClick()
        catalog.districts.forEach { rule.onNodeWithTag(TestTags.orderDistrictRow(it.id)).assertIsDisplayed() }
        rule.onNodeWithTag(TestTags.orderDistrictRow(district.id)).performClick()

        rule.onNodeWithTag(TestTags.ORDER_DISTRICT_FEE).assertTextEquals("Phí giao hàng: ${groupThousands(district.deliveryFeeVnd)} ₫")
        rule.onNodeWithTag(TestTags.orderFieldError("district"), useUnmergedTree = true).assertDoesNotExist()
    }

    // AC-26: 200 characters accepted, the 201st not inserted and the message beside the field.
    @Test
    fun noteTakesTwoHundredCharactersAndRefusesTheNext() {
        show()
        type(TestTags.ORDER_FIELD_NOTE, "x".repeat(200))
        rule.onNodeWithTag(TestTags.ORDER_NOTE_COUNTER, useUnmergedTree = true).assertTextEquals("200/200")
        rule.onNodeWithTag(TestTags.ORDER_NOTE_ERROR, useUnmergedTree = true).assertDoesNotExist()

        type(TestTags.ORDER_FIELD_NOTE, "y")

        rule.onNodeWithTag(TestTags.ORDER_NOTE_COUNTER, useUnmergedTree = true).assertTextEquals("200/200")
        rule.onNodeWithTag(TestTags.ORDER_NOTE_ERROR, useUnmergedTree = true).assertTextEquals("Ghi chú tối đa 200 ký tự.")
    }

    @Test
    fun pastedNoteIsCutAtTwoHundred() {
        show()

        type(TestTags.ORDER_FIELD_NOTE, "z".repeat(260))

        rule.onNodeWithTag(TestTags.ORDER_NOTE_COUNTER, useUnmergedTree = true).assertTextEquals("200/200")
        rule.onNodeWithTag(TestTags.ORDER_NOTE_ERROR, useUnmergedTree = true).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun districtListStillLoadingDisablesThePickerButNotTheOtherFields() {
        show(catalog = Load.Loading)

        rule.onNodeWithTag(TestTags.ORDER_FIELD_DISTRICT).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.ORDER_FIELD_NAME).assertIsEnabled()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsEnabled()
    }

    @Test
    fun districtListFailureShowsRetryBesideThePicker() {
        val intents = mutableListOf<OrderIntent>()
        show(catalog = Load.Failed(LoadFailure.OTHER), onIntent = { intents += it })

        rule.onNodeWithTag(TestTags.ORDER_DISTRICT_ERROR).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_FIELD_DISTRICT).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.STATE_RETRY).performScrollTo().performClick()

        assertEquals(listOf<OrderIntent>(OrderIntent.RetryCatalog), intents)
    }

    @Test
    fun noServedDistrictShowsTheMessageAndBlocksNext() {
        show(catalog = Load.Ready(catalog.copy(districts = emptyList())))

        rule.onNodeWithTag(TestTags.ORDER_DISTRICT_EMPTY).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
    }
}
