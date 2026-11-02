package app.banh.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The four cancel reasons (api/06 section 10.11); `day_full` was removed in v1.16. */
@Serializable
enum class CancelReason(val wire: String) {
    @SerialName("customer_asked") CUSTOMER_ASKED("customer_asked"),
    @SerialName("cannot_deliver") CANNOT_DELIVER("cannot_deliver"),
    @SerialName("cannot_reach_customer") CANNOT_REACH_CUSTOMER("cannot_reach_customer"),
    @SerialName("fake_spam") FAKE_SPAM("fake_spam"),
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
    /** Date the server set for delivery, if any. */
    @SerialName("expected_delivery_date") val expectedDeliveryDate: String? = null,
    /** Sort and due-mark date: expected date, else the requested one; never null. */
    @SerialName("list_date") val listDate: String,
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
