package app.banh.admin.ui

import android.content.Context
import app.banh.admin.R
import app.banh.core.common.DueMark
import app.banh.core.design.BadgeTone
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderStatus

fun OrderStatus.textRes(): Int = when (this) {
    OrderStatus.New -> R.string.a_status_new
    OrderStatus.Confirmed -> R.string.a_status_confirmed
    OrderStatus.Completed -> R.string.a_status_completed
    OrderStatus.Cancelled -> R.string.a_status_cancelled
}

fun OrderStatus.tone(): BadgeTone = when (this) {
    OrderStatus.New -> BadgeTone.NEW
    OrderStatus.Confirmed -> BadgeTone.CONFIRMED
    OrderStatus.Completed -> BadgeTone.COMPLETED
    OrderStatus.Cancelled -> BadgeTone.CANCELLED
}

fun CancelReason.textRes(): Int = when (this) {
    CancelReason.CUSTOMER_ASKED -> R.string.a_reason_customer
    CancelReason.CANNOT_DELIVER -> R.string.a_reason_cannot_deliver
    CancelReason.CANNOT_REACH_CUSTOMER -> R.string.a_reason_no_contact
    CancelReason.FAKE_SPAM -> R.string.a_reason_spam
}

fun CancelReason.tag(): String = when (this) {
    CancelReason.CUSTOMER_ASKED -> AdminTags.REASON_CUSTOMER
    CancelReason.CANNOT_DELIVER -> AdminTags.REASON_CANNOT_DELIVER
    CancelReason.CANNOT_REACH_CUSTOMER -> AdminTags.REASON_NO_CONTACT
    CancelReason.FAKE_SPAM -> AdminTags.REASON_SPAM
}

fun DueMark.text(context: Context): String = when (this) {
    DueMark.Today -> context.getString(R.string.a_due_today)
    is DueMark.Overdue -> context.getString(R.string.a_overdue, days.toInt())
}
