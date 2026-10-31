package app.banh.customer.order

import app.banh.customer.testing.fixtureAvailability
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The calendar built from `availability-ok.json`: server date 2026-11-02, lead 2 days, horizon 30 days. */
class DateCalendarTest {
    private val availability = fixtureAvailability()
    private val calendar = DateCalendar(LocalDate.parse(availability.serverDate), maxDaysAhead = 30, dates = availability.dates)

    private fun status(date: String) = calendar.statusOf(LocalDate.parse(date))

    @Test
    fun monthsRunFromTheServerDateToTheEndOfTheHorizon() {
        assertEquals(listOf(YearMonth.of(2026, 11), YearMonth.of(2026, 12)), calendar.months.map { it.month })
    }

    @Test
    fun weeksStartOnMondayAndNovember2026BeginsOnASunday() {
        assertEquals(6, calendar.months[0].leadingBlanks)
        assertEquals(30, calendar.months[0].days.size)
    }

    // AC-7: nothing before the server date plus the lead time can be selected, whatever the device says.
    @Test
    fun datesBeforeTheLeadTimeCannotBeSelected() {
        assertEquals(DateStatus.TOO_SOON, status("2026-11-01"))
        assertEquals(DateStatus.TOO_SOON, status("2026-11-02"))
        assertEquals(DateStatus.TOO_SOON, status("2026-11-03"))
        assertEquals(DateStatus.AVAILABLE, status("2026-11-04"))
    }

    // AC-24: the last day of the horizon can be selected, the day after cannot.
    @Test
    fun theLastDayOfTheHorizonIsSelectableAndTheNextIsNot() {
        assertEquals(DateStatus.AVAILABLE, status("2026-12-02"))
        assertEquals(DateStatus.TOO_FAR, status("2026-12-03"))
        assertFalse(status("2026-12-03").selectable)
    }

    // AC-8: full dates are marked and cannot be selected.
    @Test
    fun fullDatesAreMarkedAndNotSelectable() {
        assertEquals(DateStatus.FULL, status("2026-11-05"))
        assertEquals(DateStatus.FULL, status("2026-11-20"))
        assertFalse(status("2026-11-20").selectable)
        assertTrue(status("2026-11-06").selectable)
    }

    @Test
    fun theFirstMonthShownHoldsTheChosenDateOrTheFirstSelectableOne() {
        assertEquals(0, calendar.initialMonthIndex(null))
        assertEquals(1, calendar.initialMonthIndex(LocalDate.parse("2026-12-01")))
        // A chosen date that is no longer selectable falls back to the first selectable day.
        assertEquals(0, calendar.initialMonthIndex(LocalDate.parse("2026-11-05")))
    }

    @Test
    fun aCalendarWithoutASelectableDateSaysSo() {
        val allFull = availability.dates.map { it.copy(available = false, reason = "FULL") }

        val full = DateCalendar(LocalDate.parse(availability.serverDate), 30, allFull)

        assertFalse(full.hasSelectableDate)
        assertTrue(calendar.hasSelectableDate)
    }

    @Test
    fun displayFormatIsDayMonthYear() {
        assertEquals("04/11/2026", LocalDate.parse("2026-11-04").toDisplayText())
    }

    @Test
    fun aDamagedStoredDateIsNoDate() {
        assertEquals(null, "not-a-date".toLocalDateOrNull())
        assertEquals(LocalDate.parse("2026-11-04"), "2026-11-04".toLocalDateOrNull())
    }
}
