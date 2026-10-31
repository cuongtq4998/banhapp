package app.banh.customer.data.orders

import app.banh.customer.data.network.ApiException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Body of `POST /v1/orders` (docs/system/api/03-orders.md). Prices and fees are never sent; the total is only an acknowledgement. */
@Serializable
data class OrderRequest(
    val items: List<OrderItemRequest>,
    @SerialName("delivery_date") val deliveryDate: String,
    @SerialName("slot_id") val slotId: String,
    val customer: CustomerRequest,
    /** Sent as `null` when the customer wrote none (the contract example does so). */
    val note: String?,
    @SerialName("expected_total_vnd") val expectedTotalVnd: Long,
)

@Serializable
data class OrderItemRequest(
    @SerialName("product_id") val productId: String,
    val quantity: Int,
)

@Serializable
data class CustomerRequest(
    val name: String,
    val phone: String,
    val address: String,
    @SerialName("district_id") val districtId: String,
)

/** The 201 and the replay 200 body: the code and nothing else (FR-11, AC-25). */
@Serializable
data class OrderReceipt(
    @SerialName("order_code") val orderCode: String,
    @SerialName("created_at") val createdAt: String,
)

/** Edge to the order endpoint; the order flow and its tests depend on this, not on OkHttp. */
interface OrderApi {
    /**
     * Sends the order once with [idempotencyKey] (ADR-0008). There is no automatic retry here: repeating with the same
     * key is the caller's decision.
     * @throws ApiException on every failure.
     */
    suspend fun submit(request: OrderRequest, idempotencyKey: String): OrderReceipt
}
