package app.banh.customer.order

import kotlinx.serialization.Serializable

/**
 * Everything the customer has entered so far (ADR-0011). It is the data of the order flow; screens read it and send
 * intents. Ids refer to catalog rows, dates are ISO `yyyy-MM-dd` in shop time.
 */
@Serializable
data class OrderDraft(
    /** Quantity by product id; a product with quantity 0 has no entry. */
    val quantities: Map<String, Int> = emptyMap(),
    val date: String? = null,
    val slotId: String? = null,
    val name: String = "",
    val phone: String = "",
    val address: String = "",
    val districtId: String? = null,
    val note: String = "",
    /** One key for one order content; slice 3 sends it with the order (ADR-0008). Replaced on every change of a body field, kept for a pure retry (ADR-0008 v1.1). */
    val idempotencyKey: String,
    /** Set when the draft is written, to apply the 24 hour rule. */
    val savedAtEpochMillis: Long = 0L,
) {
    /** True when every field that goes into the order request is equal; the key and the save time are not part of it. */
    fun hasSameBodyAs(other: OrderDraft): Boolean =
        copy(idempotencyKey = "", savedAtEpochMillis = 0L) == other.copy(idempotencyKey = "", savedAtEpochMillis = 0L)

    fun quantityOf(productId: String): Int = quantities[productId] ?: 0

    companion object {
        fun blank(idempotencyKey: String) = OrderDraft(idempotencyKey = idempotencyKey)
    }
}
