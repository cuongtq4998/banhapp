package app.banh.core.design

import androidx.compose.ui.unit.dp

// Admin tokens of docs/design/design-system/07-admin-additions.md section 7.1 (Android column). Plain Long like ColorTokens,
// so unit tests can measure contrast without the Compose runtime.
object StatusTokens {
    const val NEW_FILL = 0xFFFFF1CCL
    const val NEW_TEXT = 0xFF5C4400L
    const val CONFIRMED_FILL = ColorTokens.PRIMARY_CONTAINER
    const val CONFIRMED_TEXT = ColorTokens.ON_PRIMARY_CONTAINER
    const val COMPLETED_TEXT = ColorTokens.TEXT_SECONDARY
    const val CANCELLED_FILL = ColorTokens.ERROR_CONTAINER
    const val CANCELLED_TEXT = ColorTokens.ERROR
    const val DUE_FILL = ColorTokens.ERROR_CONTAINER
    const val DUE_TEXT = ColorTokens.ERROR
    const val TAB_BADGE_FILL = ColorTokens.ERROR
    const val TAB_BADGE_TEXT = 0xFFFFFFFFL

    /** Completed is a translucent grey over the glass card; for contrast it is measured on the solid surface. */
    const val COMPLETED_FILL_ALPHA = 0.08f
}

object AdminSizes {
    val otpCellWidth = 48.dp
    val otpCellHeight = 56.dp
    val badgeHeight = 24.dp
    val chipHeight = 48.dp
}
