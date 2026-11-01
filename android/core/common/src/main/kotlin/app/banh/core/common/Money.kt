package app.banh.core.common

import java.text.NumberFormat
import java.util.Locale

private val VIETNAM_LOCALE: Locale = Locale.forLanguageTag("vi-VN")

/** Whole dong with dots between thousands and the dong sign: "120.000 ₫". */
fun formatVnd(amount: Long): String = NumberFormat.getIntegerInstance(VIETNAM_LOCALE).format(amount) + " ₫"

/** The badge on the Orders tab: the number up to 99, then "99+" (FR-13). Zero is hidden by the caller. */
fun badgeText(count: Int): String = if (count > MAX_BADGE) "$MAX_BADGE+" else count.toString()

private const val MAX_BADGE = 99
