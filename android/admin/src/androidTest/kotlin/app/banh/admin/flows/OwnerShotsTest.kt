package app.banh.admin.flows

import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.AdminApplication
import app.banh.admin.push.PushMessage
import app.banh.admin.testing.Shots
import app.banh.admin.testing.openArea
import app.banh.admin.testing.settle
import app.banh.admin.testing.signIn
import app.banh.admin.testing.signInOwner
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.testing.withStub
import app.banh.admin.ui.AdminTags
import org.junit.Rule
import org.junit.Test

private const val CAKE = "5b0c2f6a-0000-4a00-8000-0000000000c1"
private const val HIDDEN = "5b0c2f6a-0000-4a00-8000-0000000000c3"
private const val STAFF = "5b0c2f6a-0000-4a00-8000-0000000000a2"

/** Screenshots of every state of the owner screens (saved outside the repository, see `Shots`). Part 1 of the tour: settings, cakes, rules, shop. */
class OwnerShotsTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun shot(name: String) {
        rule.settle()
        Shots.take(name)
    }

    private fun pickPicture() {
        rule.tap(AdminTags.CAKE_FORM_IMAGE)
        rule.waitForTag(AdminTags.CAKE_FORM_CHANGE)
    }

    @Test
    fun cakes() = withStub {
        rule.signInOwner(); shot("a-settings")
        rule.openArea(AdminTags.SETTINGS_ROW_CAKES)
        rule.waitForTag(AdminTags.CAKES_ADD); shot("b-cakes-list")
        rule.tap(AdminTags.CAKES_ADD); shot("c-cake-add-empty")
        rule.typeInto(AdminTags.CAKE_FORM_DESC, "Banh ngon")
        rule.tap(AdminTags.CAKE_FORM_SAVE); rule.waitForTag(AdminTags.cakeFormError("name")); shot("d-cake-add-errors-all-at-once")
        pickPicture()
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "banh mau"); rule.typeInto(AdminTags.CAKE_FORM_DESC, "Banh ngon"); rule.typeInto(AdminTags.CAKE_FORM_PRICE, "150000")
        shot("e-cake-add-filled")
        rule.tap(AdminTags.CAKE_FORM_SAVE); rule.waitForTag(AdminTags.cakeFormError("name")); shot("f-cake-add-name-taken")
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "Full Cake")
        rule.tap(AdminTags.CAKE_FORM_SAVE); rule.waitForTag(AdminTags.OWNER_SAVE_ERROR); shot("g-cake-add-limit-reached")
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "Slow Cake")
        rule.tap(AdminTags.CAKE_FORM_SAVE); rule.waitForTag(AdminTags.CAKE_FORM_PROGRESS); shot("h-cake-uploading")
        rule.tap(AdminTags.CAKE_FORM_CANCEL); rule.waitUntilGone(AdminTags.CAKE_FORM_PROGRESS)
        rule.tap(AdminTags.NAV_BACK); rule.tap(AdminTags.DISCARD_CONFIRM); rule.waitForTag(AdminTags.CAKES_ADD)
        rule.tap(AdminTags.cakeRow(CAKE)); rule.waitForTag(AdminTags.CAKE_FORM_REMOVE); shot("j-cake-edit-active")
        rule.tap(AdminTags.CAKE_FORM_ACTIVE, scroll = true); rule.waitForTag(AdminTags.TOAST); shot("k-cake-last-active-toast")
        rule.tap(AdminTags.NAV_BACK)
        rule.tap(AdminTags.cakeRow(HIDDEN)); rule.waitForTag(AdminTags.CAKE_FORM_REMOVE); shot("l-cake-edit-hidden")
        rule.tap(AdminTags.CAKE_FORM_REMOVE, scroll = true); rule.waitForTag(AdminTags.CAKE_FORM_REMOVE_YES); shot("m-cake-remove-dialog")
        rule.tap(AdminTags.CAKE_FORM_REMOVE_YES); rule.waitForTag(AdminTags.TOAST); shot("n-cakes-list-removed-toast")
        rule.tap(AdminTags.CAKES_ADD); pickPicture()
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "Banh Moi"); rule.typeInto(AdminTags.CAKE_FORM_DESC, "Banh ngon"); rule.typeInto(AdminTags.CAKE_FORM_PRICE, "150000")
        rule.tap(AdminTags.CAKE_FORM_SAVE); rule.waitForTag(AdminTags.TOAST); shot("i-cakes-list-added-toast")
    }

    @Test
    fun rulesAndShop() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_RULES); rule.waitForTag(AdminTags.RULES_LIMIT); shot("o-rules-default")
        rule.typeInto(AdminTags.RULES_LIMIT, "10"); rule.typeInto(AdminTags.RULES_MIN, "15"); rule.typeInto(AdminTags.RULES_LEAD, "20")
        rule.tap(AdminTags.RULES_SAVE); rule.waitForTag(AdminTags.rulesError("min")); shot("p-rules-errors")
        rule.typeInto(AdminTags.RULES_LIMIT, "40"); rule.typeInto(AdminTags.RULES_MIN, "2"); rule.typeInto(AdminTags.RULES_LEAD, "2")
        rule.tap(AdminTags.RULES_SAVE); rule.waitForTag(AdminTags.RULES_WARN_DIALOG); shot("q-rules-limit-warning")
        rule.tap(AdminTags.RULES_WARN_CONFIRM); rule.waitForTag(AdminTags.TOAST); shot("r-settings-after-save")
        rule.openArea(AdminTags.SETTINGS_ROW_SHOP); rule.waitForTag(AdminTags.SHOP_NAME); shot("s-shop-default")
        rule.typeInto(AdminTags.SHOP_NAME, ""); rule.typeInto(AdminTags.SHOP_PHONE, "abc"); rule.typeInto(AdminTags.SHOP_ZALO, "ab")
        rule.tap(AdminTags.SHOP_SAVE); rule.waitForTag(AdminTags.shopError("phone")); shot("t-shop-errors")
        rule.tap(AdminTags.NAV_BACK); rule.waitForTag(AdminTags.DISCARD_CONFIRM); shot("u-discard-dialog")
    }

    @Test
    fun deliveryAndStaff() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_DELIVERY); rule.waitForTag(AdminTags.DISTRICT_ADD); shot("v-delivery-list")
        rule.tap(AdminTags.districtToggle("5b0c2f6a-0000-4a00-8000-0000000000d1")); rule.waitForTag(AdminTags.TOAST); shot("w-delivery-last-district-toast")
        rule.waitUntilGone(AdminTags.TOAST)
        rule.tap(AdminTags.DISTRICT_ADD); rule.typeInto(AdminTags.DISTRICT_NAME, "Quan Moi"); rule.typeInto(AdminTags.DISTRICT_FEE, "0")
        rule.tap(AdminTags.DISTRICT_SAVE); rule.waitForTag(AdminTags.DISTRICT_FEE_ERROR); shot("x-district-sheet-error")
        rule.typeInto(AdminTags.DISTRICT_FEE, "25000"); rule.tap(AdminTags.DISTRICT_SAVE); rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.DISTRICT_SAVE)
        rule.tap(AdminTags.SLOT_ADD); rule.tap(AdminTags.SLOT_START); rule.waitForTag("${AdminTags.SLOT_START}.ok"); shot("y-slot-time-picker")
        rule.tap("${AdminTags.SLOT_START}.ok"); shot("z-slot-sheet")
        rule.tap(AdminTags.SLOT_SAVE); rule.waitForTag(AdminTags.TOAST); rule.waitUntilGone(AdminTags.SLOT_SAVE)
        rule.tap(AdminTags.SLOT_ADD); rule.tap(AdminTags.SLOT_SAVE); rule.waitForTag(AdminTags.DELIVERY_ERROR); shot("za-slot-duplicate")
        rule.tap(AdminTags.NAV_BACK)
    }

    @Test
    fun staffAndPush() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_STAFF); rule.waitForTag(AdminTags.STAFF_ADD); shot("zb-staff-list")
        rule.tap(AdminTags.STAFF_ADD); rule.typeInto(AdminTags.STAFF_ADD_NAME, "Nhan Vien B"); rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "taken@example.com")
        rule.tap(AdminTags.STAFF_ADD_SAVE); rule.waitForTag(AdminTags.staffAddError("email")); shot("zc-staff-add-email-taken")
        rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "full@example.com"); rule.tap(AdminTags.STAFF_ADD_SAVE); rule.waitForTag(AdminTags.staffAddError("banner")); shot("zd-staff-add-limit")
        rule.tap(AdminTags.STAFF_ADD_EMAIL); rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "b@example.com"); rule.tap(AdminTags.STAFF_ADD_SAVE); rule.waitForTag(AdminTags.TOAST); shot("ze-staff-added-toast")
        rule.waitUntilGone(AdminTags.STAFF_ADD_SAVE)
        rule.tap(AdminTags.staffRow(STAFF)); rule.waitForTag(AdminTags.STAFF_DEACTIVATE); shot("zf-staff-detail")
        rule.tap(AdminTags.STAFF_DEACTIVATE); rule.waitForTag(AdminTags.STAFF_DEACTIVATE_YES); shot("zg-staff-deactivate-dialog")
    }

    @Test
    fun staffPushToastAndPart1Fixes() = withStub {
        rule.signIn()
        val push = (InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as AdminApplication).container.push
        push.deliver(PushMessage("BT-7K3M9Q", "2", "03/11/2026")); rule.waitForTag(AdminTags.TOAST); shot("zh-foreground-toast")
        rule.waitUntilGone(AdminTags.TOAST)
        rule.tap(AdminTags.FILTER_DATE, scroll = true)
        rule.tap(AdminTags.DATE_ONE); shot("zi-date-picker")
    }
}
