package app.banh.customer.ui.home

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.DEFAULT_FONT_SCALE
import app.banh.customer.testing.LARGEST_FONT_SCALE
import app.banh.customer.testing.RecordingContactLauncher
import app.banh.customer.testing.WithFontScale
import app.banh.customer.testing.assertTextNotClipped
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.contact.ContactActions
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-2 states and actions (UI document 5.2). */
class HomeScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val launcher = RecordingContactLauncher()
    private val appStrings = InstrumentationRegistry.getInstrumentation().targetContext

    private val allButtons = listOf(TestTags.HOME_ZALO, TestTags.HOME_PHONE, TestTags.HOME_PRODUCTS, TestTags.HOME_ORDER)

    private fun show(
        state: () -> Load<HomeContent>,
        launcher: RecordingContactLauncher = this.launcher,
        onRetry: () -> Unit = {},
        onViewProducts: () -> Unit = {},
        onPlaceOrder: () -> Unit = {},
        fontScale: Float = DEFAULT_FONT_SCALE,
    ) {
        rule.setBanhContent {
            WithFontScale(fontScale) {
                val snackbarHostState = remember { SnackbarHostState() }
                val scope = rememberCoroutineScope()
                val actions = remember {
                    ContactActions(
                        launcher,
                        scope,
                        snackbarHostState,
                        zaloFailedText = appStrings.getString(R.string.err_open_zalo),
                        phoneFailedText = appStrings.getString(R.string.err_open_phone),
                    )
                }
                HomeScreen(state(), snackbarHostState, actions, onRetry, onViewProducts, onPlaceOrder)
            }
        }
    }

    private fun ready(catalog: Catalog = this.catalog) = Load.Ready(catalog.toHomeContent())

    // TC-102, TC-232, AC-2: Default shows the six elements and every button is enabled.
    @Test
    fun defaultShowsShopNameGreetingAndFourEnabledButtons() {
        show({ ready() })

        rule.onNodeWithTag(TestTags.HOME_SHOP_NAME).assertTextEquals(catalog.shop.name)
        rule.onNodeWithTag(TestTags.HOME_GREETING).assertTextEquals(catalog.shop.greeting)
        allButtons.forEach { rule.onNodeWithTag(it).assertIsDisplayed().assertIsEnabled() }
        rule.onNodeWithTag(TestTags.HOME_NO_CAKES_NOTICE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.ERROR_STATE).assertDoesNotExist()
    }

    // TC-132, TC-232: Loading without a cache shows the skeleton and no button can be used.
    @Test
    fun loadingShowsTheSkeletonAndDisablesEveryButton() {
        show({ Load.Loading })

        rule.onNodeWithTag(TestTags.HOME_SKELETON).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.HOME_SHOP_NAME).assertDoesNotExist()
        allButtons.forEach { rule.onNodeWithTag(it).assertIsNotEnabled() }
    }

    // TC-132, TC-232: Error without a cache shows the message with retry, and all four buttons are disabled.
    @Test
    fun errorShowsRetryAndDisablesEveryButton() {
        var retries = 0
        show({ Load.Failed(LoadFailure.NETWORK) }, onRetry = { retries++ })

        rule.onNodeWithTag(TestTags.ERROR_STATE).assertIsDisplayed()
        allButtons.forEach { rule.onNodeWithTag(it).assertIsNotEnabled() }
        rule.onNodeWithTag(TestTags.STATE_RETRY).performClick()

        assertEquals(1, retries)
    }

    // AC-33, UI 5.2 No cakes: Place order is disabled with the notice, the other buttons keep working.
    @Test
    fun noCakesDisablesPlaceOrderOnlyAndShowsTheNotice() {
        var openedProducts = 0
        var startedOrder = 0
        show({ ready(ContractAssets.catalogWithoutCakes()) }, onViewProducts = { openedProducts++ }, onPlaceOrder = { startedOrder++ })

        rule.onNodeWithTag(TestTags.HOME_NO_CAKES_NOTICE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.HOME_ORDER).assertIsDisplayed().assertIsNotEnabled().performClick()
        listOf(TestTags.HOME_ZALO, TestTags.HOME_PHONE, TestTags.HOME_PRODUCTS).forEach {
            rule.onNodeWithTag(it).assertIsEnabled()
        }
        rule.onNodeWithTag(TestTags.HOME_PRODUCTS).performClick()

        assertEquals("a disabled Place order must not start a flow", 0, startedOrder)
        assertEquals(1, openedProducts)
    }

    // AC-33: the state ends as soon as a later answer has a cake, without reinstalling the app.
    @Test
    fun noCakesEndsWhenACakeBecomesActive() {
        var state: Load<HomeContent> by mutableStateOf(ready(ContractAssets.catalogWithoutCakes()))
        show({ state })
        rule.onNodeWithTag(TestTags.HOME_NO_CAKES_NOTICE).assertIsDisplayed()

        state = ready(ContractAssets.catalogWithCakes(1))

        rule.onNodeWithTag(TestTags.HOME_NO_CAKES_NOTICE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.HOME_ORDER).assertIsEnabled()
    }

    // TC-103, TC-104 (launcher part), AC-3: the buttons hand the shop contacts to the launcher.
    @Test
    fun zaloAndPhoneButtonsOpenTheShopContacts() {
        show({ ready() })

        rule.onNodeWithTag(TestTags.HOME_ZALO).performClick()
        rule.onNodeWithTag(TestTags.HOME_PHONE).performClick()

        assertEquals(listOf(catalog.shop.zaloContact), launcher.zaloContacts)
        assertEquals(listOf(catalog.shop.phoneContact), launcher.phoneContacts)
    }

    // TC-205, TC-105: when Zalo cannot be opened the customer is told, and the screen stays usable.
    @Test
    fun failedZaloShowsTheSnackbarAndKeepsTheButtonsEnabled() {
        show({ ready() }, launcher = RecordingContactLauncher(opens = false))

        rule.onNodeWithTag(TestTags.HOME_ZALO).performClick()

        rule.onNodeWithText(appStrings.getString(R.string.err_open_zalo)).assertIsDisplayed()
        allButtons.forEach { rule.onNodeWithTag(it).assertIsEnabled() }
    }

    // TC-205, TC-105: same for the dialer.
    @Test
    fun failedPhoneShowsTheSnackbar() {
        show({ ready() }, launcher = RecordingContactLauncher(opens = false))

        rule.onNodeWithTag(TestTags.HOME_PHONE).performClick()

        rule.onNodeWithText(appStrings.getString(R.string.err_open_phone)).assertIsDisplayed()
    }

    // TC-125 (large text), UI document 9: with the largest system font the labels still fit and the buttons stay on screen.
    @Test
    fun largeFontScaleDoesNotClipTextOrHideButtons() {
        show({ ready(ContractAssets.catalogWithoutCakes()) }, fontScale = LARGEST_FONT_SCALE)

        rule.onNodeWithTag(TestTags.HOME_SHOP_NAME).assertIsDisplayed()
        rule.assertTextNotClipped(TestTags.HOME_SHOP_NAME)
        rule.assertTextNotClipped(TestTags.HOME_GREETING)
        allButtons.forEach {
            rule.onNodeWithTag(it).assertIsDisplayed()
            rule.assertTextNotClipped(it)
        }
    }
}
