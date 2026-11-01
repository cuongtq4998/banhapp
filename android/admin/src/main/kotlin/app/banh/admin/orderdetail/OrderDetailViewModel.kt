package app.banh.admin.orderdetail

import app.banh.admin.auth.SessionEndedException
import app.banh.admin.orders.OrderChanges
import app.banh.admin.orders.OrdersApi
import app.banh.admin.orders.StatusChange
import app.banh.core.common.MviViewModel
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderStatus
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import kotlinx.coroutines.CancellationException

class OrderDetailViewModel(
    orderCode: String,
    private val api: OrdersApi,
    private val changes: OrderChanges,
) : MviViewModel<OrderDetailState, OrderDetailIntent, Nothing>(OrderDetailState(orderCode)) {
    // The reducer ignores a second tap while busy, but `handle` still runs; one request at a time keeps a double tap harmless.
    private var working = false

    init {
        dispatch(OrderDetailIntent.Load)
    }

    override fun reduce(state: OrderDetailState, intent: OrderDetailIntent): OrderDetailState = reduceOrderDetail(state, intent)

    override suspend fun handle(intent: OrderDetailIntent) {
        when (intent) {
            OrderDetailIntent.Load -> load()
            OrderDetailIntent.TapConfirm -> if (current.busy == BusyAction.CONFIRM) change(OrderStatus.Confirmed, null)
            OrderDetailIntent.CompleteYes -> if (current.busy == BusyAction.COMPLETE) change(OrderStatus.Completed, null)
            OrderDetailIntent.CancelConfirm -> if (current.busy == BusyAction.CANCEL) change(OrderStatus.Cancelled, current.reason)
            else -> Unit
        }
    }

    private suspend fun load() {
        try {
            dispatch(OrderDetailIntent.Loaded(api.detail(current.orderCode)))
        } catch (e: CancellationException) {
            throw e
        } catch (_: SessionEndedException) {
            Unit
        } catch (e: ApiException) {
            dispatch(OrderDetailIntent.LoadFailed(loadPhaseOf(e)))
        }
    }

    private suspend fun change(to: OrderStatus, reason: CancelReason?) {
        val expected = current.detail?.status ?: return
        if (working) return
        working = true
        try {
            when (val result = api.changeStatus(current.orderCode, expected, to, reason)) {
                is StatusChange.Changed -> dispatch(OrderDetailIntent.Changed(result.detail)).also { changes.notifyChanged() }
                is StatusChange.Conflict -> dispatch(OrderDetailIntent.Conflicted(result.current)).also { changes.notifyChanged() }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (_: SessionEndedException) {
            Unit
        } catch (e: ApiException) {
            dispatch(failureOf(e))
        } finally {
            working = false
        }
    }

    private fun loadPhaseOf(e: ApiException): DetailPhase = when {
        e is ApiException.Http && e.code == ErrorCodes.ORDER_NOT_FOUND -> DetailPhase.GONE
        e.isOffline -> DetailPhase.OFFLINE
        else -> DetailPhase.ERROR
    }

    private fun failureOf(e: ApiException): OrderDetailIntent = when {
        e is ApiException.Http && e.code == ErrorCodes.ORDER_NOT_FOUND -> OrderDetailIntent.Gone
        e.isOffline -> OrderDetailIntent.ChangeFailed(DetailBanner.ActionOffline)
        else -> OrderDetailIntent.ChangeFailed(DetailBanner.ActionError)
    }
}
