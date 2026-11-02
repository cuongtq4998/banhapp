package app.banh.admin.orderdetail

import app.banh.admin.auth.SessionEndedException
import app.banh.admin.orders.OrderChanges
import app.banh.admin.orders.OrdersApi
import app.banh.admin.orders.StatusChange
import app.banh.core.common.MviViewModel
import app.banh.admin.orders.toRuleError
import app.banh.core.model.OrderDetail
import app.banh.core.network.ApiJson
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
        if (intent == OrderDetailIntent.Load) return load()
        val request = requestFor(current.busy, current.sheet) ?: return
        change(request)
    }

    // Only the reducer starts work (it sets `busy`); this turns that state into the one request to send.
    private fun requestFor(busy: BusyAction?, sheet: DetailSheet?): (suspend (OrderDetail) -> StatusChange)? {
        val code = current.orderCode
        return when (busy) {
            null -> null
            BusyAction.PROCESS -> { d -> api.changeStatus(code, d.status, OrderStatus.Processing) }
            BusyAction.FINISH -> { d -> api.changeStatus(code, d.status, OrderStatus.Finished) }
            BusyAction.CANCEL -> { d -> api.changeStatus(code, d.status, OrderStatus.Cancelled, (sheet as? DetailSheet.Cancel)?.reason) }
            BusyAction.SCHEDULE -> { d -> api.changeStatus(code, d.status, OrderStatus.DeliveryDateScheduled, expectedDate = (sheet as DetailSheet.Date).picked) }
            BusyAction.START_DELIVERY -> { d -> api.changeStatus(code, d.status, OrderStatus.DeliveryStarted, feeVnd = feeOf((sheet as DetailSheet.Fee).text)) }
            BusyAction.CHANGE_DATE -> { d -> api.changeExpectedDate(code, d.expectedDeliveryDate.orEmpty(), (sheet as DetailSheet.Date).picked.orEmpty()) }
            BusyAction.CORRECT_FEE -> { d -> api.correctFee(code, d.deliveryFeeFinalVnd ?: 0L, feeOf((sheet as DetailSheet.FeeCorrection).text) ?: 0L) }
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

    private suspend fun change(request: suspend (OrderDetail) -> StatusChange) {
        val detail = current.detail ?: return
        if (working) return
        working = true
        try {
            when (val result = request(detail)) {
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
        e is ApiException.Http && e.toRuleError(ApiJson) != null -> OrderDetailIntent.Refused(e.toRuleError(ApiJson)!!)
        e.isOffline -> OrderDetailIntent.ChangeFailed(DetailBanner.ActionOffline)
        else -> OrderDetailIntent.ChangeFailed(DetailBanner.ActionError)
    }
}
