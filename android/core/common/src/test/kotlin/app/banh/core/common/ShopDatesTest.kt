package app.banh.core.common

import app.banh.core.model.OrderStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ShopDatesTest {
    @Test
    fun openOrderDueTodayAndOverdueUseTheServerDate() {
        assertEquals(DueMark.Today, dueMarkOf(OrderStatus.Received, "2026-11-02", "2026-11-02"))
        assertEquals(DueMark.Overdue(2), dueMarkOf(OrderStatus.Processing, "2026-10-31", "2026-11-02"))
        assertNull(dueMarkOf(OrderStatus.Received, "2026-11-03", "2026-11-02"))
    }

    @Test
    fun finishedOrdersNeverShowAMark() {
        assertNull(dueMarkOf(OrderStatus.Finished, "2026-10-01", "2026-11-02"))
        assertNull(dueMarkOf(OrderStatus.Cancelled, "2026-11-02", "2026-11-02"))
    }

    @Test
    fun badgeShows99PlusAbove99() {
        assertEquals("99", badgeText(99))
        assertEquals("99+", badgeText(100))
    }

    @Test
    fun moneyUsesDotsAndTheDongSign() = assertEquals("120.000 ₫", formatVnd(120000))

    @Test
    fun dateAndInstantAreShownInShopTime() {
        assertEquals("02/11", formatDate("2026-11-02", "2026-11-05"))
        assertEquals("02/11/2025", formatDate("2025-11-02", "2026-11-05"))
        assertEquals("10:15 31/10", formatInstant("2026-10-31T03:15:09Z", "2026-11-02"))
        assertEquals("Thứ Hai, 02/11", formatWeekdayDate("2026-11-02", "2026-11-02"))
    }
}
