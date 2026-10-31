package app.banh.customer.ui.order

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.RecordingContactLauncher
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.contact.ContactActions
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-9 (UI document 5.9): the code, the received message, the contact buttons and the way home. */
class ConfirmationScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val shop = ContractAssets.catalog().shop
    private val strings = InstrumentationRegistry.getInstrumentation().targetContext
    private val launcher = RecordingContactLauncher()
    private var homeTaps = 0

    private fun show(launcher: RecordingContactLauncher = this.launcher) {
        rule.setBanhContent {
            val snackbarHostState = remember { SnackbarHostState() }
            val scope = rememberCoroutineScope()
            val actions = remember {
                ContactActions(
                    launcher,
                    scope,
                    snackbarHostState,
                    zaloFailedText = strings.getString(R.string.err_open_zalo),
                    phoneFailedText = strings.getString(R.string.err_open_phone),
                )
            }
            ConfirmationScreen("BT-7K3M9Q", shop, actions, snackbarHostState, onHome = { homeTaps++ })
        }
    }

    // TC-119: only the code and fixed text; no tracking, status or cancel control.
    @Test
    fun showsTheCodeTheReceivedMessageAndNothingElse() {
        show()

        rule.onNodeWithTag(TestTags.CONF_TITLE).assertTextEquals(strings.getString(R.string.conf_title))
        rule.onNodeWithTag(TestTags.CONF_CODE).assertTextEquals("BT-7K3M9Q")
        rule.onNodeWithTag(TestTags.CONF_MESSAGE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.CONF_HOME).assertIsEnabled()
        rule.onNodeWithTag(TestTags.NAV_BACK).assertDoesNotExist()
    }

    // TC-128, AC-25: the message says received and contact, never accepted or guaranteed.
    @Test
    fun messageSaysReceivedAndNeverAcceptedOrGuaranteed() {
        val message = strings.getString(R.string.conf_message)

        assertEquals(true, message.contains("đã nhận"))
        listOf("đã chấp nhận", "đảm bảo", "accepted", "guaranteed").forEach { assertEquals(it, false, message.contains(it, ignoreCase = true)) }
    }

    // TC-121, AC-17: both buttons open the shop contacts like S-2.
    @Test
    fun contactButtonsOpenZaloAndThePhone() {
        show()

        rule.onNodeWithTag(TestTags.CONF_ZALO).assertIsEnabled().performClick()
        rule.onNodeWithTag(TestTags.CONF_PHONE).assertIsEnabled().performClick()

        assertEquals(listOf(shop.zaloContact), launcher.zaloContacts)
        assertEquals(listOf(shop.phoneContact), launcher.phoneContacts)
    }

    // TC-105: a launcher that cannot open tells the customer, and the screen stays usable.
    @Test
    fun aFailedOpenShowsTheMessage() {
        show(RecordingContactLauncher(opens = false))

        rule.onNodeWithTag(TestTags.CONF_ZALO).performClick()
        rule.onNodeWithText(strings.getString(R.string.err_open_zalo)).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.CONF_HOME).assertIsEnabled()
    }

    // TC-139: Home is the only exit.
    @Test
    fun homeLeavesTheScreen() {
        show()

        rule.onNodeWithTag(TestTags.CONF_HOME).performClick()

        assertEquals(1, homeTaps)
    }
}
