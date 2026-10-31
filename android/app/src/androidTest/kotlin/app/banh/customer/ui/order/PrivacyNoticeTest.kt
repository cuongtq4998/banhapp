package app.banh.customer.ui.order

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.unit.dp
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderIntent
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.LARGEST_FONT_SCALE
import app.banh.customer.testing.ReducerHost
import app.banh.customer.testing.WithFontScale
import app.banh.customer.testing.assertTextNotClipped
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.privacy.LocalPrivacyEnvironment
import app.banh.customer.ui.privacy.PrivacyEnvironment
import kotlinx.coroutines.flow.emptyFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/** FR-20, AC-30: the privacy notice card on S-7 and the reminder link on S-8 (UI document 5.7, 5.8, 9.2). */
class PrivacyNoticeTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val opened = mutableListOf<String>()
    private val failures = mutableListOf<String>()
    private var canOpen = true

    private val environment get() = PrivacyEnvironment({ url -> opened += url; canOpen }, { failures += it })

    private fun showRecipient(load: Load<Catalog> = Load.Ready(catalog), fontScale: Float = 1f, draft: OrderDraft = OrderDraft.blank("key")) {
        val state = OrderFlowState(draft = draft, draftLoaded = true, catalog = load)
        rule.setBanhContent {
            CompositionLocalProvider(LocalPrivacyEnvironment provides environment) {
                WithFontScale(fontScale) {
                    ReducerHost(state, {}) { current, send -> RecipientScreen(current, send, onBack = {}, focusEvents = emptyFlow()) }
                }
            }
        }
    }

    @Test
    fun cardIsVisibleOnEntryAboveTheNameFieldWithItsTexts() {
        showRecipient()

        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_CARD).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_TITLE).assertTextEquals("Thông tin của bạn được dùng như thế nào")
        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_BODY).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_DRAFT).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_LINK).assertIsDisplayed()
        val card = rule.onNodeWithTag(TestTags.ORDER_PRIVACY_CARD).getUnclippedBoundsInRoot()
        val name = rule.onNodeWithTag(TestTags.ORDER_FIELD_NAME).getUnclippedBoundsInRoot()
        assertTrue("card ${card.bottom} must end above the name field ${name.top}", card.bottom <= name.top)
        assertTrue("link is at least 48 dp high", rule.onNodeWithTag(TestTags.ORDER_PRIVACY_LINK).getUnclippedBoundsInRoot().let { it.bottom - it.top } >= 48.dp)
    }

    @Test
    fun cardStaysWhileTheDistrictListFails() {
        showRecipient(Load.Failed(LoadFailure.NETWORK))

        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_CARD).assertIsDisplayed()
    }

    @Test
    fun cardStaysAfterAFailedNextAndAfterEditing() {
        showRecipient()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).performClick()
        rule.onNodeWithTag(TestTags.ORDER_FIELD_NAME).performTextInput("An")

        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_CARD).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun cardTextIsNotClippedAtTheLargestTextSize() {
        showRecipient(fontScale = LARGEST_FONT_SCALE)

        listOf(TestTags.ORDER_PRIVACY_TITLE, TestTags.ORDER_PRIVACY_BODY, TestTags.ORDER_PRIVACY_DRAFT).forEach {
            rule.onNodeWithTag(it).performScrollTo()
            rule.assertTextNotClipped(it)
        }
    }

    @Test
    fun tappingTheLinkOpensThePrivacyPage() {
        showRecipient()

        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_LINK).performClick()

        assertEquals(1, opened.size)
        assertTrue(opened.single().endsWith("/privacy"))
        assertTrue(failures.isEmpty())
    }

    @Test
    fun aLinkThatCannotOpenTellsTheCustomerAndKeepsTheCard() {
        canOpen = false
        showRecipient()

        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_LINK).performClick()

        assertEquals(listOf("Không mở được trang chính sách. Vui lòng thử lại sau."), failures)
        rule.onNodeWithTag(TestTags.ORDER_PRIVACY_BODY).assertIsDisplayed()
    }

    private fun showReview(sending: Boolean) {
        val district = catalog.districts[2]
        val draft = OrderDraft(
            quantities = mapOf(catalog.products[0].id to 2, catalog.products[2].id to 3),
            date = "2026-11-04",
            slotId = catalog.slots[1].id,
            name = "Nguyễn An",
            phone = "0912 345 678",
            address = "12 Đường Hoa Sen",
            districtId = district.id,
            idempotencyKey = "key",
        )
        val state = OrderFlowState(draft = draft, draftLoaded = true, catalog = Load.Ready(catalog))
        val actions = ReviewActions(onBack = {}, onEditCakes = {}, onEditDelivery = {}, onEditRecipient = {})
        rule.setBanhContent {
            CompositionLocalProvider(LocalPrivacyEnvironment provides environment) {
                ReviewScreen(state, actions, sending = sending)
            }
        }
    }

    @Test
    fun reviewShowsTheReminderAndTheLinkWhichOpensTheSamePage() {
        showReview(sending = false)

        rule.onNodeWithTag(TestTags.REVIEW_PRIVACY).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.REVIEW_PRIVACY_LINK).performScrollTo().assertIsDisplayed().performClick()

        assertTrue(opened.single().endsWith("/privacy"))
    }

    @Test
    fun reviewLinkFailureShowsTheSameMessage() {
        canOpen = false
        showReview(sending = false)

        rule.onNodeWithTag(TestTags.REVIEW_PRIVACY_LINK).performScrollTo().performClick()

        assertEquals(1, failures.size)
    }

    @Test
    fun reviewLinkIsDisabledWhileSending() {
        showReview(sending = true)

        rule.onNodeWithTag(TestTags.REVIEW_PRIVACY_LINK).performScrollTo().assertIsNotEnabled()
    }
}
