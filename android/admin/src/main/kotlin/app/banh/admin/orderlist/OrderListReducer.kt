package app.banh.admin.orderlist

import app.banh.admin.orders.DateFilter
import app.banh.admin.orders.StatusFilter

/** Pure transitions of S-A3. The store starts the request that matches the new [OrderListState.seq]. */
fun reduceOrderList(state: OrderListState, intent: OrderListIntent): OrderListState = when (intent) {
    is OrderListIntent.Resumed -> state
    OrderListIntent.Refresh -> restart(state, keepRows = true)
    is OrderListIntent.SelectFilter -> restart(state.copy(filter = intent.filter), keepRows = false)
    is OrderListIntent.SelectDate -> restart(state.copy(date = intent.date), keepRows = false)
    is OrderListIntent.QueryChanged -> changeQuery(state, intent.text)
    OrderListIntent.SubmitSearch -> if (state.searchText.isEmpty()) state else restart(state, keepRows = false)
    OrderListIntent.ClearFilters -> restart(state.copy(filter = StatusFilter.TODO, date = DateFilter.Any, queryText = ""), keepRows = false)
    OrderListIntent.LoadMore ->
        if (state.nextCursor != null && state.phase == ListPhase.READY && !state.loadingMore) state.copy(loadingMore = true, loadMoreFailed = false) else state
    is OrderListIntent.Loaded -> if (intent.seq == state.seq) applyPage(state, intent) else state
    is OrderListIntent.Failed -> if (intent.seq == state.seq) applyFailure(state, intent) else state
}

private fun changeQuery(state: OrderListState, text: String): OrderListState {
    val next = state.copy(queryText = text.take(MAX_SEARCH_CHARACTERS))
    // Typing below 3 characters changes nothing on the list; crossing the limit or changing the sent text reloads.
    return if (next.searchText == state.searchText) next else restart(next, keepRows = false)
}

private fun restart(state: OrderListState, keepRows: Boolean): OrderListState {
    val showOld = keepRows && state.rows.isNotEmpty()
    return state.copy(
        seq = state.seq + 1,
        phase = if (showOld) ListPhase.READY else ListPhase.LOADING,
        refreshing = showOld,
        rows = if (showOld) state.rows else emptyList(),
        nextCursor = if (showOld) state.nextCursor else null,
        loadingMore = false,
        loadMoreFailed = false,
    )
}

private fun applyPage(state: OrderListState, loaded: OrderListIntent.Loaded): OrderListState {
    val known = state.rows.mapTo(HashSet()) { it.orderCode }
    val rows = if (loaded.append) state.rows + loaded.page.items.filter { it.orderCode !in known } else loaded.page.items
    return state.copy(
        rows = rows,
        nextCursor = loaded.page.nextCursor,
        unfinishedCount = loaded.page.unfinishedCount,
        serverDate = loaded.page.serverDate,
        phase = ListPhase.READY,
        refreshing = false,
        loadingMore = false,
        loadMoreFailed = false,
    )
}

private fun applyFailure(state: OrderListState, failed: OrderListIntent.Failed): OrderListState = when {
    failed.append -> state.copy(loadingMore = false, loadMoreFailed = true)
    // No earlier rows are shown as current after a failed reload (AC-20).
    else -> state.copy(rows = emptyList(), nextCursor = null, refreshing = false, phase = if (failed.offline) ListPhase.OFFLINE else ListPhase.ERROR)
}
