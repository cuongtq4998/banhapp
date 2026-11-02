package app.banh.admin.live

import androidx.compose.ui.test.junit4.ComposeTestRule
import app.banh.admin.testing.has
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue

/** Step 7 of the scenario: the owner adds a staff member and signs out, the staff member works, the owner deactivates the account, the staff app's next action ends the session. */
class StaffFlow(private val rule: ComposeTestRule) {
    fun run(owner: String, staff: String) {
        val code1 = LiveSupport.state("code1")
        launchLive().use {
            rule.waitUntil(10_000) { rule.has(AdminTags.TAB_SETTINGS) || rule.has(AdminTags.ORDERS_TITLE) || rule.has(AdminTags.SIGNIN_EMAIL) }
            // A repeat after a failure at the staff part finds the staff member still signed in on the phone: carry on from there.
            val staffAlreadyIn = !rule.has(AdminTags.TAB_SETTINGS) && rule.has(AdminTags.ORDERS_TITLE)
            if (!staffAlreadyIn) {
                addStaff(staff)
                signOutOwner()
                rule.signInWithMailCode(staff, "31")
            }
            assertFalse("staff has no tab bar", rule.has(AdminTags.TAB_ORDERS) || rule.has(AdminTags.TAB_SETTINGS))
            rule.snap("32-staff-orders-no-tab-bar")
            rule.tap(AdminTags.FILTER_ALL)
            rule.snap("32b-staff-all-orders")
            rule.tap(AdminTags.FILTER_COMPLETED)
            rule.openOrder(code1)
            rule.snap("33-staff-order-detail")
            deactivateByTheOwnerElsewhere(owner, staff)
            // The staff phone's next action: back to the list, which loads again, and a change of the status chip.
            rule.tap(AdminTags.NAV_BACK)
            rule.tap(AdminTags.FILTER_CONFIRMED)
            rule.waitForTag(AdminTags.SIGNIN_EMAIL, 15_000)
            rule.waitForTag(AdminTags.SIGNIN_BANNER)
            LiveSupport.note("34-session-ended-message", rule.textOf(AdminTags.SIGNIN_BANNER))
            rule.snap("34-staff-session-ended-sign-in")
        }
    }

    private fun addStaff(email: String) {
        rule.tap(AdminTags.TAB_SETTINGS)
        rule.tap(AdminTags.SETTINGS_ROW_STAFF)
        val existing = existingStaff(email)
        if (existing != null) {
            // An earlier run left the account (deactivated at its end): the owner switches it on again instead of adding it.
            rule.tap(AdminTags.staffRow(existing.first))
            if (rule.has(AdminTags.STAFF_REACTIVATE)) {
                rule.snap("28-admin-staff-reactivate-sheet")
                rule.tap(AdminTags.STAFF_REACTIVATE)
                rule.waitUntilGone(AdminTags.STAFF_REACTIVATE)
            } else {
                rule.tap(AdminTags.NAV_BACK)
            }
            rule.snap("29-admin-staff-list-with-staff")
            rule.tap(AdminTags.NAV_BACK)
            return
        }
        rule.tap(AdminTags.STAFF_ADD)
        rule.typeInto(AdminTags.STAFF_ADD_NAME, "Nhân Viên E2E")
        rule.typeInto(AdminTags.STAFF_ADD_EMAIL, email)
        rule.snap("28-admin-staff-add-form")
        rule.tap(AdminTags.STAFF_ADD_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.STAFF_ADD_SAVE)
        rule.snap("29-admin-staff-list-with-new-staff")
        rule.tap(AdminTags.NAV_BACK)
    }

    /** Account id and active flag of [email], read with the phone's own owner session; null when it does not exist. */
    private fun existingStaff(email: String): Pair<String, Boolean>? {
        val accounts = LiveSupport.call("GET", "/v1/owner/staff", LiveSupport.appToken()).json().getJSONArray("accounts")
        return (0 until accounts.length()).map { accounts.getJSONObject(it) }.firstOrNull { it.getString("email") == email }
            ?.let { it.getString("account_id") to it.getBoolean("is_active") }
    }

    private fun signOutOwner() {
        rule.tap(AdminTags.SETTINGS_SIGN_OUT, scroll = true)
        rule.snap("30a-admin-owner-sign-out-question")
        rule.tap(AdminTags.SETTINGS_SIGN_OUT_YES)
        rule.waitForTag(AdminTags.SIGNIN_EMAIL)
        rule.snap("30-admin-owner-signed-out")
    }

    // The owner is signed out on this phone, so the deactivation is made from a second owner session (another phone) by the API.
    private fun deactivateByTheOwnerElsewhere(owner: String, staff: String) {
        val (token, _) = LiveSupport.signInByHttp(owner)
        val accounts = LiveSupport.call("GET", "/v1/owner/staff", token).json().getJSONArray("accounts")
        val id = (0 until accounts.length()).map { accounts.getJSONObject(it) }.first { it.getString("email") == staff }.getString("account_id")
        val patch = LiveSupport.call("PATCH", "/v1/owner/staff/$id", token, """{"is_active":false}""")
        LiveSupport.note("34a-deactivate-staff", "PATCH /v1/owner/staff/$id is_active=false -> ${patch.status} ${patch.body}")
        assertEquals(patch.body, 200, patch.status)
        assertFalse(patch.json().getBoolean("is_active"))
        val out = LiveSupport.call("DELETE", "/v1/admin/session", token)
        assertTrue("helper session sign-out: ${out.status}", out.status == 204)
    }
}
