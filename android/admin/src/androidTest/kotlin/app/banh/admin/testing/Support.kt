package app.banh.admin.testing

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.MainActivity
import app.banh.admin.ui.AdminTags
import java.io.File
import java.io.FileOutputStream

private const val WAIT_MILLIS = 8_000L

/** Starts the app against the stub backend with no stored session (debug launch extras of `BuildBackend`). */
fun launchStub(grantNotifications: Boolean = true): ActivityScenario<MainActivity> {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context = instrumentation.targetContext
    // The system question for notifications would cover the app after sign-in (FR-25); tests grant it first, unless they test the question.
    if (grantNotifications) instrumentation.uiAutomation.grantRuntimePermission(context.packageName, "android.permission.POST_NOTIFICATIONS")
    return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra("backend", "stub"))
}

/** Runs [block] with the app started against the stub, then closes the activity. Returns Unit, as JUnit needs of a test method. */
fun withStub(grantNotifications: Boolean = true, block: () -> Unit) {
    launchStub(grantNotifications).use { block() }
}

fun ComposeTestRule.waitForTag(tag: String, timeoutMillis: Long = WAIT_MILLIS): SemanticsNodeInteraction {
    waitUntil(timeoutMillis) { onAllNodesWithTagCount(tag) > 0 }
    return onNodeWithTag(tag, useUnmergedTree = true)
}

fun ComposeTestRule.waitUntilGone(tag: String, timeoutMillis: Long = WAIT_MILLIS) = waitUntil(timeoutMillis) { onAllNodesWithTagCount(tag) == 0 }

fun ComposeTestRule.has(tag: String): Boolean = onAllNodesWithTagCount(tag) > 0

private fun ComposeTestRule.onAllNodesWithTagCount(tag: String): Int =
    onAllNodes(androidx.compose.ui.test.hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().size

/** Signs in through the real screens; "owner" in the address signs in as the owner, anything else as staff. */
fun ComposeTestRule.signIn(email: String = "nhanvien.a@example.com") {
    waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput(email)
    onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
    waitForTag(AdminTags.CODE_FIELD).performTextInput("123456")
    onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
    waitForTag(AdminTags.ORDERS_LIST)
}

/** Signs in as the owner and opens the settings tab (S-A6). */
fun ComposeTestRule.signInOwner() {
    signIn("owner@example.com")
    waitForTag(AdminTags.TAB_SETTINGS).performClick()
    waitForTag(AdminTags.SETTINGS_ROW_CAKES)
}

/** Opens one of the five areas from S-A6 by the id of its row. */
fun ComposeTestRule.openArea(rowTag: String) {
    waitForTag(rowTag).performClick()
}

/** Taps the element with [tag] (scrolling to it first when it sits in a scrolling column). */
fun ComposeTestRule.tap(tag: String, scroll: Boolean = false) {
    val node = waitForTag(tag)
    if (scroll) node.performScrollTo()
    node.performClick()
}

/** Replaces the text of a field. */
fun ComposeTestRule.typeInto(tag: String, text: String) {
    val node = waitForTag(tag)
    node.performTextClearance()
    node.performTextInput(text)
}

/** Waits until the screen has stopped moving (toast fades, sheet animations end). */
fun ComposeTestRule.settle() {
    waitForIdle()
    Thread.sleep(SETTLE_MILLIS)
}

private const val SETTLE_MILLIS = 400L

/** Saves a screenshot to the app's external files directory (`adb pull` it afterwards); never into the repository. */
object Shots {
    fun take(name: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val bitmap = instrumentation.uiAutomation.takeScreenshot() ?: return
        val context: Context = instrumentation.targetContext
        val dir = File(context.getExternalFilesDir(null), "shots").apply { mkdirs() }
        FileOutputStream(File(dir, "$name.png")).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
