package app.banh.admin.orders

import app.banh.core.model.CancelReason
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrdersPage
import java.time.LocalDate

/** The status chips (FR-10). Exactly one is selected; the wire value is what `status=` takes (api/06 10.9). */
enum class StatusFilter(val wire: String) {
    TODO("todo"),
    RECEIVED("Received"),
    PROCESSING("Processing"),
    SCHEDULED("DeliveryDateScheduled"),
    DELIVERING("DeliveryStarted"),
    FINISHED("Finished"),
    CANCELLED("Cancelled"),
    ALL("all"),
}

/** The date chip: no filter, today, tomorrow (the server decides which day that is) or one chosen date. */
sealed interface DateFilter {
    data object Any : DateFilter

    data object Today : DateFilter

    data object Tomorrow : DateFilter

    data class One(val date: LocalDate) : DateFilter
}

/** [text] is already trimmed; the empty string means no search. */
data class OrdersQuery(
    val status: StatusFilter = StatusFilter.TODO,
    val date: DateFilter = DateFilter.Any,
    val text: String = "",
)

/** Result of a status change: done, or the server says the order is no longer in the state the screen showed (ADR-0028). */
sealed interface StatusChange {
    data class Changed(val detail: OrderDetail) : StatusChange

    data class Conflict(val current: OrderDetail) : StatusChange
}

interface OrdersApi {
    suspend fun list(query: OrdersQuery, cursor: String?): OrdersPage

    suspend fun detail(orderCode: String): OrderDetail

    /** [expectedDate] goes with DeliveryDateScheduled and [feeVnd] with DeliveryStarted; the server refuses extras elsewhere. */
    suspend fun changeStatus(
        orderCode: String,
        expected: OrderStatus,
        to: OrderStatus,
        reason: CancelReason? = null,
        expectedDate: String? = null,
        feeVnd: Long? = null,
    ): StatusChange

    suspend fun changeExpectedDate(orderCode: String, previous: String, new: String): StatusChange

    suspend fun correctFee(orderCode: String, previous: Long, new: Long): StatusChange
}
