package app.banh.admin.testing

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.click
import androidx.compose.ui.test.isEnabled
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import app.banh.admin.ui.AdminOrderTags

// The picker cells read as "Friday, November 27, 2026" (device locale en-US).
private fun dayCell(day: Int) = hasText("November $day, 2026", substring = true)

/** Taps a day of the open date picker by its number (the stub shows November 2026). */
fun ComposeTestRule.pickDay(day: Int) {
    waitForTag(AdminOrderTags.SCHEDULE_PICKER)
    onNode(dayCell(day)).performClick()
}

/** Schedules from the date sheet with [day] (null keeps the day the picker opens on) and waits for it to close. */
fun ComposeTestRule.scheduleOnDay(day: Int?) {
    tap(AdminOrderTags.ORDER_SCHEDULE)
    day?.let(::pickDay)
    waitForTag(AdminOrderTags.SCHEDULE_SAVE).assertIsEnabled().performClick()
    waitUntilGone(AdminOrderTags.SCHEDULE_SHEET)
}

/** Starts delivery from the fee sheet with the typed [fee] and waits for the sheet to close. */
fun ComposeTestRule.startWithFee(fee: String) {
    tap(AdminOrderTags.ORDER_START_DELIVERY)
    typeInto(AdminOrderTags.FEE_FIELD, fee)
    onNodeWithTag(AdminOrderTags.FEE_CONFIRM).assertIsEnabled().performClick()
    waitUntilGone(AdminOrderTags.FEE_SHEET)
}

// The stub window ends on November 9; the 10th is shown but not selectable.
private const val OUT_OF_RANGE_DAY = 10

/** Touches a day beyond the server range; the picker must ignore it. */
fun ComposeTestRule.pickOutOfRangeDay() {
    waitForTag(AdminOrderTags.SCHEDULE_PICKER)
    onNode(dayCell(OUT_OF_RANGE_DAY)).performTouchInput { click() }
    waitForIdle()
}

/** Waits until the element with [tag] accepts taps. */
fun ComposeTestRule.waitUntilEnabled(tag: String) = waitUntil(WAIT_ENABLED_MILLIS) { onAllNodes(hasTestTag(tag) and isEnabled()).fetchSemanticsNodes().isNotEmpty() }

private const val WAIT_ENABLED_MILLIS = 5_000L
