package app.banh.admin.orderdetail

import app.banh.admin.orders.OrderRuleError
import app.banh.core.model.DateRange
import app.banh.core.model.OrderDetail

/** The inline error of a sheet field; the UI maps each to one copy key. */
enum class SheetError { DATE_PAST, DATE_TOO_FAR, DATE_UNCHANGED, FEE_REQUIRED, FEE_INVALID, FEE_UNCHANGED, FEE_NOT_ALLOWED }

/** Null for rule errors that no sheet field shows (the generic banner covers them). */
fun OrderRuleError.sheetError(): SheetError? = when (this) {
    is OrderRuleError.DatePast -> SheetError.DATE_PAST
    is OrderRuleError.DateTooFar -> SheetError.DATE_TOO_FAR
    OrderRuleError.DateUnchanged -> SheetError.DATE_UNCHANGED
    OrderRuleError.FeeRequired -> SheetError.FEE_REQUIRED
    OrderRuleError.FeeInvalid -> SheetError.FEE_INVALID
    OrderRuleError.FeeUnchanged -> SheetError.FEE_UNCHANGED
    OrderRuleError.FeeCorrectionNotAllowed -> SheetError.FEE_NOT_ALLOWED
    OrderRuleError.TransitionInvalid -> null
}

/** A day is pickable only inside the server range; without a range nothing is (the server decides). */
fun isDayPickable(day: String, range: DateRange?): Boolean = range != null && day >= range.min && day <= range.max

/** The day the picker opens on: current expected date, else requested date, each only when pickable; else the range start. */
fun openingDateOf(detail: OrderDetail): String? {
    val range = detail.expectedDateRange ?: return null
    return listOfNotNull(detail.expectedDeliveryDate, detail.requestedDeliveryDate ?: detail.deliveryDate)
        .firstOrNull { isDayPickable(it, range) } ?: range.min
}

/** What the fee sheets show while typing; null fee means the field is empty or invalid. */
data class FeePreview(val feeVnd: Long?, val totalVnd: Long?)

/** Typed-input preview only; stored amounts always come from the server. */
fun feePreviewOf(cakesVnd: Long, text: String): FeePreview {
    val fee = feeOf(text)
    return FeePreview(fee, fee?.let { cakesVnd + it })
}

/** Lines of the delivery card: what the customer asked and, from the scheduled step, what staff set. */
data class DeliveryLines(val requestedDate: String, val expectedDate: String?, val expectedTappable: Boolean)

fun deliveryLinesOf(detail: OrderDetail, canChangeDate: Boolean): DeliveryLines {
    val expected = detail.expectedDeliveryDate
    return DeliveryLines(detail.requestedDeliveryDate ?: detail.deliveryDate, expected, expected != null && canChangeDate)
}
