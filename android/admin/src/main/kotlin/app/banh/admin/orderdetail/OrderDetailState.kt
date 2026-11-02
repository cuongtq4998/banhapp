package app.banh.admin.orderdetail

import app.banh.admin.orders.OrderRuleError
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus

const val MIN_FEE_VND = 0L
const val MAX_FEE_VND = 10_000_000L

enum class DetailPhase { LOADING, READY, GONE, ERROR, OFFLINE }

/** The action whose request is running; its button shows a spinner and the others are disabled. */
enum class BusyAction { PROCESS, FINISH, CANCEL, SCHEDULE, START_DELIVERY, CHANGE_DATE, CORRECT_FEE }

/** The message above the action bar. */
sealed interface DetailBanner {
    /** The order changed under the person (FR-19): shows what it is now. */
    data class Conflict(val status: OrderStatus) : DetailBanner

    /** A fee correction lost a race while the order is still on the delivery step: names the fee now stored. */
    data class FeeConflict(val feeVnd: Long) : DetailBanner

    data class Rule(val error: OrderRuleError) : DetailBanner

    data object ActionError : DetailBanner

    data object ActionOffline : DetailBanner
}

/** The one open sheet or dialog; at most one at a time. */
sealed interface DetailSheet {
    data object FinishDialog : DetailSheet

    data class Cancel(val reason: CancelReason? = null) : DetailSheet

    /** [change] is true when the date is moved (DeliveryDateScheduled), false when first scheduled. */
    data class Date(val change: Boolean, val picked: String? = null, val error: OrderRuleError? = null) : DetailSheet

    /** Start delivery; the fee is typed with no prefill. */
    data class Fee(val text: String = "", val error: OrderRuleError? = null) : DetailSheet

    data class FeeCorrection(val text: String = "", val error: OrderRuleError? = null) : DetailSheet
}

data class OrderDetailState(
    val orderCode: String,
    val phase: DetailPhase = DetailPhase.LOADING,
    val detail: OrderDetail? = null,
    val busy: BusyAction? = null,
    val sheet: DetailSheet? = null,
    val banner: DetailBanner? = null,
    /** True for a moment after a successful change; the screen clears it with [OrderDetailIntent.ToastShown]. */
    val toast: Boolean = false,
) {
    /** Actions come only from the server list; the app never derives them from the status. */
    fun allows(action: OrderAction): Boolean = detail?.allowedActions?.contains(action) == true

    val hasActions: Boolean get() = detail?.allowedActions?.isNotEmpty() == true

    /** The date the server shows now, used to refuse an unchanged date. */
    private val currentDate: String? get() = detail?.expectedDeliveryDate

    val canSaveDate: Boolean
        get() {
            val date = (sheet as? DetailSheet.Date) ?: return false
            val range = detail?.expectedDateRange ?: return false
            val picked = date.picked ?: return false
            return picked >= range.min && picked <= range.max && (!date.change || picked != currentDate)
        }

    val canSaveFee: Boolean get() = (sheet as? DetailSheet.Fee)?.text?.let(::feeOf) != null

    val canSaveFeeCorrection: Boolean
        get() {
            val fee = (sheet as? DetailSheet.FeeCorrection)?.text?.let(::feeOf) ?: return false
            return fee != detail?.deliveryFeeFinalVnd
        }
}

/** The fee typed so far; null while empty, not whole, or outside the allowed range. */
fun feeOf(text: String): Long? = text.toLongOrNull()?.takeIf { it in MIN_FEE_VND..MAX_FEE_VND }

sealed interface OrderDetailIntent {
    data object Load : OrderDetailIntent

    data class Loaded(val detail: OrderDetail) : OrderDetailIntent

    data class LoadFailed(val phase: DetailPhase) : OrderDetailIntent

    /** A button of the bar; ignored unless the server allowed it. */
    data class Tap(val action: OrderAction) : OrderDetailIntent

    data object FinishYes : OrderDetailIntent

    data class SelectReason(val reason: CancelReason) : OrderDetailIntent

    data class PickDate(val date: String) : OrderDetailIntent

    data class EditFee(val text: String) : OrderDetailIntent

    /** Save of the date or fee sheet, or confirm of the cancel sheet. */
    data object Submit : OrderDetailIntent

    data object SheetBack : OrderDetailIntent

    data class Changed(val detail: OrderDetail) : OrderDetailIntent

    data class Conflicted(val current: OrderDetail) : OrderDetailIntent

    data class Refused(val error: OrderRuleError) : OrderDetailIntent

    data class ChangeFailed(val banner: DetailBanner) : OrderDetailIntent

    data object Gone : OrderDetailIntent

    data object ToastShown : OrderDetailIntent
}
