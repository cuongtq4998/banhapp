package app.banh.admin.orderlist

import app.banh.admin.orders.OrderChanges
import app.banh.admin.orders.OrdersApi
import app.banh.admin.orders.ServerDateHolder
import app.banh.admin.auth.SessionEndedException
import app.banh.core.common.MviViewModel
import app.banh.core.network.ApiException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

private const val SEARCH_DEBOUNCE_MILLIS = 300L

/** Returning from the background reloads after more than 60 s (FR-12). */
private const val STALE_AFTER_MILLIS = 60_000L

class OrderListViewModel(
    private val api: OrdersApi,
    changes: OrderChanges,
    private val serverDate: ServerDateHolder,
    private val now: () -> Long = System::currentTimeMillis,
) : MviViewModel<OrderListState, OrderListIntent, Nothing>(OrderListState()) {
    private var lastLoadMillis: Long? = null
    private var debounce: Job? = null

    init {
        // A status change on S-A4 reloads the list and the badge at once.
        scope.launch { changes.version.drop(1).collect { dispatch(OrderListIntent.Refresh) } }
    }

    override fun reduce(state: OrderListState, intent: OrderListIntent): OrderListState = reduceOrderList(state, intent)

    override suspend fun handle(intent: OrderListIntent) {
        when (intent) {
            is OrderListIntent.Resumed -> resume(intent.nowMillis)
            OrderListIntent.Refresh, is OrderListIntent.SelectFilter, is OrderListIntent.SelectDate, OrderListIntent.ClearFilters -> load(append = false)
            OrderListIntent.SubmitSearch -> if (current.searchText.isNotEmpty()) load(append = false)
            is OrderListIntent.QueryChanged -> reloadAfterTyping()
            OrderListIntent.LoadMore -> if (current.loadingMore) load(append = true)
            else -> Unit
        }
    }

    private fun resume(nowMillis: Long) {
        val last = lastLoadMillis
        if (last == null || nowMillis - last > STALE_AFTER_MILLIS) dispatch(OrderListIntent.Refresh)
    }

    // Typing sends one request when the person pauses, and only if the reducer decided the sent text changed.
    private fun reloadAfterTyping() {
        debounce?.cancel()
        val seq = current.seq
        debounce = scope.launch {
            delay(SEARCH_DEBOUNCE_MILLIS)
            if (current.seq == seq && current.phase == ListPhase.LOADING) load(append = false)
        }
    }

    private suspend fun load(append: Boolean) {
        val seq = current.seq
        val cursor = if (append) current.nextCursor else null
        try {
            val page = api.list(current.query, cursor)
            lastLoadMillis = now()
            serverDate.update(page.serverDate)
            dispatch(OrderListIntent.Loaded(seq, page, append))
        } catch (e: CancellationException) {
            throw e
        } catch (_: SessionEndedException) {
            Unit
        } catch (e: ApiException) {
            dispatch(OrderListIntent.Failed(seq, e.isOffline, append))
        }
    }
}
