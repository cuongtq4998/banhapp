package app.banh.admin.testing

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.MainActivity
import app.banh.admin.ui.AdminTags
import java.io.File
import java.io.FileOutputStream

private const val WAIT_MILLIS = 8_000L

/** Starts the app against the stub backend with no stored session (debug launch extras of `BuildBackend`). */
fun launchStub(): ActivityScenario<MainActivity> {
    val context = InstrumentationRegistry.getInstrumentation().targetContext
    return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra("backend", "stub"))
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
