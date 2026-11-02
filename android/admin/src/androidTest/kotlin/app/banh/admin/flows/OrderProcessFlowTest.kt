package app.banh.admin.flows

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import app.banh.admin.testing.has
import app.banh.admin.testing.launchStub
import app.banh.admin.testing.pickDay
import app.banh.admin.testing.pickOutOfRangeDay
import app.banh.admin.testing.waitUntilEnabled
import app.banh.admin.testing.scheduleOnDay
import app.banh.admin.testing.signIn
import app.banh.admin.testing.startWithFee
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.ui.AdminOrderTags
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

// Codes of the stub orders: received, scheduled and delivery-started.
private const val RECEIVED = "BT-7K3M9Q"
private const val SCHEDULED = "BT-3S5T9U"
private const val STARTED = "BT-5D1L6V"
private const val DAY_IN_RANGE = 3

class OrderProcessFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun open(code: String) {
        rule.waitForTag(AdminOrderTags.orderRow(code)).performClick()
        rule.waitForTag(AdminOrderTags.DETAIL_CUSTOMER)
    }

    @Test
    fun fiveStepsRunFromReceivedToFinished() {
        launchStub().use {
            rule.signIn()
            open(RECEIVED)
            rule.tap(AdminOrderTags.ORDER_PROCESS)
            rule.waitForTag(AdminOrderTags.ORDER_SCHEDULE)
            rule.scheduleOnDay(4)
            rule.waitForTag(AdminOrderTags.ORDER_START_DELIVERY)
            rule.waitForTag(AdminOrderTags.ORDER_EXPECTED_DATE)
            rule.startWithFee("30000")
            rule.waitForTag(AdminOrderTags.ORDER_FINISH)
            rule.waitForTag(AdminOrderTags.ORDER_TOTAL_COLLECT)
            rule.tap(AdminOrderTags.ORDER_FINISH)
            rule.tap(AdminOrderTags.DETAIL_COMPLETE_YES)
            rule.waitUntilGone(AdminOrderTags.ORDER_FINISH)
            assertFalse(rule.has(AdminOrderTags.ORDER_FEE_CORRECT))
        }
    }

    @Test
    fun cancelIsNotOfferedOnceTheDateIsScheduled() {
        launchStub().use {
            rule.signIn()
            open(RECEIVED)
            rule.waitForTag(AdminOrderTags.DETAIL_CANCEL)
            rule.tap(AdminTags.NAV_BACK)
            rule.waitForTag(AdminOrderTags.orderRow(SCHEDULED))
            open(SCHEDULED)
            rule.waitForTag(AdminOrderTags.ORDER_START_DELIVERY)
            assertFalse(rule.has(AdminOrderTags.DETAIL_CANCEL))
            rule.tap(AdminTags.NAV_BACK)
            open(STARTED)
            rule.waitForTag(AdminOrderTags.ORDER_FINISH)
            assertFalse(rule.has(AdminOrderTags.DETAIL_CANCEL))
        }
    }

    @Test
    fun aDateOutsideTheServerRangeCannotBeSaved() {
        launchStub().use {
            rule.signIn()
            open(SCHEDULED)
            rule.tap(AdminOrderTags.ORDER_CHANGE_DATE)
            rule.waitForTag(AdminOrderTags.SCHEDULE_SAVE).assertIsNotEnabled()
            rule.pickOutOfRangeDay()
            rule.onNodeWithTag(AdminOrderTags.SCHEDULE_SAVE).assertIsNotEnabled()
            rule.pickDay(DAY_IN_RANGE)
            rule.waitUntilEnabled(AdminOrderTags.SCHEDULE_SAVE)
            assertTrue(rule.has(AdminOrderTags.SCHEDULE_LIMIT))
        }
    }

    @Test
    fun aFeeOfZeroIsAcceptedAtStartDelivery() {
        launchStub().use {
            rule.signIn()
            open(SCHEDULED)
            rule.startWithFee("0")
            rule.waitForTag(AdminOrderTags.ORDER_FINISH)
            rule.waitForTag(AdminOrderTags.ORDER_TOTAL_COLLECT)
        }
    }

    @Test
    fun aFeeCorrectionAddsToTheHistoryCard() {
        launchStub().use {
            rule.signIn()
            open(STARTED)
            assertFalse(rule.has(AdminOrderTags.ORDER_FEE_HISTORY))
            rule.tap(AdminOrderTags.ORDER_FEE_CORRECT, scroll = true)
            rule.typeInto(AdminOrderTags.FEE_FIX_FIELD, "30000")
            rule.onNodeWithTag(AdminOrderTags.FEE_FIX_SAVE).assertIsEnabled().performClick()
            rule.waitUntilGone(AdminOrderTags.FEE_FIX_SHEET)
            rule.waitForTag(AdminOrderTags.ORDER_FEE_HISTORY)
            rule.waitForTag(AdminOrderTags.feeHistoryRow(1))
        }
    }

    @Test
    fun theAmountToCollectIsHiddenUntilTheFeeIsKnown() {
        launchStub().use {
            rule.signIn()
            open(RECEIVED)
            assertFalse(rule.has(AdminOrderTags.ORDER_TOTAL_COLLECT))
            rule.tap(AdminTags.NAV_BACK)
            open(SCHEDULED)
            rule.waitForTag(AdminOrderTags.ORDER_START_DELIVERY)
            assertFalse(rule.has(AdminOrderTags.ORDER_TOTAL_COLLECT))
        }
    }
}
