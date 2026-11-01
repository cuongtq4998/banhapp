package app.banh.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The four order statuses; the constant names are the wire values (api/06 section 10.9). */
@Serializable
enum class OrderStatus {
    New,
    Confirmed,
    Completed,
    Cancelled,
    ;

    /** New and Confirmed orders are open; they are the ones that can become due (FR-9). */
    val isOpen: Boolean get() = this == New || this == Confirmed
}

/** The four cancel reasons (api/06 section 10.11); `day_full` was removed in v1.16. */
@Serializable
enum class CancelReason(val wire: String) {
    @SerialName("customer_asked") CUSTOMER_ASKED("customer_asked"),
    @SerialName("cannot_deliver") CANNOT_DELIVER("cannot_deliver"),
    @SerialName("cannot_reach_customer") CANNOT_REACH_CUSTOMER("cannot_reach_customer"),
    @SerialName("fake_spam") FAKE_SPAM("fake_spam"),
}

/** What the server allows next, computed from the status (api/06 section 10.10). */
@Serializable
enum class OrderAction {
    @SerialName("confirm") CONFIRM,
    @SerialName("complete") COMPLETE,
    @SerialName("cancel") CANCEL,
}

@Serializable
data class Slot(val start: String, val end: String)

/** One row of the list (api/06 section 10.9). */
@Serializable
data class OrderSummary(
    @SerialName("order_code") val orderCode: String,
    val status: OrderStatus,
    @SerialName("customer_name") val customerName: String,
    /** Shop date, `YYYY-MM-DD`. */
    @SerialName("delivery_date") val deliveryDate: String,
    val slot: Slot,
    @SerialName("total_cakes") val totalCakes: Int,
    @SerialName("total_vnd") val totalVnd: Long,
    @SerialName("district_name") val districtName: String,
    @SerialName("created_at") val createdAt: String,
)

/** The list answer: at most 50 rows, the badge number and the shop date used for due marks. */
@Serializable
data class OrdersPage(
    val items: List<OrderSummary>,
    @SerialName("next_cursor") val nextCursor: String? = null,
    @SerialName("unfinished_count") val unfinishedCount: Int = 0,
    @SerialName("server_date") val serverDate: String,
)

@Serializable
data class OrderLine(
    @SerialName("product_name") val productName: String,
    val quantity: Int,
    @SerialName("unit_price_vnd") val unitPriceVnd: Long,
    @SerialName("line_total_vnd") val lineTotalVnd: Long,
)

/** `actor_name` is null when the customer placed the order and nobody changed it. */
@Serializable
data class LastChange(@SerialName("actor_name") val actorName: String? = null, val at: String)

/** The detail (api/06 section 10.10); also the body of a successful status change and of a 409. */
@Serializable
data class OrderDetail(
    @SerialName("order_code") val orderCode: String,
    val status: OrderStatus,
    @SerialName("customer_name") val customerName: String,
    @SerialName("delivery_date") val deliveryDate: String,
    val slot: Slot,
    @SerialName("total_cakes") val totalCakes: Int,
    @SerialName("total_vnd") val totalVnd: Long,
    @SerialName("district_name") val districtName: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("customer_phone") val customerPhone: String,
    @SerialName("customer_address") val customerAddress: String,
    val note: String? = null,
    val items: List<OrderLine>,
    @SerialName("items_subtotal_vnd") val itemsSubtotalVnd: Long,
    @SerialName("delivery_fee_vnd") val deliveryFeeVnd: Long,
    @SerialName("cancel_reason") val cancelReason: CancelReason? = null,
    @SerialName("allowed_actions") val allowedActions: List<OrderAction> = emptyList(),
    @SerialName("last_change") val lastChange: LastChange? = null,
)

/** Body of `POST /v1/admin/orders/{code}/status` (ADR-0028: `expected_status` detects a stale view). */
@Serializable
data class StatusChangeRequest(
    @SerialName("expected_status") val expectedStatus: OrderStatus,
    @SerialName("to_status") val toStatus: OrderStatus,
    @SerialName("cancel_reason") val cancelReason: CancelReason? = null,
)
