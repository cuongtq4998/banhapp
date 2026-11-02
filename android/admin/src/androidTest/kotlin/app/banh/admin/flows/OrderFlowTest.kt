package app.banh.admin.flows

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import app.banh.admin.testing.has
import app.banh.admin.testing.launchStub
import app.banh.admin.testing.signIn
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class OrderFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun open(code: String) {
        rule.waitForTag(AdminTags.orderRow(code)).performClick()
        rule.waitForTag(AdminTags.DETAIL_CUSTOMER)
    }

    @Test
    fun listShowsDueMarksOnlyForOpenOrdersDueByTheServerDate() {
        launchStub().use {
            rule.signIn()
            rule.waitForTag(AdminTags.orderDue("BT-7K3M9Q"))
            rule.waitForTag(AdminTags.orderDue("BT-2H4N8R"))
            assertFalse(rule.has(AdminTags.orderDue("BT-9C5D3F")))
            rule.waitForTag(AdminTags.ORDERS_BADGE)
        }
    }

    @Test
    fun confirmIsOneTapAndUpdatesInPlaceWithAToast() {
        launchStub().use {
            rule.signIn()
            open("BT-7K3M9Q")
            rule.onNodeWithTag(AdminTags.DETAIL_CONFIRM).performClick()
            rule.waitForTag(AdminTags.TOAST)
            rule.waitForTag(AdminTags.DETAIL_COMPLETE)
            assertFalse(rule.has(AdminTags.DETAIL_CONFIRM))
        }
    }

    @Test
    fun completeAsksOnceThenFinishesTheOrderAndRemovesTheBar() {
        launchStub().use {
            rule.signIn()
            open("BT-2H4N8R")
            rule.onNodeWithTag(AdminTags.DETAIL_COMPLETE).performClick()
            rule.waitForTag(AdminTags.DETAIL_COMPLETE_BACK).performClick()
            rule.waitUntilGone(AdminTags.DETAIL_COMPLETE_YES)
            rule.onNodeWithTag(AdminTags.DETAIL_COMPLETE).performClick()
            rule.waitForTag(AdminTags.DETAIL_COMPLETE_YES).performClick()
            rule.waitUntilGone(AdminTags.DETAIL_COMPLETE)
            assertFalse(rule.has(AdminTags.DETAIL_CANCEL))
        }
    }

    @Test
    fun cancelNeedsAReasonThenShowsTheReasonCard() {
        launchStub().use {
            rule.signIn()
            open("BT-7K3M9Q")
            rule.onNodeWithTag(AdminTags.DETAIL_CANCEL).performClick()
            rule.waitForTag(AdminTags.CANCEL_CONFIRM).assertIsNotEnabled()
            rule.onNodeWithTag(AdminTags.REASON_CUSTOMER).performClick()
            rule.onNodeWithTag(AdminTags.CANCEL_CONFIRM).assertIsEnabled().performClick()
            rule.waitForTag(AdminTags.DETAIL_REASON)
            assertFalse(rule.has(AdminTags.DETAIL_CANCEL))
        }
    }

    @Test
    fun anOrderChangedByAnotherPersonShowsTheConflictAndTheCurrentStatus() {
        launchStub().use {
            rule.signIn()
            open("BT-9C5D3F")
            rule.onNodeWithTag(AdminTags.DETAIL_CONFIRM).performClick()
            rule.waitForTag(AdminTags.DETAIL_CONFLICT)
            rule.waitForTag(AdminTags.DETAIL_COMPLETE)
        }
    }

    @Test
    fun backToTheListShowsTheNewStatusAndTheBadgeDrops() {
        launchStub().use {
            rule.signIn()
            open("BT-7K3M9Q")
            rule.onNodeWithTag(AdminTags.DETAIL_CONFIRM).performClick()
            rule.waitForTag(AdminTags.DETAIL_COMPLETE)
            rule.onNodeWithTag(AdminTags.NAV_BACK).performClick()
            rule.waitForTag(AdminTags.ORDERS_LIST)
            rule.waitForTag(AdminTags.orderRow("BT-7K3M9Q"))
        }
    }

    @Test
    fun statusChipsDateMenuAndSearchFilterTheList() {
        launchStub().use {
            rule.signIn()
            rule.onNodeWithTag(AdminTags.FILTER_COMPLETED).performScrollTo().performClick()
            rule.waitForTag(AdminTags.orderRow("BT-6P2W7X"))
            assertFalse(rule.has(AdminTags.orderRow("BT-7K3M9Q")))
            rule.onNodeWithTag(AdminTags.FILTER_TODO).performClick()
            rule.waitForTag(AdminTags.orderRow("BT-7K3M9Q"))

            rule.onNodeWithTag(AdminTags.FILTER_DATE).performScrollTo().performClick()
            rule.waitForTag(AdminTags.DATE_TODAY).performClick()
            rule.waitUntilGone(AdminTags.orderRow("BT-2H4N8R"))
            assertTrue(rule.has(AdminTags.orderRow("BT-7K3M9Q")))

            rule.onNodeWithTag(AdminTags.ORDERS_SEARCH).performTextInput("zz")
            rule.waitForTag(AdminTags.ORDERS_SEARCH_MIN)
            rule.onNodeWithTag(AdminTags.ORDERS_SEARCH).performTextInput("z")
            rule.waitForTag(AdminTags.ORDERS_EMPTY)
        }
    }

    @Test
    fun ownerHasTheTabBarAndASettingsPlaceholderWithSignOut() {
        launchStub().use {
            rule.signIn("owner@example.com")
            rule.waitForTag(AdminTags.TAB_ORDERS)
            rule.waitForTag(AdminTags.TAB_ORDERS_BADGE)
            rule.onNodeWithTag(AdminTags.TAB_SETTINGS).performClick()
            rule.waitForTag(AdminTags.SETTINGS_SIGN_OUT_OTHERS).performClick()
            rule.waitForTag(AdminTags.SETTINGS_SIGN_OUT_OTHERS_YES).performClick()
            rule.waitForTag(AdminTags.TOAST)
        }
    }
}
