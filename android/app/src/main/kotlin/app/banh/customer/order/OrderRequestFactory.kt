package app.banh.customer.order

import app.banh.customer.data.orders.CustomerRequest
import app.banh.customer.data.orders.OrderItemRequest
import app.banh.customer.data.orders.OrderRequest

/**
 * The body of `POST /v1/orders` for this state, or null while something the server requires is missing (a date, a
 * slot or a district), in which case nothing is sent. Text is NFC and trimmed (ADR-0009); the phone is sent as
 * entered, trimmed, because the server normalises it (FR-13); the total is the one the review shows (ADR-0010).
 */
fun OrderFlowState.toOrderRequest(): OrderRequest? {
    val summary = summary ?: return null
    val date = draft.date ?: return null
    val slotId = draft.slotId ?: return null
    val districtId = summary.district?.id ?: return null
    if (summary.lines.isEmpty()) return null
    return OrderRequest(
        items = summary.lines.map { OrderItemRequest(it.product.id, it.quantity) },
        deliveryDate = date,
        slotId = slotId,
        customer = CustomerRequest(
            name = FieldRules.normalizeForSubmit(draft.name),
            phone = draft.phone.trim(),
            address = FieldRules.normalizeForSubmit(draft.address),
            districtId = districtId,
        ),
        note = FieldRules.normalizeForSubmit(draft.note).ifEmpty { null },
        expectedTotalVnd = summary.totalVnd,
    )
}
