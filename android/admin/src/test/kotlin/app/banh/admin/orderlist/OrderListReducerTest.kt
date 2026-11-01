package app.banh.admin.orderlist

import app.banh.admin.orders.DateFilter
import app.banh.admin.orders.StatusFilter
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrderSummary
import app.banh.core.model.OrdersPage
import app.banh.core.model.Slot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OrderListReducerTest {
    private fun row(code: String) = OrderSummary(code, OrderStatus.New, "A", "2026-11-02", Slot("08:00", "10:00"), 1, 1, "D", "2026-10-31T03:15:09Z")
    private fun page(vararg codes: String, next: String? = null, unfinished: Int = 3) = OrdersPage(codes.map(::row), next, unfinished, "2026-11-02")
    private fun run(state: OrderListState = OrderListState(), vararg intents: OrderListIntent) = intents.fold(state, ::reduceOrderList)

    @Test
    fun searchStartsAtThreeCharactersOnly() {
        val two = run(intents = arrayOf(OrderListIntent.QueryChanged("ab ")))
        assertEquals("", two.searchText)
        assertTrue(two.searchTooShort)
        assertEquals(0, two.seq)

        val three = run(two, OrderListIntent.QueryChanged("abc"))
        assertEquals("abc", three.searchText)
        assertFalse(three.searchTooShort)
        assertEquals(1, three.seq)
        assertEquals(ListPhase.LOADING, three.phase)
    }

    @Test
    fun searchIsCappedAtWhatTheServerAccepts() {
        assertEquals(MAX_SEARCH_CHARACTERS, run(intents = arrayOf(OrderListIntent.QueryChanged("x".repeat(80)))).queryText.length)
    }

    @Test
    fun submitWithTooFewCharactersDoesNothing() {
        val typed = run(intents = arrayOf(OrderListIntent.QueryChanged("ab")))
        assertEquals(typed, reduceOrderList(typed, OrderListIntent.SubmitSearch))
    }

    @Test
    fun staleAnswersAreIgnored() {
        val s = run(intents = arrayOf(OrderListIntent.SelectFilter(StatusFilter.NEW)))
        val stale = reduceOrderList(s, OrderListIntent.Loaded(seq = s.seq - 1, page = page("BT-1"), append = false))
        assertEquals(s, stale)
    }

    @Test
    fun pagingAppendsWithoutRepeatingRows() {
        val first = run(intents = arrayOf(OrderListIntent.Refresh))
        val loaded = reduceOrderList(first, OrderListIntent.Loaded(first.seq, page("BT-1", "BT-2", next = "c"), false))
        val more = reduceOrderList(loaded, OrderListIntent.LoadMore)
        assertTrue(more.loadingMore)
        val done = reduceOrderList(more, OrderListIntent.Loaded(more.seq, page("BT-2", "BT-3"), true))
        assertEquals(listOf("BT-1", "BT-2", "BT-3"), done.rows.map { it.orderCode })
        assertEquals(3, done.unfinishedCount)
        assertFalse(done.loadingMore)
    }

    @Test
    fun failedPageKeepsEarlierRowsAndOffersRetry() {
        val loaded = run(intents = arrayOf(OrderListIntent.Refresh)).let { reduceOrderList(it, OrderListIntent.Loaded(it.seq, page("BT-1", next = "c"), false)) }
        val more = reduceOrderList(loaded, OrderListIntent.LoadMore)
        val failed = reduceOrderList(more, OrderListIntent.Failed(more.seq, offline = true, append = true))
        assertEquals(1, failed.rows.size)
        assertTrue(failed.loadMoreFailed)
    }

    @Test
    fun failedReloadShowsNoOldRowsAsCurrent() {
        val loaded = run(intents = arrayOf(OrderListIntent.Refresh)).let { reduceOrderList(it, OrderListIntent.Loaded(it.seq, page("BT-1"), false)) }
        val refreshing = reduceOrderList(loaded, OrderListIntent.Refresh)
        assertTrue(refreshing.refreshing)
        assertEquals(1, refreshing.rows.size)
        val failed = reduceOrderList(refreshing, OrderListIntent.Failed(refreshing.seq, offline = true, append = false))
        assertTrue(failed.rows.isEmpty())
        assertEquals(ListPhase.OFFLINE, failed.phase)
    }

    @Test
    fun clearFiltersGoesBackToToDo() {
        val s = run(intents = arrayOf(OrderListIntent.SelectFilter(StatusFilter.ALL), OrderListIntent.SelectDate(DateFilter.Today), OrderListIntent.QueryChanged("abc")))
        assertTrue(s.hasFilters)
        val cleared = reduceOrderList(s, OrderListIntent.ClearFilters)
        assertFalse(cleared.hasFilters)
        assertEquals("", cleared.queryText)
    }
}
