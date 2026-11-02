package app.banh.admin.orderlist

import app.banh.admin.orders.DateFilter
import app.banh.admin.orders.OrdersQuery
import app.banh.admin.orders.StatusFilter
import app.banh.core.model.OrderSummary
import app.banh.core.model.OrdersPage

enum class ListPhase { LOADING, READY, ERROR, OFFLINE }

const val MIN_SEARCH_CHARACTERS = 3

// The server accepts 3 to 50 characters (api/06 10.9); the UI document said 100, the API is the limit that counts.
const val MAX_SEARCH_CHARACTERS = 50

data class OrderListState(
    val filter: StatusFilter = StatusFilter.TODO,
    val date: DateFilter = DateFilter.Any,
    val queryText: String = "",
    val rows: List<OrderSummary> = emptyList(),
    val nextCursor: String? = null,
    val unfinishedCount: Int = 0,
    val serverDate: String? = null,
    val phase: ListPhase = ListPhase.LOADING,
    /** An older list stays on screen while a pull-to-refresh runs. */
    val refreshing: Boolean = false,
    val loadingMore: Boolean = false,
    val loadMoreFailed: Boolean = false,
    /** Identifies the latest request; an answer with another number is stale and ignored. */
    val seq: Int = 0,
) {
    /** The search that is sent: at least 3 characters (BR-10), else none. */
    val searchText: String get() = queryText.trim().takeIf { it.length >= MIN_SEARCH_CHARACTERS }.orEmpty()

    val searchTooShort: Boolean get() = queryText.trim().length in 1 until MIN_SEARCH_CHARACTERS

    val query: OrdersQuery get() = OrdersQuery(filter, date, searchText)

    /** Something other than the default "To do" is set, so the empty state offers `A_CLEAR_FILTERS`. */
    val hasFilters: Boolean get() = filter != StatusFilter.TODO || date != DateFilter.Any
}

sealed interface OrderListIntent {
    /** The screen came back and the data may be old; the store decides (60 s rule, FR-12). */
    data class Resumed(val nowMillis: Long) : OrderListIntent

    data object Refresh : OrderListIntent

    data class SelectFilter(val filter: StatusFilter) : OrderListIntent

    data class SelectDate(val date: DateFilter) : OrderListIntent

    data class QueryChanged(val text: String) : OrderListIntent

    data object SubmitSearch : OrderListIntent

    data object ClearFilters : OrderListIntent

    data object LoadMore : OrderListIntent

    data class Loaded(val seq: Int, val page: OrdersPage, val append: Boolean) : OrderListIntent

    data class Failed(val seq: Int, val offline: Boolean, val append: Boolean) : OrderListIntent
}
