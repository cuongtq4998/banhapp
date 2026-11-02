package app.banh.customer.data.lookup

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Body of `POST /v1/orders/lookup` (api/10); the phone is sent as typed, the server normalises it. */
@Serializable
data class LookupRequest(val phone: String, val cursor: String? = null)

/** One page of the answer; `as_of` is server time and is the only "data as of" source. */
@Serializable
data class LookupAnswer(
    val orders: List<LookupOrder>,
    @SerialName("next_cursor") val nextCursor: String? = null,
    @SerialName("as_of") val asOf: String,
)

@Serializable
data class LookupItem(
    @SerialName("cake_name") val cakeName: String,
    val quantity: Int,
    @SerialName("unit_price_vnd") val unitPriceVnd: Long,
)

/**
 * One order as the lookup lists it. No reason for a cancel and no street exist in the answer. [statusWire] keeps the raw
 * word, so a status added later never fails decoding (see [status]).
 */
@Serializable
data class LookupOrder(
    @SerialName("order_code") val orderCode: String,
    @SerialName("status") val statusWire: String,
    @SerialName("placed_at") val placedAt: String,
    @SerialName("requested_delivery_date") val requestedDeliveryDate: String,
    @SerialName("slot_start_time") val slotStartTime: String,
    @SerialName("slot_end_time") val slotEndTime: String,
    @SerialName("expected_delivery_date") val expectedDeliveryDate: String? = null,
    val items: List<LookupItem> = emptyList(),
    @SerialName("items_subtotal_vnd") val itemsSubtotalVnd: Long = 0,
    @SerialName("delivery_fee_estimate_vnd") val deliveryFeeEstimateVnd: Long? = null,
    @SerialName("delivery_fee_final_vnd") val deliveryFeeFinalVnd: Long? = null,
    @SerialName("amount_to_collect_vnd") val amountToCollectVnd: Long? = null,
    @SerialName("district_name") val districtName: String = "",
    @SerialName("phone_masked") val phoneMasked: String = "",
) {
    val status: TrackingStatus get() = TrackingStatus.fromWire(statusWire)
}

/** The six customer statuses; a word not known yet is [Unknown] with its text, never a crash. */
sealed interface TrackingStatus {
    enum class Known(val wire: String) : TrackingStatus {
        RECEIVED("Received"),
        PROCESSING("Processing"),
        DELIVERY_DATE_SCHEDULED("DeliveryDateScheduled"),
        DELIVERY_STARTED("DeliveryStarted"),
        FINISHED("Finished"),
        CANCELLED("Cancelled"),
    }

    data class Unknown(val raw: String) : TrackingStatus

    companion object {
        fun fromWire(raw: String): TrackingStatus = Known.entries.firstOrNull { it.wire == raw } ?: Unknown(raw)
    }
}
