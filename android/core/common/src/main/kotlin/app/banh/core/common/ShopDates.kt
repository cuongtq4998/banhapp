package app.banh.core.common

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import app.banh.core.model.OrderStatus

/** The shop works in Vietnam time; instants from the server are shown in it, shop dates are plain dates. */
val ShopZone: ZoneId = ZoneId.of("Asia/Ho_Chi_Minh")

private val DAY_MONTH_YEAR: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.ROOT)
private val DAY_MONTH: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM", Locale.ROOT)
private val TIME: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.ROOT)
private val WEEKDAYS = listOf("Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ nhật")

fun parseShopDate(text: String): LocalDate = LocalDate.parse(text)

/** `dd/MM`, with the year only when it is not the current year; "current" is the year of the server date, never the device clock. */
private fun LocalDate.short(serverDate: String?): String =
    if (serverDate == null || year == parseShopDate(serverDate).year) format(DAY_MONTH) else format(DAY_MONTH_YEAR)

fun formatDate(text: String, serverDate: String? = null): String = parseShopDate(text).short(serverDate)

fun formatDayMonth(date: LocalDate): String = date.format(DAY_MONTH)

/** "Thứ Hai, 02/11" for the delivery card (S-A4); the year appears when it is not the current one. */
fun formatWeekdayDate(text: String, serverDate: String? = null): String {
    val date = parseShopDate(text)
    return "${WEEKDAYS[date.dayOfWeek.value - 1]}, ${date.short(serverDate)}"
}

fun formatInstant(text: String, serverDate: String? = null): String {
    val at = Instant.parse(text).atZone(ShopZone)
    return "${at.format(TIME)} ${at.toLocalDate().short(serverDate)}"
}
/** A red mark next to the delivery date of an open order that is due (FR-9). */
sealed interface DueMark {
    data object Today : DueMark

    data class Overdue(val days: Long) : DueMark
}

/**
 * Computed from the order's date and the server date of the same answer, never from the device clock (TQ-D8).
 * Completed and Cancelled orders never show a mark (AC-16).
 */
fun dueMarkOf(status: OrderStatus, deliveryDate: String, serverDate: String): DueMark? {
    if (!status.isOpen) return null
    val days = ChronoUnit.DAYS.between(parseShopDate(deliveryDate), parseShopDate(serverDate))
    return when {
        days < 0 -> null
        days == 0L -> DueMark.Today
        else -> DueMark.Overdue(days)
    }
}
