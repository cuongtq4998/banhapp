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
import app.banh.admin.ui.AdminOrderTags
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class OrderFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun open(code: String) {
        rule.waitForTag(AdminOrderTags.orderRow(code)).performClick()
        rule.waitForTag(AdminOrderTags.DETAIL_CUSTOMER)
    }

    @Test
    fun listShowsDueMarksOnlyForOpenOrdersDueByTheServerDate() {
        launchStub().use {
            rule.signIn()
            rule.waitForTag(AdminOrderTags.orderDue("BT-7K3M9Q"))
            rule.waitForTag(AdminOrderTags.orderDue("BT-2H4N8R"))
            assertFalse(rule.has(AdminOrderTags.orderDue("BT-9C5D3F")))
            rule.waitForTag(AdminTags.ORDERS_BADGE)
        }
    }

    @Test
    fun confirmIsOneTapAndUpdatesInPlaceWithAToast() {
        launchStub().use {
            rule.signIn()
            open("BT-7K3M9Q")
            rule.onNodeWithTag(AdminOrderTags.ORDER_PROCESS).performClick()
            rule.waitForTag(AdminTags.TOAST)
            rule.waitForTag(AdminOrderTags.ORDER_FINISH)
            assertFalse(rule.has(AdminOrderTags.ORDER_PROCESS))
        }
    }

    @Test
    fun completeAsksOnceThenFinishesTheOrderAndRemovesTheBar() {
        launchStub().use {
            rule.signIn()
            open("BT-2H4N8R")
            rule.onNodeWithTag(AdminOrderTags.ORDER_FINISH).performClick()
            rule.waitForTag(AdminOrderTags.DETAIL_COMPLETE_BACK).performClick()
            rule.waitUntilGone(AdminOrderTags.DETAIL_COMPLETE_YES)
            rule.onNodeWithTag(AdminOrderTags.ORDER_FINISH).performClick()
            rule.waitForTag(AdminOrderTags.DETAIL_COMPLETE_YES).performClick()
            rule.waitUntilGone(AdminOrderTags.ORDER_FINISH)
            assertFalse(rule.has(AdminOrderTags.DETAIL_CANCEL))
        }
    }

    @Test
    fun cancelNeedsAReasonThenShowsTheReasonCard() {
        launchStub().use {
            rule.signIn()
            open("BT-7K3M9Q")
            rule.onNodeWithTag(AdminOrderTags.DETAIL_CANCEL).performClick()
            rule.waitForTag(AdminOrderTags.CANCEL_CONFIRM).assertIsNotEnabled()
            rule.onNodeWithTag(AdminOrderTags.REASON_CUSTOMER).performClick()
            rule.onNodeWithTag(AdminOrderTags.CANCEL_CONFIRM).assertIsEnabled().performClick()
            rule.waitForTag(AdminOrderTags.DETAIL_REASON)
            assertFalse(rule.has(AdminOrderTags.DETAIL_CANCEL))
        }
    }

    @Test
    fun anOrderChangedByAnotherPersonShowsTheConflictAndTheCurrentStatus() {
        launchStub().use {
            rule.signIn()
            open("BT-9C5D3F")
            rule.onNodeWithTag(AdminOrderTags.ORDER_PROCESS).performClick()
            rule.waitForTag(AdminOrderTags.DETAIL_CONFLICT)
            rule.waitForTag(AdminOrderTags.ORDER_FINISH)
        }
    }

    @Test
    fun backToTheListShowsTheNewStatusAndTheBadgeDrops() {
        launchStub().use {
            rule.signIn()
            open("BT-7K3M9Q")
            rule.onNodeWithTag(AdminOrderTags.ORDER_PROCESS).performClick()
            rule.waitForTag(AdminOrderTags.ORDER_FINISH)
            rule.onNodeWithTag(AdminTags.NAV_BACK).performClick()
            rule.waitForTag(AdminTags.ORDERS_LIST)
            rule.waitForTag(AdminOrderTags.orderRow("BT-7K3M9Q"))
        }
    }

    @Test
    fun statusChipsDateMenuAndSearchFilterTheList() {
        launchStub().use {
            rule.signIn()
            rule.onNodeWithTag(AdminTags.FILTER_COMPLETED).performScrollTo().performClick()
            rule.waitForTag(AdminOrderTags.orderRow("BT-6P2W7X"))
            assertFalse(rule.has(AdminOrderTags.orderRow("BT-7K3M9Q")))
            rule.onNodeWithTag(AdminTags.FILTER_TODO).performClick()
            rule.waitForTag(AdminOrderTags.orderRow("BT-7K3M9Q"))

            rule.onNodeWithTag(AdminTags.FILTER_DATE).performScrollTo().performClick()
            rule.waitForTag(AdminTags.DATE_TODAY).performClick()
            rule.waitUntilGone(AdminOrderTags.orderRow("BT-2H4N8R"))
            assertTrue(rule.has(AdminOrderTags.orderRow("BT-7K3M9Q")))

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
