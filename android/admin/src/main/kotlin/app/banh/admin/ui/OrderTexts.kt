package app.banh.admin.ui

import android.content.Context
import app.banh.admin.R
import app.banh.core.common.DueMark
import app.banh.core.design.BadgeTone
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderStatus

fun OrderStatus.textRes(): Int = when (this) {
    OrderStatus.Received -> R.string.a_status_received
    OrderStatus.Processing -> R.string.a_status_processing
    OrderStatus.DeliveryDateScheduled -> R.string.a_status_scheduled
    OrderStatus.DeliveryStarted -> R.string.a_status_delivering
    OrderStatus.Finished -> R.string.a_status_finished
    OrderStatus.Cancelled -> R.string.a_status_cancelled
    is OrderStatus.Unknown -> R.string.a_status_unknown
}

// Tones: the screens slice may add dedicated ones; the existing four keep the badge colours meaningful meanwhile.
fun OrderStatus.tone(): BadgeTone = when (this) {
    OrderStatus.Received -> BadgeTone.NEW
    OrderStatus.Processing, OrderStatus.DeliveryDateScheduled, OrderStatus.DeliveryStarted -> BadgeTone.CONFIRMED
    OrderStatus.Finished -> BadgeTone.COMPLETED
    OrderStatus.Cancelled, is OrderStatus.Unknown -> BadgeTone.CANCELLED
}

fun CancelReason.textRes(): Int = when (this) {
    CancelReason.CUSTOMER_ASKED -> R.string.a_reason_customer
    CancelReason.CANNOT_DELIVER -> R.string.a_reason_cannot_deliver
    CancelReason.CANNOT_REACH_CUSTOMER -> R.string.a_reason_no_contact
    CancelReason.FAKE_SPAM -> R.string.a_reason_spam
}

fun CancelReason.tag(): String = when (this) {
    CancelReason.CUSTOMER_ASKED -> AdminOrderTags.REASON_CUSTOMER
    CancelReason.CANNOT_DELIVER -> AdminOrderTags.REASON_CANNOT_DELIVER
    CancelReason.CANNOT_REACH_CUSTOMER -> AdminOrderTags.REASON_NO_CONTACT
    CancelReason.FAKE_SPAM -> AdminOrderTags.REASON_SPAM
}

fun DueMark.text(context: Context): String = when (this) {
    DueMark.Today -> context.getString(R.string.a_due_today)
    is DueMark.Overdue -> context.getString(R.string.a_overdue, days.toInt())
}
