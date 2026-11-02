package app.banh.admin.flows

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.AdminApplication
import app.banh.admin.push.PrefsAskedFlag
import app.banh.admin.push.PushMessage
import app.banh.admin.stub.StubBackend
import app.banh.admin.stub.StubTokenProvider
import app.banh.admin.testing.has
import app.banh.admin.testing.launchStub
import app.banh.admin.testing.signIn
import app.banh.admin.testing.tap
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.withStub
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeFalse
import org.junit.Rule
import org.junit.Test

private const val ORDER = "BT-7K3M9Q"

/** FR-25 and FR-26 with the debug stub's token provider: registration, the foreground toast, the tap on a notification, sign-out. */
class PushFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val push get() = (context.applicationContext as AdminApplication).container.push

    @Test
    fun theTokenIsRegisteredRightAfterSignIn() = withStub {
        StubBackend.pushTokens.clear()
        rule.signIn()
        rule.waitUntil(5_000) { StubBackend.pushTokens.isNotEmpty() }
        assertEquals("stub-token-1", StubBackend.pushTokens.first())
    }

    @Test
    fun anOrderThatArrivesWhileTheAppIsOpenShowsAToastThatOpensTheOrder() = withStub {
        rule.signIn()
        push.deliver(PushMessage(ORDER, "2", "03/11/2026"))
        rule.waitForTag(AdminTags.TOAST).assertTextContains(ORDER, substring = true)
        rule.onNodeWithTag(AdminTags.TOAST).performClick()
        rule.waitForTag(AdminTags.DETAIL_CODE).assertTextContains(ORDER)
        rule.tap(AdminTags.NAV_BACK)
        rule.waitForTag(AdminTags.ORDERS_LIST)
    }

    @Test
    fun aTapOnANotificationOpensTheOrderAndBackReturnsToTheList() = withStub {
        rule.signIn()
        push.requestOrder(ORDER)
        rule.waitForTag(AdminTags.DETAIL_CODE).assertTextContains(ORDER)
        rule.tap(AdminTags.NAV_BACK)
        rule.waitForTag(AdminTags.ORDERS_LIST)
    }

    @Test
    fun aTapWhileSignedOutIsKeptInMemoryAndOpensTheOrderAfterSignIn() = withStub {
        rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("nhanvien.a@example.com")
        push.requestOrder(ORDER)
        rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
        rule.waitForTag(AdminTags.CODE_FIELD).performTextInput("123456")
        rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
        rule.waitForTag(AdminTags.DETAIL_CODE).assertTextContains(ORDER)
    }

    @Test
    fun anUnknownOrderShowsTheGoneMessage() = withStub {
        rule.signIn()
        push.requestOrder("BT-000000")
        rule.waitForTag(AdminTags.DETAIL_GONE)
    }

    @Test
    fun signOutMakesThePhoneForgetItsToken() = withStub {
        rule.signIn()
        rule.waitUntil(5_000) { push.lastRegistered != null }
        val before = StubTokenProvider.forgotten
        rule.tap(AdminTags.ORDERS_ACCOUNT)
        rule.tap(AdminTags.ACCOUNT_SIGN_OUT)
        rule.tap(AdminTags.ACCOUNT_SIGN_OUT_YES)
        rule.waitForTag(AdminTags.SIGNIN_EMAIL)
        rule.waitUntil(5_000) { StubTokenProvider.forgotten > before && push.lastRegistered == null }
    }

    /** Only meaningful on a fresh install (a granted permission cannot be taken back inside the test); skipped otherwise. */
    @Test
    fun afterARefusalNothingIsAskedOrSentAndEveryFunctionWorks() {
        val granted = context.checkSelfPermission("android.permission.POST_NOTIFICATIONS") == 0
        assumeFalse("permission already granted on this install", granted)
        PrefsAskedFlag(context).asked = true
        StubBackend.pushTokens.clear()
        launchStub(grantNotifications = false).use {
            rule.signIn()
            Thread.sleep(1_500)
            assertTrue(StubBackend.pushTokens.isEmpty())
        }
    }

    @Test
    fun theQuestionIsAskedOnceAfterTheFirstSignIn() {
        val granted = context.checkSelfPermission("android.permission.POST_NOTIFICATIONS") == 0
        assumeFalse("permission already granted on this install", granted)
        val flag = PrefsAskedFlag(context).also { it.asked = false }
        launchStub(grantNotifications = false).use {
            rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("nhanvien.a@example.com")
            rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
            rule.waitForTag(AdminTags.CODE_FIELD).performTextInput("123456")
            rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
            rule.waitUntil(8_000) { flag.asked }
            // Dismiss the system dialog with Back: not granted, never asked again.
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("input keyevent 4").close()
            assertTrue(flag.asked)
        }
    }
}
