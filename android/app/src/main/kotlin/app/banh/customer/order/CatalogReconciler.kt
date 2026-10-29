package app.banh.customer.order

import app.banh.customer.data.Load

/**
 * Brings the draft in line with the active catalog (BR-13, ADR-0011): a cake the shop has hidden loses its quantity and
 * is reported once; every other entry stays. A district or slot that is no longer offered is cleared so the customer
 * chooses again. Because the order content changed, the idempotency key is replaced (ADR-0008).
 * Does nothing until both the catalog and the saved draft are known.
 */
internal fun reconcile(state: OrderFlowState, replacementKey: String): OrderFlowState {
    val catalog = (state.catalog as? Load.Ready)?.value ?: return state
    if (!state.draftLoaded) return state
    val activeIds = catalog.products.map { it.id }.toSet()
    val hidden = state.draft.quantities.keys.filter { it !in activeIds }
    val draft = state.draft.copy(
        quantities = state.draft.quantities.filterKeys { it in activeIds },
        districtId = state.draft.districtId?.takeIf { id -> catalog.districts.any { it.id == id } },
        slotId = state.draft.slotId?.takeIf { id -> catalog.slots.any { it.id == id } },
        idempotencyKey = if (hidden.isEmpty()) state.draft.idempotencyKey else replacementKey,
    )
    // An empty name means the cake was never seen in this run; the screen then uses a general wording.
    val removed = (state.removedCakeNames + hidden.map { state.knownCakeNames[it].orEmpty() }).distinct()
    return state.copy(draft = draft, removedCakeNames = removed)
}
