package app.banh.admin.orderdetail

/** Pure transitions of S-A4 and S-A5. Rules: confirm is one tap, complete asks once, cancel needs a reason (FR-16 to FR-18). */
fun reduceOrderDetail(state: OrderDetailState, intent: OrderDetailIntent): OrderDetailState = when (intent) {
    OrderDetailIntent.Load -> state.copy(phase = DetailPhase.LOADING, banner = null)
    is OrderDetailIntent.Loaded -> state.copy(phase = DetailPhase.READY, detail = intent.detail)
    is OrderDetailIntent.LoadFailed -> state.copy(phase = intent.phase, detail = null)
    OrderDetailIntent.TapConfirm -> if (state.canConfirm && state.busy == null) state.copy(busy = BusyAction.CONFIRM, banner = null) else state
    OrderDetailIntent.TapComplete -> if (state.canComplete && state.busy == null) state.copy(completeDialog = true, banner = null) else state
    OrderDetailIntent.CompleteYes -> if (state.completeDialog && state.busy == null) state.copy(completeDialog = false, busy = BusyAction.COMPLETE) else state
    OrderDetailIntent.CompleteBack -> state.copy(completeDialog = false)
    OrderDetailIntent.TapCancel -> if (state.canCancel && state.busy == null) state.copy(cancelSheet = true, reason = null, banner = null) else state
    is OrderDetailIntent.SelectReason -> if (state.busy == null) state.copy(reason = intent.reason) else state
    OrderDetailIntent.CancelConfirm -> if (state.reason != null && state.busy == null) state.copy(busy = BusyAction.CANCEL, banner = null) else state
    OrderDetailIntent.CancelBack -> if (state.busy == null) state.copy(cancelSheet = false, reason = null) else state
    is OrderDetailIntent.Changed -> settled(state, intent.detail).copy(statusToast = true)
    // Open sheets and dialogs close and the current status shows with a warning (FR-19).
    is OrderDetailIntent.Conflicted -> settled(state, intent.current).copy(banner = DetailBanner.Conflict(intent.current.status))
    is OrderDetailIntent.ChangeFailed -> state.copy(busy = null, banner = intent.banner)
    OrderDetailIntent.Gone -> state.copy(phase = DetailPhase.GONE, detail = null, busy = null, completeDialog = false, cancelSheet = false)
    OrderDetailIntent.ToastShown -> state.copy(statusToast = false)
}

private fun settled(state: OrderDetailState, detail: app.banh.core.model.OrderDetail): OrderDetailState = state.copy(
    phase = DetailPhase.READY,
    detail = detail,
    busy = null,
    completeDialog = false,
    cancelSheet = false,
    reason = null,
    banner = null,
)
