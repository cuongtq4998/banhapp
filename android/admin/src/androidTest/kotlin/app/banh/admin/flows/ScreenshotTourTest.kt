package app.banh.admin.flows

import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import app.banh.admin.testing.Shots
import app.banh.admin.testing.launchStub
import app.banh.admin.testing.signIn
import app.banh.admin.testing.waitForTag
import app.banh.admin.ui.AdminTags
import org.junit.Rule
import org.junit.Test

/** Walks every screen state of this slice once and saves a screenshot of each (outside the repository, see [Shots]). */
class ScreenshotTourTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun settle() = rule.waitForIdle().also { Thread.sleep(400) }

    @Test
    fun staffTour() = launchStub().use {
        rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("nhanvien.a@example.com")
        settle(); Shots.take("01-signin-email-filled")
        rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
        rule.waitForTag(AdminTags.CODE_FIELD).performTextInput("000000")
        rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
        rule.waitForTag(AdminTags.CODE_ERROR); settle(); Shots.take("02-code-wrong")
        rule.onNodeWithTag(AdminTags.CODE_FIELD).performTextInput("123456")
        settle(); Shots.take("03-code-filled")
        rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
        rule.waitForTag(AdminTags.orderDue("BT-7K3M9Q")); settle(); Shots.take("04-list-todo-staff")
        rule.onNodeWithTag(AdminTags.FILTER_DATE).performScrollTo().performClick()
        rule.waitForTag(AdminTags.DATE_TODAY); settle(); Shots.take("05-list-date-menu")
        rule.onNodeWithTag(AdminTags.DATE_TODAY).performClick()
        settle(); Shots.take("06-list-date-today")
        rule.onNodeWithTag(AdminTags.FILTER_ALL).performScrollTo().performClick()
        settle(); Shots.take("07-list-all")
        rule.onNodeWithTag(AdminTags.ORDERS_SEARCH).performTextInput("zz")
        rule.waitForTag(AdminTags.ORDERS_SEARCH_MIN); settle(); Shots.take("08-list-search-min")
        rule.onNodeWithTag(AdminTags.ORDERS_SEARCH).performTextInput("z")
        rule.waitForTag(AdminTags.ORDERS_EMPTY); settle(); Shots.take("09-list-search-empty")
        rule.onNodeWithTag(AdminTags.ORDERS_SEARCH).performTextInput("error")
        rule.waitForTag(AdminTags.ORDERS_ERROR); settle(); Shots.take("10-list-error")
        rule.onNodeWithTag(AdminTags.ORDERS_ACCOUNT).performClick()
        rule.waitForTag(AdminTags.ACCOUNT_SIGN_OUT); settle(); Shots.take("11-account-sheet")
        rule.onNodeWithTag(AdminTags.ACCOUNT_SIGN_OUT).performClick()
        rule.waitForTag(AdminTags.ACCOUNT_SIGN_OUT_YES); settle(); Shots.take("12-signout-dialog")
    }

    @Test
    fun detailTour() = launchStub().use {
        rule.signIn()
        rule.waitForTag(AdminTags.orderRow("BT-7K3M9Q")).performClick()
        rule.waitForTag(AdminTags.DETAIL_CONFIRM); settle(); Shots.take("20-detail-new")
        rule.onNodeWithTag(AdminTags.DETAIL_CANCEL).performClick()
        rule.waitForTag(AdminTags.CANCEL_CONFIRM); settle(); Shots.take("21-cancel-sheet-empty")
        rule.onNodeWithTag(AdminTags.REASON_NO_CONTACT).performClick()
        settle(); Shots.take("22-cancel-sheet-selected")
        rule.onNodeWithTag(AdminTags.CANCEL_BACK).performClick()
        rule.waitForTag(AdminTags.DETAIL_CONFIRM)
        rule.onNodeWithTag(AdminTags.DETAIL_CONFIRM).performClick()
        rule.waitForTag(AdminTags.TOAST); settle(); Shots.take("23-detail-confirmed-toast")
        rule.onNodeWithTag(AdminTags.DETAIL_COMPLETE).performClick()
        rule.waitForTag(AdminTags.DETAIL_COMPLETE_YES); settle(); Shots.take("24-complete-dialog")
        rule.onNodeWithTag(AdminTags.DETAIL_COMPLETE_YES).performClick()
        rule.waitForTag(AdminTags.DETAIL_STATUS); Thread.sleep(3500); settle(); Shots.take("25-detail-completed")
        rule.onNodeWithTag(AdminTags.NAV_BACK).performClick()
        rule.waitForTag(AdminTags.orderRow("BT-9C5D3F")).performClick()
        rule.waitForTag(AdminTags.DETAIL_CONFIRM).performClick()
        rule.waitForTag(AdminTags.DETAIL_CONFLICT); settle(); Shots.take("26-detail-conflict")
    }

    @Test
    fun ownerTour() = launchStub().use {
        rule.signIn("owner@example.com")
        rule.waitForTag(AdminTags.TAB_ORDERS_BADGE); settle(); Shots.take("30-list-owner-tabbar")
        rule.onNodeWithTag(AdminTags.TAB_SETTINGS).performClick()
        rule.waitForTag(AdminTags.SETTINGS_SIGN_OUT); settle(); Shots.take("31-settings-placeholder")
    }
}
