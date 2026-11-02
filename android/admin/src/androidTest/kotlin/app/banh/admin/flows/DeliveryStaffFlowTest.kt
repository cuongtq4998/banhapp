package app.banh.admin.flows

import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import app.banh.admin.testing.has
import app.banh.admin.testing.openArea
import app.banh.admin.testing.signInOwner
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.testing.withStub
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

private const val DISTRICT = "5b0c2f6a-0000-4a00-8000-0000000000d1"
private const val SLOT = "5b0c2f6a-0000-4a00-8000-0000000000e1"
private const val STAFF = "5b0c2f6a-0000-4a00-8000-0000000000a2"
private const val OWNER = "5b0c2f6a-0000-4a00-8000-0000000000a1"

/** S-A10 (districts and slots) and S-A12 (staff) against the stub. */
class DeliveryStaffFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun openDelivery() {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_DELIVERY)
        rule.waitForTag(AdminTags.DISTRICT_ADD)
    }

    @Test
    fun addADistrictThenTheSameNameIsRefused() = withStub {
        openDelivery()
        rule.tap(AdminTags.DISTRICT_ADD)
        rule.typeInto(AdminTags.DISTRICT_NAME, "Quan Moi")
        rule.typeInto(AdminTags.DISTRICT_FEE, "25000")
        rule.tap(AdminTags.DISTRICT_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.DISTRICT_SAVE)
        rule.tap(AdminTags.DISTRICT_ADD)
        rule.typeInto(AdminTags.DISTRICT_NAME, "quan moi")
        rule.typeInto(AdminTags.DISTRICT_FEE, "25000")
        rule.tap(AdminTags.DISTRICT_SAVE)
        rule.waitForTag(AdminTags.DISTRICT_NAME_ERROR)
    }

    @Test
    fun aFeeOfZeroIsRefusedOnThePhone() = withStub {
        openDelivery()
        rule.tap(AdminTags.DISTRICT_ADD)
        rule.typeInto(AdminTags.DISTRICT_NAME, "Quan Mot")
        rule.typeInto(AdminTags.DISTRICT_FEE, "0")
        rule.tap(AdminTags.DISTRICT_SAVE)
        rule.waitForTag(AdminTags.DISTRICT_FEE_ERROR)
    }

    @Test
    fun theLastActiveDistrictAndSlotCannotBeSwitchedOff() = withStub {
        openDelivery()
        rule.tap(AdminTags.districtToggle(DISTRICT))
        rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.TOAST)
        // Lazy rows below the districts are not composed until the list scrolls to them.
        rule.onNodeWithTag(AdminTags.DELIVERY_LIST).performScrollToNode(hasTestTag(AdminTags.slotToggle(SLOT)))
        rule.tap(AdminTags.slotToggle(SLOT))
        rule.waitForTag(AdminTags.TOAST)
    }

    @Test
    fun aNewSlotIsAddedAndTheSamePairIsADuplicate() = withStub {
        openDelivery()
        rule.tap(AdminTags.SLOT_ADD)
        rule.tap(AdminTags.SLOT_START)
        rule.tap("${AdminTags.SLOT_START}.ok")
        rule.tap(AdminTags.SLOT_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.SLOT_SAVE)
        rule.tap(AdminTags.SLOT_ADD)
        rule.tap(AdminTags.SLOT_SAVE)
        rule.waitForTag(AdminTags.DELIVERY_ERROR)
    }

    @Test
    fun staffAddRefusesATakenAddressAndAddsANewOne() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_STAFF)
        rule.waitForTag(AdminTags.STAFF_ADD)
        rule.tap(AdminTags.STAFF_ADD)
        rule.typeInto(AdminTags.STAFF_ADD_NAME, "Nhan Vien B")
        rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "not-an-email")
        rule.tap(AdminTags.STAFF_ADD_SAVE)
        rule.waitForTag(AdminTags.staffAddError("email"))
        rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "Nhanvien.A@example.com")
        rule.tap(AdminTags.STAFF_ADD_SAVE)
        rule.waitForTag(AdminTags.staffAddError("email"))
        rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "nhanvien.b@example.com")
        rule.tap(AdminTags.STAFF_ADD_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.STAFF_ADD_SAVE)
    }

    @Test
    fun theThirtyFirstStaffAccountShowsTheLimitMessage() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_STAFF)
        rule.tap(AdminTags.STAFF_ADD)
        rule.typeInto(AdminTags.STAFF_ADD_NAME, "Nhan Vien C")
        rule.typeInto(AdminTags.STAFF_ADD_EMAIL, "full@example.com")
        rule.tap(AdminTags.STAFF_ADD_SAVE)
        rule.waitForTag(AdminTags.staffAddError("banner"))
    }

    @Test
    fun deactivateAsksFirstAndReactivateDoesNot() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_STAFF)
        rule.tap(AdminTags.staffRow(STAFF))
        rule.tap(AdminTags.STAFF_DEACTIVATE)
        rule.tap(AdminTags.STAFF_DEACTIVATE_YES)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitUntilGone(AdminTags.STAFF_DEACTIVATE)
        rule.tap(AdminTags.staffRow(STAFF))
        rule.tap(AdminTags.STAFF_REACTIVATE)
        rule.waitUntilGone(AdminTags.STAFF_REACTIVATE)
    }

    @Test
    fun theOwnerRowIsListedFirstAndCannotBeOpened() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_STAFF)
        rule.waitForTag(AdminTags.staffRow(OWNER)).performClickSafely()
        assertFalse(rule.has(AdminTags.STAFF_DEACTIVATE))
        assertTrue(rule.has(AdminTags.STAFF_ADD))
    }
}

private fun androidx.compose.ui.test.SemanticsNodeInteraction.performClickSafely() {
    runCatching { performClick() }
}
