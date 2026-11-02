package app.banh.admin.stub

import app.banh.core.model.DateChange
import app.banh.core.model.DeliveryFeeEntry
import app.banh.core.model.FeeCorrection
import app.banh.core.model.LastChange
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.StatusChangeRequest
import java.time.LocalDate

internal const val STUB_NOW = "2026-11-02T04:00:00Z"
internal const val TRANSITION_STATUS = 422
internal const val VALIDATION_STATUS = 422
// A null result of a rule is "fine"; takeIf keeps it from falling through to the required error.
private const val FEE_REQUIRED = "error-validation-fee-required"
private const val DATE_REQUIRED = "error-validation-expected-date-past"
private const val MAX_FEE_VND = 10_000_000L
private const val RANGE_DAYS = 7L

/** The moves api/09 10.13.1 allows; cancel stops after Processing. */
internal fun allowedTargets(status: OrderStatus): List<OrderStatus> = when (status) {
    OrderStatus.Received -> listOf(OrderStatus.Processing, OrderStatus.Cancelled)
    OrderStatus.Processing -> listOf(OrderStatus.DeliveryDateScheduled, OrderStatus.Cancelled)
    OrderStatus.DeliveryDateScheduled -> listOf(OrderStatus.DeliveryStarted)
    OrderStatus.DeliveryStarted -> listOf(OrderStatus.Finished)
    else -> emptyList()
}

/** `allowed_actions` by status, in the table order of api/09 10.13.7. */
internal fun actions(status: OrderStatus): List<OrderAction> = when (status) {
    OrderStatus.Received -> listOf(OrderAction.CANCEL, OrderAction.PROCESS)
    OrderStatus.Processing -> listOf(OrderAction.CANCEL, OrderAction.SCHEDULE_DELIVERY)
    OrderStatus.DeliveryDateScheduled -> listOf(OrderAction.CHANGE_DATE, OrderAction.START_DELIVERY)
    OrderStatus.DeliveryStarted -> listOf(OrderAction.CORRECT_FEE, OrderAction.FINISH)
    else -> emptyList()
}

/** The error fixture for a body that breaks the extras rules of its target, or null. */
internal fun refusalOf(request: StatusChangeRequest, today: String): String? = when (request.toStatus) {
    OrderStatus.Cancelled -> if (request.cancelReason == null) "error-cancel-reason-required" else null
    OrderStatus.DeliveryDateScheduled -> request.expectedDeliveryDate?.let { dateRefusal(it, today) } ?: DATE_REQUIRED.takeIf { request.expectedDeliveryDate == null }
    OrderStatus.DeliveryStarted -> request.deliveryFeeVnd?.let(::feeRefusal) ?: FEE_REQUIRED.takeIf { request.deliveryFeeVnd == null }
    else -> null
}

/** Shop today to today + 7, inclusive. */
internal fun dateRefusal(date: String, today: String): String? {
    val day = LocalDate.parse(date)
    val first = LocalDate.parse(today)
    return when {
        day.isBefore(first) -> "error-validation-expected-date-past"
        day.isAfter(first.plusDays(RANGE_DAYS)) -> "error-validation-expected-date-too-far"
        else -> null
    }
}

/** A fee of 0 is valid: delivery can be free. */
internal fun feeRefusal(fee: Long): String? = if (fee < 0 || fee > MAX_FEE_VND) "error-validation-fee-invalid" else null

internal fun OrderDetail.withDate(date: String, actor: String) = copy(
    expectedDeliveryDate = date,
    listDate = date,
    dateChanges = dateChanges + DateChange(expectedDeliveryDate.orEmpty(), date, actor, STUB_NOW),
    lastChange = LastChange(actor, STUB_NOW, "date"),
)

internal fun OrderDetail.withFee(fee: Long, actor: String) = copy(
    deliveryFeeFinalVnd = fee,
    deliveryFeeVnd = fee,
    amountToCollectVnd = itemsSubtotalVnd + fee,
    feeCorrections = feeCorrections + FeeCorrection(deliveryFeeFinalVnd ?: 0, fee, actor, STUB_NOW),
    lastChange = LastChange(actor, STUB_NOW, "fee"),
)

internal fun OrderDetail.withEnteredFee(fee: Long, actor: String) = copy(
    deliveryFeeFinalVnd = fee,
    deliveryFeeVnd = fee,
    amountToCollectVnd = itemsSubtotalVnd + fee,
    deliveryFeeEntry = DeliveryFeeEntry(actor, STUB_NOW),
)
