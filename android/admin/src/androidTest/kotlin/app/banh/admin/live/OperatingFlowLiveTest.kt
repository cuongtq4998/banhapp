package app.banh.admin.live

import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import app.banh.admin.testing.has
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Rule
import org.junit.Test
import org.junit.runners.MethodSorters

private const val CUSTOMER_NAME = "Nguyễn Văn An"
private const val CUSTOMER_ADDRESS = "12 Đường Hoa Sen, phường 5"
private const val OWNER = "owner.and@example.com"
private const val STAFF = "staff.and@example.com"

/**
 * The admin half of the shop's operating flow against a real backend, no stub (steps 2 to 8 of the scenario). The customer half is
 * `app.banh.customer.live.OperatingFlowLiveTest`; `android/e2e/run-operating-flow.sh` runs the methods in the order of their names
 * (one `am instrument` call each, so the stored session carries over). Skipped unless the argument `e2eLive=true` is given.
 */
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class OperatingFlowLiveTest {
    @get:Rule val rule = createEmptyComposeRule()

    @Before fun onlyWhenLive() = LiveSupport.assumeLive()

    private val code1 get() = LiveSupport.state("code1")
    private val code2 get() = LiveSupport.state("code2")
    private val date get() = LiveSupport.state("date")

    /** Opens one settings area from a signed-in owner session on the order list. */
    private fun openArea(row: String) {
        rule.tap(AdminTags.TAB_SETTINGS)
        rule.tap(row)
    }

    @Test
    fun step2a_ownerSignsInByMailCodeAndSeesBothNewOrdersFirst() {
        // A first run signs in; a repeat of this method after a failure keeps the stored session (3 code requests an hour per address).
        launchLive().use {
            rule.waitUntil(10_000) { rule.has(AdminTags.SIGNIN_EMAIL) || rule.has(AdminTags.ORDERS_LIST) }
            if (rule.has(AdminTags.SIGNIN_EMAIL)) rule.signInWithMailCode(OWNER, "08")
            rule.waitForTag(AdminTags.ORDERS_LIST)
            LiveSupport.note("09-tidy", LiveHelpers.cancelOrdersOfEarlierRuns(code1, code2))
        }
        // Opened again so that the list is read after the tidy-up.
        launchLive().use {
            rule.assertTodoShowsBothFirst(code1, code2)
        }
    }

    @Test
    fun step2b_ownerChecksOrder1AgainstWhatTheCustomerTypedAndConfirmsIt() {
        launchLive().use {
            rule.openOrder(code1)
            rule.snap("11-admin-order1-detail")
            rule.assertOrderDetailIs(CUSTOMER_NAME, LiveSupport.state("phone"), CUSTOMER_ADDRESS, LiveSupport.state("total1"))
            rule.tap(AdminTags.DETAIL_CONFIRM)
            rule.waitForTag(AdminTags.TOAST)
            rule.waitForTag(AdminTags.DETAIL_COMPLETE)
            rule.snap("12-admin-order1-confirmed")
            rule.tap(AdminTags.NAV_BACK)
            rule.tap(AdminTags.FILTER_CONFIRMED)
            rule.waitForTag(AdminTags.orderRow(code1))
            assertFalse(rule.has(AdminTags.orderRow(code2)))
            rule.snap("13-admin-chip-confirmed-lists-order1")
        }
    }

    @Test
    fun step3_ownerCancelsOrder2AsSpamAndThePerPhoneCountStillIncludesIt() {
        launchLive().use {
            rule.tap(AdminTags.FILTER_TODO)
            rule.openOrder(code2)
            rule.tap(AdminTags.DETAIL_CANCEL)
            rule.tap(AdminTags.REASON_SPAM)
            rule.snap("14-admin-cancel-sheet-spam")
            rule.tap(AdminTags.CANCEL_CONFIRM)
            rule.waitForTag(AdminTags.DETAIL_REASON)
            assertTrue(rule.textOf(AdminTags.DETAIL_REASON).contains("Đơn giả hoặc spam"))
            rule.snap("15-admin-order2-cancelled-spam")
            LiveSupport.note("16-per-phone-count", LiveHelpers.perPhoneCount())
        }
    }

    @Test
    fun step4_ownerCompletesOrder1() {
        launchLive().use {
            rule.tap(AdminTags.FILTER_CONFIRMED)
            rule.openOrder(code1)
            rule.tap(AdminTags.DETAIL_COMPLETE)
            rule.snap("17-admin-complete-question")
            rule.tap(AdminTags.DETAIL_COMPLETE_YES)
            rule.waitUntilGone(AdminTags.DETAIL_COMPLETE)
            rule.tap(AdminTags.NAV_BACK)
            rule.tap(AdminTags.FILTER_COMPLETED)
            rule.waitForTag(AdminTags.orderRow(code1))
            rule.snap("18-admin-completed-lists-order1")
        }
    }

    @Test
    fun step5a_ownerLowersTheDailyLimitAndTheImpactPreviewListsTheDate() {
        launchLive().use {
            val original = LiveSupport.call("GET", "/v1/owner/settings/ordering", LiveSupport.appToken()).json().getInt("daily_limit")
            LiveSupport.saveState(mapOf("limit0" to original.toString()))
            openArea(AdminTags.SETTINGS_ROW_RULES)
            rule.typeInto(AdminTags.RULES_LIMIT, "2")
            rule.snap("19-admin-rules-limit-typed")
            rule.tap(AdminTags.RULES_SAVE)
            rule.waitForTag(AdminTags.RULES_WARN_DIALOG)
            val shortDate = "${date.substring(8, 10)}/${date.substring(5, 7)}"
            assertTrue("preview lists $shortDate: ${rule.textOf(AdminTags.RULES_WARN_DIALOG)}", rule.textOf(AdminTags.RULES_WARN_DIALOG).contains(shortDate))
            rule.snap("20-admin-rules-impact-preview")
            rule.tap(AdminTags.RULES_WARN_CONFIRM)
            if (rule.has(AdminTags.RULES_WARN_DIALOG)) rule.tap(AdminTags.RULES_WARN_CONFIRM)
            rule.waitUntilGone(AdminTags.RULES_LIMIT)
            assertEquals(2, LiveSupport.call("GET", "/v1/owner/settings/ordering", LiveSupport.appToken()).json().getInt("daily_limit"))
            rule.snap("20b-admin-rules-saved")
        }
    }

    @Test
    fun step5b_ownerRestoresTheLimit() {
        launchLive().use {
            openArea(AdminTags.SETTINGS_ROW_RULES)
            rule.typeInto(AdminTags.RULES_LIMIT, LiveSupport.state("limit0"))
            rule.tap(AdminTags.RULES_SAVE)
            rule.waitUntilGone(AdminTags.RULES_LIMIT)
            assertEquals(LiveSupport.state("limit0").toInt(), LiveSupport.call("GET", "/v1/owner/settings/ordering", LiveSupport.appToken()).json().getInt("daily_limit"))
            rule.snap("22-admin-rules-restored")
        }
    }

    @Test
    fun step6a_ownerFillsTheCakeFormAndTheCakeIsAddedByHelperUpload() {
        val name = LiveSupport.arg("e2eCake", "Banh_E2E_Cam").replace("_", " ")
        LiveSupport.note("24a-tidy", LiveHelpers.removeCakesOfEarlierRuns(name))
        launchLive().use {
            openArea(AdminTags.SETTINGS_ROW_CAKES)
            rule.tap(AdminTags.CAKES_ADD)
            rule.fillCakeForm(name)
            rule.snap("24-admin-cake-form-filled-no-photo")
            // The system photo picker cannot be driven reliably: the upload is a multipart POST with the owner's token.
            val created = LiveSupport.createCake(LiveSupport.appToken(), name, 120000)
            assertEquals(created.body, 201, created.status)
            LiveSupport.saveState(mapOf("cakeId" to created.json().getString("cake_id")))
            LiveSupport.note("24b-helper-upload", "POST /v1/owner/cakes -> ${created.status} ${created.body}")
            rule.tap(AdminTags.NAV_BACK)
            if (rule.has(AdminTags.DISCARD_CONFIRM)) rule.tap(AdminTags.DISCARD_CONFIRM)
            rule.waitForTag(AdminTags.CAKES_ADD)
        }
        // The app does not poll: a change made from another phone shows when the app is opened again (found by this flow, listed as an observation).
        launchLive().use {
            openArea(AdminTags.SETTINGS_ROW_CAKES)
            rule.waitForTag(AdminTags.cakeRow(LiveSupport.state("cakeId")))
            Thread.sleep(1500)
            rule.snap("25-admin-cakes-list-shows-new-cake")
        }
    }

    @Test
    fun step6b_ownerHidesTheCake() {
        launchLive().use {
            openArea(AdminTags.SETTINGS_ROW_CAKES)
            rule.tap(AdminTags.cakeRow(LiveSupport.state("cakeId")))
            // The switch is below the fold and the form's scroll action is not reachable by tag: swipe the form up.
            rule.waitForTag(AdminTags.CAKE_FORM_NAME).performTouchInput { swipeUp() }
            rule.tap(AdminTags.CAKE_FORM_ACTIVE)
            rule.snap("27-admin-cake-form-hidden-switch")
            rule.tap(AdminTags.CAKE_FORM_SAVE)
            rule.waitForTag(AdminTags.CAKES_ADD)
            val cakes = LiveSupport.call("GET", "/v1/owner/settings", LiveSupport.appToken()).json().getJSONArray("cakes")
            val mine = (0 until cakes.length()).map { cakes.getJSONObject(it) }.first { it.getString("cake_id").equals(LiveSupport.state("cakeId"), true) }
            assertFalse(mine.getBoolean("is_active"))
            rule.snap("27b-admin-cakes-list-cake-hidden")
        }
    }

    @Test
    fun step7_ownerAddsStaffSignsOutStaffWorksThenIsDeactivated() = StaffFlow(rule).run(OWNER, STAFF)

    @Test
    fun step8_logAudit() = LogAudit.run(CUSTOMER_NAME, CUSTOMER_ADDRESS)
}
