package app.banh.admin.orderdetail

import app.banh.core.model.CancelReason
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus

enum class DetailPhase { LOADING, READY, GONE, ERROR, OFFLINE }

/** The action whose request is running; its button shows a spinner and the other is disabled (S-A4 Disabled). */
enum class BusyAction { CONFIRM, COMPLETE, CANCEL }

/** The message above the action bar. */
sealed interface DetailBanner {
    /** The order changed under the person (FR-19): shows the status it has now. */
    data class Conflict(val status: OrderStatus) : DetailBanner

    data object ActionError : DetailBanner

    data object ActionOffline : DetailBanner
}

data class OrderDetailState(
    val orderCode: String,
    val phase: DetailPhase = DetailPhase.LOADING,
    val detail: OrderDetail? = null,
    val busy: BusyAction? = null,
    val completeDialog: Boolean = false,
    val cancelSheet: Boolean = false,
    val reason: CancelReason? = null,
    val banner: DetailBanner? = null,
    /** True for a moment after a successful change: the screen shows `A_STATUS_CHANGED` and clears it with [OrderDetailIntent.ToastShown]. */
    val statusToast: Boolean = false,
) {
    val canConfirm: Boolean get() = detail?.status == OrderStatus.New
    val canComplete: Boolean get() = detail?.status == OrderStatus.Confirmed
    val canCancel: Boolean get() = detail?.status?.isOpen == true
    val hasActions: Boolean get() = canCancel
}

sealed interface OrderDetailIntent {
    data object Load : OrderDetailIntent

    data class Loaded(val detail: OrderDetail) : OrderDetailIntent

    data class LoadFailed(val phase: DetailPhase) : OrderDetailIntent

    data object TapConfirm : OrderDetailIntent

    data object TapComplete : OrderDetailIntent

    data object CompleteYes : OrderDetailIntent

    data object CompleteBack : OrderDetailIntent

    data object TapCancel : OrderDetailIntent

    data class SelectReason(val reason: CancelReason) : OrderDetailIntent

    data object CancelConfirm : OrderDetailIntent

    data object CancelBack : OrderDetailIntent

    data class Changed(val detail: OrderDetail) : OrderDetailIntent

    data class Conflicted(val current: OrderDetail) : OrderDetailIntent

    data class ChangeFailed(val banner: DetailBanner) : OrderDetailIntent

    data object Gone : OrderDetailIntent

    data object ToastShown : OrderDetailIntent
}
