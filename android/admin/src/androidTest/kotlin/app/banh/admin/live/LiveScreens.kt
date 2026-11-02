package app.banh.admin.live

import android.content.Intent
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.MainActivity
import app.banh.admin.testing.has
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.ui.AdminOrderTags
import app.banh.admin.ui.AdminTags

/** Starts the real app (local backend). [fresh] forgets any stored session first; otherwise the stored session is restored. */
fun launchLive(fresh: Boolean = false): ActivityScenario<MainActivity> {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context = instrumentation.targetContext
    instrumentation.uiAutomation.grantRuntimePermission(context.packageName, "android.permission.POST_NOTIFICATIONS")
    val intent = Intent(context, MainActivity::class.java)
    if (fresh) intent.putExtra("backend", "local").putExtra("reset", true)
    return ActivityScenario.launch(intent)
}

/** Text shown at the node tagged [tag] (all its text pieces joined, also from the parts of a merged node). */
fun ComposeTestRule.textOf(tag: String): String {
    val node = onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().first()
    val own = node.config.getOrNull(SemanticsProperties.Text)?.joinToString(" ") { it.text }
    if (own != null) return own
    return onAllNodes(androidx.compose.ui.test.hasAnyAncestor(hasTestTag(tag)), useUnmergedTree = true).fetchSemanticsNodes()
        .mapNotNull { it.config.getOrNull(SemanticsProperties.Text)?.joinToString(" ") { t -> t.text } }.joinToString(" | ")
}

/** Settles the screen, then saves the picture. */
fun ComposeTestRule.snap(name: String) {
    waitForIdle()
    Thread.sleep(900)
    LiveSupport.shot(name)
}

/** Types the e-mail, asks for the code, reads it from the console mail log and signs in; returns when the order list shows. */
fun ComposeTestRule.signInWithMailCode(email: String, shotPrefix: String) {
    waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput(email)
    snap("${shotPrefix}a-signin-email")
    val before = LiveSupport.codeCount()
    tap(AdminTags.SIGNIN_SEND)
    val code = LiveSupport.codeAfter(before)
    waitForTag(AdminTags.CODE_FIELD).performTextInput(code)
    snap("${shotPrefix}b-signin-code")
    tap(AdminTags.CODE_SUBMIT)
    // The default To-do list can be empty (no open orders); the title is on both.
    waitForTag(AdminTags.ORDERS_TITLE)
}

/** Vertical positions of the order rows that are on the screen, top first: code to top edge. */
fun ComposeTestRule.rowOrder(): List<String> =
    onAllNodes(androidx.compose.ui.test.SemanticsMatcher("order row") { it.config.getOrNull(SemanticsProperties.TestTag)?.startsWith("admin.orders.row.") == true }, useUnmergedTree = true)
        .fetchSemanticsNodes().sortedBy { it.boundsInWindow.top }.map { it.config[SemanticsProperties.TestTag].removePrefix("admin.orders.row.") }

fun ComposeTestRule.openOrder(code: String) {
    tap(AdminOrderTags.orderRow(code))
    waitForTag(AdminOrderTags.DETAIL_CUSTOMER)
}

/** Waits until [tag] is visible with text that contains [part]. */
fun ComposeTestRule.waitText(tag: String, part: String) = waitUntil(20_000) { has(tag) && textOf(tag).contains(part) }

/** The open detail shows what the customer typed: name, phone (E.164 of the same digits), address, the two cakes and the total (digits only, as shown on the review). */
fun ComposeTestRule.assertOrderDetailIs(name: String, phone: String, address: String, totalDigits: String) {
    org.junit.Assert.assertEquals(name, textOf(AdminOrderTags.DETAIL_CUSTOMER))
    val shown = textOf(AdminOrderTags.DETAIL_PHONE).replace(" ", "")
    org.junit.Assert.assertTrue("phone $shown", shown.endsWith(phone.drop(1)))
    org.junit.Assert.assertTrue(textOf(AdminOrderTags.DETAIL_ADDRESS).contains(address))
    org.junit.Assert.assertTrue(textOf(AdminOrderTags.detailCake(0)).contains("2 × Bánh chuối"))
    org.junit.Assert.assertTrue(textOf(AdminOrderTags.detailCake(1)).contains("1 × Bánh đậu xanh nhân mỡ"))
    org.junit.Assert.assertEquals(totalDigits, textOf(AdminOrderTags.DETAIL_TOTAL).filter { it.isDigit() }.takeLast(totalDigits.length))
}

fun ComposeTestRule.fillCakeForm(name: String) {
    typeInto(AdminTags.CAKE_FORM_NAME, name)
    typeInto(AdminTags.CAKE_FORM_DESC, "Bánh thử nghiệm vận hành")
    typeInto(AdminTags.CAKE_FORM_PRICE, "120000")
}

/** To-do lists both orders as its first two rows; the badge is shown exactly when the server counts due orders (see the note written). */
fun ComposeTestRule.assertTodoShowsBothFirst(code1: String, code2: String) {
    waitForTag(AdminOrderTags.orderRow(code1))
    waitForTag(AdminOrderTags.orderRow(code2))
    // The red badge counts only orders due today or overdue (api 10.9 `unfinished_count`, FR-13); a new order is for a date at least
    // lead_days ahead, so the badge is expected to be absent here. The owner has the tab bar, so it would sit on the Orders tab.
    val unfinished = LiveSupport.call("GET", "/v1/admin/orders", LiveSupport.appToken()).json().getInt("unfinished_count")
    org.junit.Assert.assertEquals("badge shown exactly when the server counts due orders", unfinished > 0, has(AdminTags.TAB_ORDERS_BADGE))
    val order = rowOrder()
    LiveSupport.note("10-todo-row-order", "rows top to bottom: $order\nserver unfinished_count: $unfinished (badge counts only orders due today or overdue)")
    snap("10-admin-todo-two-orders")
    org.junit.Assert.assertEquals("both new orders are the first two rows of To-do: $order", setOf(code1, code2), order.take(2).toSet())
}
