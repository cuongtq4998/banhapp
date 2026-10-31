package app.banh.customer.order

import app.banh.customer.data.availability.AvailableDate
import app.banh.customer.data.availability.UnavailableReason
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

/** What S-6 can say about one day (UI document 5.6). */
enum class DateStatus {
    AVAILABLE,

    /** Before today plus the lead time. */
    TOO_SOON,

    /** After today plus the booking horizon. */
    TOO_FAR,

    /** Not enough room left for this order. */
    FULL,
    ;

    val selectable: Boolean get() = this == AVAILABLE
}

data class CalendarDay(val date: LocalDate, val status: DateStatus)

/** One month of the grid; weeks start on Monday, so [leadingBlanks] empty cells come before day 1. */
data class CalendarMonth(val month: YearMonth, val leadingBlanks: Int, val days: List<CalendarDay>)

/**
 * The months from the server's today to the end of the booking horizon with the state of each day. All dates come from
 * the server answer; the device date is never read (A-1, AC-7, AC-24).
 */
class DateCalendar(private val serverDate: LocalDate, maxDaysAhead: Int, dates: List<AvailableDate>) {
    private val byDate: Map<LocalDate, DateStatus> = dates.associate { LocalDate.parse(it.date) to statusOf(it) }

    val months: List<CalendarMonth> = run {
        val first = YearMonth.from(serverDate)
        val last = YearMonth.from(serverDate.plusDays(maxDaysAhead.toLong()))
        generateSequence(first) { if (it < last) it.plusMonths(1) else null }.map(::buildMonth).toList()
    }

    fun statusOf(date: LocalDate): DateStatus = byDate[date] ?: when {
        date < serverDate -> DateStatus.TOO_SOON
        else -> DateStatus.TOO_FAR
    }

    val hasSelectableDate: Boolean get() = byDate.values.any { it.selectable }

    /** Index of the month a customer should see first: the chosen date, else the first day that can be chosen. */
    fun initialMonthIndex(selected: LocalDate?): Int {
        val target = selected?.takeIf { statusOf(it).selectable }
            ?: byDate.entries.filter { it.value.selectable }.minByOrNull { it.key }?.key
            ?: return 0
        return months.indexOfFirst { it.month == YearMonth.from(target) }.coerceAtLeast(0)
    }

    private fun buildMonth(month: YearMonth): CalendarMonth {
        val days = (1..month.lengthOfMonth()).map { day ->
            val date = month.atDay(day)
            CalendarDay(date, statusOf(date))
        }
        return CalendarMonth(month, leadingBlanks = month.atDay(1).dayOfWeek.value - 1, days = days)
    }

    private fun statusOf(entry: AvailableDate): DateStatus = when (entry.unavailableReason) {
        null -> DateStatus.AVAILABLE
        UnavailableReason.TOO_SOON -> DateStatus.TOO_SOON
        UnavailableReason.TOO_FAR -> DateStatus.TOO_FAR
        UnavailableReason.FULL -> DateStatus.FULL
    }
}

private val DISPLAY_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy")

/** `04/11/2026` (AC-31). The pattern has no locale-dependent part, so the device language cannot change it. */
fun LocalDate.toDisplayText(): String = format(DISPLAY_FORMAT)

/** Reads a stored `yyyy-MM-dd`; a damaged value in a restored draft is treated as no date. */
fun String.toLocalDateOrNull(): LocalDate? = try {
    LocalDate.parse(this)
} catch (e: DateTimeParseException) {
    null
}
