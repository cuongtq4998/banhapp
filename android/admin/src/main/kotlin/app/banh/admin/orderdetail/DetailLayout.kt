package app.banh.admin.orderdetail

import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus

enum class StepState { DONE, CURRENT, NEXT }

/** The five stepper rows from the status; null for Cancelled and unknown words, which do not use the stepper. */
fun stepStatesOf(status: OrderStatus): List<StepState>? {
    val current = when (status) {
        OrderStatus.Received -> 0
        OrderStatus.Processing -> 1
        OrderStatus.DeliveryDateScheduled -> 2
        OrderStatus.DeliveryStarted -> 3
        // Past the last row: every row is done.
        OrderStatus.Finished -> STEP_COUNT
        OrderStatus.Cancelled, is OrderStatus.Unknown -> return null
    }
    return List(STEP_COUNT) { index ->
        when {
            index < current -> StepState.DONE
            index == current -> StepState.CURRENT
            else -> StepState.NEXT
        }
    }
}

const val STEP_COUNT = 5

/** The bar buttons in order: the left one, then the forward one; empty entries are absent, never disabled. */
data class BarActions(val left: OrderAction?, val right: OrderAction?)

// Only the server list decides; the status never adds a button.
fun barActionsOf(allowed: List<OrderAction>): BarActions = BarActions(
    left = LEFT_ACTIONS.firstOrNull { it in allowed },
    right = RIGHT_ACTIONS.firstOrNull { it in allowed },
)

private val LEFT_ACTIONS = listOf(OrderAction.CANCEL, OrderAction.CHANGE_DATE)
private val RIGHT_ACTIONS = listOf(OrderAction.PROCESS, OrderAction.SCHEDULE_DELIVERY, OrderAction.START_DELIVERY, OrderAction.FINISH)

/** True when the Info message names why cancel is gone (from the scheduled step on). */
fun OrderDetailState.cancelBlocked(): Boolean {
    val status = detail?.status
    return (status == OrderStatus.DeliveryDateScheduled || status == OrderStatus.DeliveryStarted) && !allows(OrderAction.CANCEL)
}

/** The fee row of the cakes card. */
sealed interface FeeRow {
    /** Before the real fee is typed; [estimateVnd] is the district estimate when known. */
    data class Pending(val estimateVnd: Long?) : FeeRow

    data object Free : FeeRow

    data class Amount(val vnd: Long) : FeeRow
}

fun feeRowOf(detail: OrderDetail): FeeRow {
    val fee = detail.deliveryFeeFinalVnd ?: return FeeRow.Pending(detail.deliveryFeeEstimateVnd)
    return if (fee == 0L) FeeRow.Free else FeeRow.Amount(fee)
}

/** Shown only when the server sent an amount; the app never sums it. */
fun amountToCollectOf(detail: OrderDetail): Long? = detail.amountToCollectVnd
