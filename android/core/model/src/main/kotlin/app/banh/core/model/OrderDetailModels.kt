package app.banh.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The newest record of the order; [kind] is `status`, `date` or `fee`. `actor_name` is null only for the customer's own creation. */
@Serializable
data class LastChange(@SerialName("actor_name") val actorName: String? = null, val at: String, val kind: String? = null)

/** The shop-date window the date picker is limited to; the server owns it, never the device clock. */
@Serializable
data class DateRange(val min: String, val max: String)

/** Who typed the real delivery fee and when (null on the order before the entry). */
@Serializable
data class DeliveryFeeEntry(
    @SerialName("entered_by_name") val enteredByName: String? = null,
    @SerialName("entered_at") val enteredAt: String,
)

@Serializable
data class DateChange(
    @SerialName("old_date") val oldDate: String,
    @SerialName("new_date") val newDate: String,
    @SerialName("changed_by_name") val changedByName: String? = null,
    @SerialName("changed_at") val changedAt: String,
)

@Serializable
data class FeeCorrection(
    @SerialName("old_fee_vnd") val oldFeeVnd: Long,
    @SerialName("new_fee_vnd") val newFeeVnd: Long,
    @SerialName("changed_by_name") val changedByName: String? = null,
    @SerialName("changed_at") val changedAt: String,
)

/** The detail (api/09 10.13.3); also the body of a successful change and of a 409. */
@Serializable
data class OrderDetail(
    @SerialName("order_code") val orderCode: String,
    val status: OrderStatus,
    @SerialName("customer_name") val customerName: String,
    @SerialName("delivery_date") val deliveryDate: String,
    @SerialName("requested_delivery_date") val requestedDeliveryDate: String? = null,
    @SerialName("expected_delivery_date") val expectedDeliveryDate: String? = null,
    @SerialName("list_date") val listDate: String? = null,
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
    @SerialName("delivery_fee_estimate_vnd") val deliveryFeeEstimateVnd: Long? = null,
    @SerialName("delivery_fee_final_vnd") val deliveryFeeFinalVnd: Long? = null,
    /** Server-computed; shown only when not null, never summed by the app. */
    @SerialName("amount_to_collect_vnd") val amountToCollectVnd: Long? = null,
    @SerialName("delivery_fee_entry") val deliveryFeeEntry: DeliveryFeeEntry? = null,
    @SerialName("cancel_reason") val cancelReason: CancelReason? = null,
    @SerialName("expected_date_range") val expectedDateRange: DateRange? = null,
    @SerialName("allowed_actions") val allowedActions: AllowedActions = emptyList(),
    @SerialName("date_changes") val dateChanges: List<DateChange> = emptyList(),
    @SerialName("fee_corrections") val feeCorrections: List<FeeCorrection> = emptyList(),
    @SerialName("last_change") val lastChange: LastChange? = null,
)

/** Body of `POST /v1/admin/orders/{code}/status` (ADR-0028); extras only for the targets that take them. */
@Serializable
data class StatusChangeRequest(
    @SerialName("expected_status") val expectedStatus: OrderStatus,
    @SerialName("to_status") val toStatus: OrderStatus,
    @SerialName("cancel_reason") val cancelReason: CancelReason? = null,
    @SerialName("expected_delivery_date") val expectedDeliveryDate: String? = null,
    @SerialName("delivery_fee_vnd") val deliveryFeeVnd: Long? = null,
)

/** Body of `PUT .../expected-delivery-date`; the previous date makes a stale view a 409. */
@Serializable
data class DateChangeRequest(
    @SerialName("expected_status") val expectedStatus: OrderStatus,
    @SerialName("previous_expected_delivery_date") val previousExpectedDeliveryDate: String,
    @SerialName("expected_delivery_date") val expectedDeliveryDate: String,
)

/** Body of `PUT .../delivery-fee`. */
@Serializable
data class FeeChangeRequest(
    @SerialName("expected_status") val expectedStatus: OrderStatus,
    @SerialName("previous_delivery_fee_vnd") val previousDeliveryFeeVnd: Long,
    @SerialName("delivery_fee_vnd") val deliveryFeeVnd: Long,
)
