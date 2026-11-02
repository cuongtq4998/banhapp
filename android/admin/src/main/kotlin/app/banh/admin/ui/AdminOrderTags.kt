package app.banh.admin.ui

/** Test identifiers of the orders list, the detail and the cancel sheet (docs/design/admin-orders/10 and 13). */
object AdminOrderTags {
    fun orderRow(code: String) = "admin.orders.row.$code"

    fun orderDue(code: String) = "admin.orders.due.$code"
    fun orderExpected(code: String) = "admin.orders.row.expected.$code"

    const val DETAIL_CODE = "admin.detail.code"
    const val DETAIL_STATUS = "admin.detail.status"
    const val DETAIL_DUE = "admin.detail.due"
    const val DETAIL_CUSTOMER = "admin.detail.customer"
    const val DETAIL_PHONE = "admin.detail.phone"
    const val DETAIL_CALL = "admin.detail.call"
    const val DETAIL_ZALO = "admin.detail.zalo"
    const val DETAIL_ADDRESS = "admin.detail.address"
    const val DETAIL_DELIVERY = "admin.detail.delivery"
    const val DETAIL_CAKES = "admin.detail.cakes"
    const val DETAIL_FEE = "admin.detail.fee"
    const val DETAIL_TOTAL = "admin.detail.total"
    const val DETAIL_NOTE = "admin.detail.note"
    const val DETAIL_REASON = "admin.detail.reason"
    const val DETAIL_LAST_CHANGED = "admin.detail.lastChanged"
    const val DETAIL_CANCEL = "admin.detail.cancel"
    const val DETAIL_COMPLETE_YES = "admin.detail.completeYes"
    const val DETAIL_COMPLETE_BACK = "admin.detail.completeBack"
    const val DETAIL_CONFLICT = "admin.detail.conflict"
    const val DETAIL_ERROR = "admin.detail.error"
    const val DETAIL_GONE = "admin.detail.gone"
    const val DETAIL_BACK_TO_LIST = "admin.detail.backToList"
    const val DETAIL_RETRY = "admin.detail.retry"
    const val DETAIL_OFFLINE = "admin.detail.offline"
    const val DETAIL_SKELETON = "admin.detail.skeleton"

    fun detailCake(index: Int) = "admin.detail.cake.$index"

    const val REASON_CUSTOMER = "admin.cancel.reason.customer"
    const val REASON_CANNOT_DELIVER = "admin.cancel.reason.cannotDeliver"
    const val REASON_NO_CONTACT = "admin.cancel.reason.noContact"
    const val REASON_SPAM = "admin.cancel.reason.spam"
    const val CANCEL_CONFIRM = "admin.cancel.reason.confirm"
    const val CANCEL_BACK = "admin.cancel.reason.back"
    const val CANCEL_ERROR = "admin.cancel.error"

    // Design 13 names the row tag admin.orders.row.expected; the code is appended so each row has a unique tag.
    const val ORDER_STEPPER = "admin.order.stepper"
    const val ORDER_PROCESS = "admin.order.process"
    const val ORDER_SCHEDULE = "admin.order.schedule"
    const val ORDER_CHANGE_DATE = "admin.order.changeDate"
    const val ORDER_START_DELIVERY = "admin.order.startDelivery"
    const val ORDER_FINISH = "admin.order.finish"
    const val ORDER_FEE_CORRECT = "admin.order.feeCorrect"
    const val ORDER_CANCEL_BLOCKED = "admin.order.cancelBlocked"
    const val ORDER_FEE = "admin.order.fee"
    const val ORDER_FEE_ESTIMATE = "admin.order.feeEstimate"
    const val ORDER_TOTAL_COLLECT = "admin.order.totalCollect"
    const val ORDER_FEE_HISTORY = "admin.order.feeHistory"

    fun orderStep(n: Int) = "admin.order.step.$n"

    fun feeHistoryRow(n: Int) = "admin.order.feeHistory.row.$n"
}
