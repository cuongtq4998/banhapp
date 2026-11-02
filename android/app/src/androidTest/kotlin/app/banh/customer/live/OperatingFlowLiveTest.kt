package app.banh.customer.live

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import app.banh.customer.MainActivity
import app.banh.customer.TestTags
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Rule
import org.junit.Test
import org.junit.runners.MethodSorters

private const val WAIT_MILLIS = 20_000L
private const val CAKES_TOTAL = 3
private const val SETTLE_MILLIS = 900L

/**
 * The customer half of the shop's operating flow against a real backend (steps 1, 5 and 6 of the scenario). The admin half is
 * `app.banh.admin.live.OperatingFlowLiveTest`; the driver `android/e2e/run-operating-flow.sh` runs the methods in the order of
 * their names, interleaved with the admin ones. Skipped unless the argument `e2eLive=true` is given.
 */
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class OperatingFlowLiveTest {
    @get:Rule val rule = createAndroidComposeRule<MainActivity>()

    @Before fun onlyWhenLive() = LiveSupport.assumeLive()

    // The tag can be found while the previous screen is still fading out; settle before taking a picture.
    private fun snap(name: String) {
        rule.waitForIdle()
        Thread.sleep(SETTLE_MILLIS)
        LiveSupport.shot(name)
    }

    private fun count(tag: String) = rule.onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().size

    private fun awaitTag(tag: String) = rule.waitUntil(WAIT_MILLIS) { count(tag) > 0 }

    private fun tap(tag: String) {
        awaitTag(tag)
        scrollIfPossible(tag)
        rule.onNodeWithTag(tag).performClick()
    }

    // Not every screen scrolls (Home does not), and performScrollTo fails there.
    private fun scrollIfPossible(tag: String) {
        runCatching { rule.onNodeWithTag(tag).performScrollTo() }
    }

    private fun textOf(tag: String): String =
        rule.onNodeWithTag(tag, useUnmergedTree = true).fetchSemanticsNode().config.getOrNull(SemanticsProperties.Text)?.joinToString("") { it.text } ?: ""

    private fun catalog() = LiveSupport.getJson("/v1/catalog")

    private fun firstAvailableDate() = LiveSupport.firstAvailableDate(CAKES_TOTAL)

    // The draft of an earlier (failed) run may be restored with its quantities, so each count is brought to the wanted number.
    private fun chooseCakes(firstCount: Int = 2) {
        val products = catalog().getJSONArray("products")
        val wanted = listOf(firstCount, 1)
        wanted.forEachIndexed { index, count ->
            val id = products.getJSONObject(index).getString("product_id")
            awaitTag(TestTags.orderQtyValue(id))
            var now = textOf(TestTags.orderQtyValue(id)).trim().toInt()
            while (now < count) { tap(TestTags.orderQtyIncrease(id)); now++ }
            while (now > count) { tap(TestTags.orderQtyDecrease(id)); now-- }
        }
    }

    private fun openOrder() {
        tap(TestTags.HOME_ORDER)
        awaitTag(TestTags.ORDER_NEXT)
    }

    private fun fill(tag: String, text: String) {
        awaitTag(tag)
        scrollIfPossible(tag)
        rule.onNodeWithTag(tag).performTextClearance()
        rule.onNodeWithTag(tag).performTextInput(text)
    }

    /** Walks S-5 to S-9 and returns the order code and the total shown on the review. */
    private fun placeOrder(name: String, address: String, prefix: String, date: String): Pair<String, String> {
        val catalog = catalog()
        openOrder()
        chooseCakes()
        snap("${prefix}a-customer-cakes")
        tap(TestTags.ORDER_NEXT)
        tap(TestTags.orderDate(date))
        tap(TestTags.orderSlot(catalog.getJSONArray("slots").getJSONObject(0).getString("slot_id")))
        snap("${prefix}b-customer-date-slot")
        tap(TestTags.ORDER_NEXT)
        fill(TestTags.ORDER_FIELD_NAME, name)
        fill(TestTags.ORDER_FIELD_PHONE, LiveSupport.phone)
        fill(TestTags.ORDER_FIELD_ADDRESS, address)
        tap(TestTags.ORDER_FIELD_DISTRICT)
        tap(TestTags.orderDistrictRow(catalog.getJSONArray("districts").getJSONObject(0).getString("district_id")))
        snap("${prefix}c-customer-recipient")
        tap(TestTags.ORDER_NEXT)
        awaitTag(TestTags.REVIEW_TOTAL)
        val total = textOf(TestTags.REVIEW_TOTAL)
        snap("${prefix}d-customer-review")
        tap(TestTags.REVIEW_CONFIRM)
        awaitTag(TestTags.CONF_CODE)
        val code = textOf(TestTags.CONF_CODE)
        snap("${prefix}e-customer-confirmation")
        assertTrue("order code looks like BT-XXXXXX: $code", Regex("^BT-[2-9A-HJKMNP-Z]{6}$").matches(code))
        tap(TestTags.CONF_HOME)
        return code to total
    }

    // Step 1: two orders for the same phone, the second one under the name "Spam Test".
    @Test
    fun step1_customerPlacesTwoOrders() {
        val date = firstAvailableDate()
        val (code1, total1) = placeOrder("Nguyễn Văn An", "12 Đường Hoa Sen, phường 5", "01", date)
        val (code2, total2) = placeOrder("Spam Test", "99 Đường Giả, phường 1", "02", date)
        LiveSupport.saveState(mapOf("date" to date, "code1" to code1, "total1" to total1, "code2" to code2, "total2" to total2, "phone" to LiveSupport.phone))
    }

    // Two cakes (the minimum): the order of step 1 has 3 on its date, so with the limit at 2 only that date is full, the others stay open.
    private fun openDateStep() {
        openOrder()
        chooseCakes(firstCount = 1)
        tap(TestTags.ORDER_NEXT)
        awaitTag(TestTags.ORDER_DATE_MONTH)
        // While the answer is loading every day is off; judge the calendar only after it arrived.
        rule.waitUntil(WAIT_MILLIS) { count(TestTags.ORDER_DATE_LOADING) == 0 }
    }

    private fun dateEnabled(date: String): Boolean {
        awaitTag(TestTags.orderDate(date))
        return runCatching { rule.onNodeWithTag(TestTags.orderDate(date)).assertIsEnabled() }.isSuccess
    }

    // Step 5: with the daily limit lowered, the date of order 1 is shown as full (a cell that cannot be tapped).
    @Test
    fun step5a_dateStepShowsTheDateFull() {
        val date = LiveSupport.state("date")
        openDateStep()
        rule.waitUntil(WAIT_MILLIS) { !dateEnabled(date) }
        rule.onNodeWithTag(TestTags.orderDate(date)).assertIsNotEnabled()
        val other = java.time.LocalDate.parse(date).plusDays(1).toString()
        snap("21-customer-date-full")
        assertTrue("$other is still open for a 2-cake order", dateEnabled(other))
        snap("21-customer-date-full")
        assertEquals(false, LiveSupport.getJson("/v1/availability?cakes=2").getJSONArray("dates").let { d ->
            (0 until d.length()).map { d.getJSONObject(it) }.first { it.getString("date") == date }.getBoolean("available")
        })
    }

    // After the owner restored the limit, the same date can be chosen again.
    @Test
    fun step5b_dateIsAvailableAgainAfterTheLimitIsRestored() {
        val date = LiveSupport.state("date")
        openDateStep()
        rule.waitUntil(WAIT_MILLIS) { dateEnabled(date) }
        snap("23-customer-date-available-again")
    }

    private fun openCatalog() {
        tap(TestTags.HOME_PRODUCTS)
        awaitTag(TestTags.PRODUCTS_LIST)
    }

    // Step 6: the cake the owner added is in the customer catalog.
    @Test
    fun step6a_newCakeIsInTheCustomerCatalog() {
        val name = LiveSupport.arg("e2eCake", "Banh_E2E_Cam").replace("_", " ")
        openCatalog()
        rule.waitUntil(WAIT_MILLIS) { rule.onAllNodes(hasText(name), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithTag(TestTags.PRODUCTS_LIST).performScrollToNode(hasText(name))
        rule.waitForIdle()
        Thread.sleep(1500) // let the picture load before the screenshot
        snap("26-customer-catalog-shows-new-cake")
    }

    // Step 6 (hide): after the owner hid it, the customer catalog no longer lists it.
    @Test
    fun step6b_hiddenCakeIsGoneFromTheCustomerCatalog() {
        val name = LiveSupport.arg("e2eCake", "Banh_E2E_Cam").replace("_", " ")
        openCatalog()
        rule.waitUntil(WAIT_MILLIS) { rule.onAllNodes(hasText(name), useUnmergedTree = true).fetchSemanticsNodes().isEmpty() }
        Thread.sleep(1000)
        snap("28-customer-catalog-without-hidden-cake")
    }
}
