package app.banh.admin.orderdetail

import app.banh.admin.orders.OrderRuleError
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail

/** Pure transitions of the detail screen and its sheets (FR-16 to FR-19, FR-28 to FR-30). */
fun reduceOrderDetail(state: OrderDetailState, intent: OrderDetailIntent): OrderDetailState = when (intent) {
    OrderDetailIntent.Load -> state.copy(phase = DetailPhase.LOADING, banner = null)
    is OrderDetailIntent.Loaded -> state.copy(phase = DetailPhase.READY, detail = intent.detail)
    is OrderDetailIntent.LoadFailed -> state.copy(phase = intent.phase, detail = null)
    is OrderDetailIntent.Tap -> if (state.busy == null && state.allows(intent.action)) tap(state, intent.action) else state
    OrderDetailIntent.FinishYes -> if (state.sheet == DetailSheet.FinishDialog && state.busy == null) {
        state.copy(sheet = null, busy = BusyAction.FINISH)
    } else {
        state
    }
    is OrderDetailIntent.SelectReason -> editSheet<DetailSheet.Cancel>(state) { it.copy(reason = intent.reason) }
    is OrderDetailIntent.PickDate -> editSheet<DetailSheet.Date>(state) { it.copy(picked = intent.date, error = null) }
    is OrderDetailIntent.EditFee -> editFee(state, intent.text.filter(Char::isDigit))
    OrderDetailIntent.Submit -> submit(state)
    OrderDetailIntent.SheetBack -> if (state.busy == null) state.copy(sheet = null) else state
    is OrderDetailIntent.Changed -> settled(state, intent.detail).copy(toast = true)
    // Open sheets close and the current order shows with a warning (FR-19).
    is OrderDetailIntent.Conflicted -> settled(state, intent.current).copy(banner = DetailBanner.Conflict(intent.current.status))
    is OrderDetailIntent.Refused -> refused(state, intent.error)
    is OrderDetailIntent.ChangeFailed -> state.copy(busy = null, banner = intent.banner)
    OrderDetailIntent.Gone -> state.copy(phase = DetailPhase.GONE, detail = null, busy = null, sheet = null)
    OrderDetailIntent.ToastShown -> state.copy(toast = false)
}

private fun tap(state: OrderDetailState, action: OrderAction): OrderDetailState = when (action) {
    OrderAction.PROCESS -> state.copy(busy = BusyAction.PROCESS, banner = null)
    OrderAction.FINISH -> state.copy(sheet = DetailSheet.FinishDialog, banner = null)
    OrderAction.CANCEL -> state.copy(sheet = DetailSheet.Cancel(), banner = null)
    OrderAction.SCHEDULE_DELIVERY -> state.copy(sheet = DetailSheet.Date(change = false), banner = null)
    OrderAction.CHANGE_DATE -> state.copy(sheet = DetailSheet.Date(change = true), banner = null)
    OrderAction.START_DELIVERY -> state.copy(sheet = DetailSheet.Fee(), banner = null)
    OrderAction.CORRECT_FEE -> state.copy(sheet = DetailSheet.FeeCorrection(), banner = null)
}

private inline fun <reified S : DetailSheet> editSheet(state: OrderDetailState, edit: (S) -> S): OrderDetailState {
    val sheet = state.sheet as? S ?: return state
    return if (state.busy == null) state.copy(sheet = edit(sheet)) else state
}

private fun editFee(state: OrderDetailState, text: String): OrderDetailState = when (state.sheet) {
    is DetailSheet.Fee -> editSheet<DetailSheet.Fee>(state) { it.copy(text = text, error = null) }
    is DetailSheet.FeeCorrection -> editSheet<DetailSheet.FeeCorrection>(state) { it.copy(text = text, error = null) }
    else -> state
}

// The sheet stays open while the request runs so a refusal can show beside the field.
private fun submit(state: OrderDetailState): OrderDetailState {
    if (state.busy != null) return state
    return when (val sheet = state.sheet) {
        is DetailSheet.Cancel -> if (sheet.reason != null) state.copy(busy = BusyAction.CANCEL, banner = null) else state
        is DetailSheet.Date -> if (!state.canSaveDate) state else state.copy(busy = if (sheet.change) BusyAction.CHANGE_DATE else BusyAction.SCHEDULE)
        is DetailSheet.Fee -> if (state.canSaveFee) state.copy(busy = BusyAction.START_DELIVERY) else state
        is DetailSheet.FeeCorrection -> if (state.canSaveFeeCorrection) state.copy(busy = BusyAction.CORRECT_FEE) else state
        else -> state
    }
}

private fun refused(state: OrderDetailState, error: OrderRuleError): OrderDetailState {
    val open = state.copy(busy = null)
    return when (val sheet = state.sheet) {
        is DetailSheet.Date -> open.copy(sheet = sheet.copy(error = error), detail = open.detail?.withRange(error))
        is DetailSheet.Fee -> open.copy(sheet = sheet.copy(error = error))
        is DetailSheet.FeeCorrection -> open.copy(sheet = sheet.copy(error = error))
        else -> open.copy(sheet = null, banner = DetailBanner.Rule(error))
    }
}

// The refusal carries a fresher window than the loaded detail (the day may have turned).
private fun OrderDetail.withRange(error: OrderRuleError): OrderDetail {
    val range = (error as? OrderRuleError.DatePast)?.range ?: (error as? OrderRuleError.DateTooFar)?.range
    return if (range == null) this else copy(expectedDateRange = range)
}

private fun settled(state: OrderDetailState, detail: OrderDetail): OrderDetailState =
    state.copy(phase = DetailPhase.READY, detail = detail, busy = null, sheet = null, banner = null)
