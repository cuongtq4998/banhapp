package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.map

/**
 * The pure state transition of the order flow (ADR-0007 MVI): same state and intent give the same result, with no
 * clock, random source, storage or network. The store ([OrderFlowViewModel]) does the side effects around it.
 */
fun reduce(state: OrderFlowState, intent: OrderIntent): OrderFlowState = when (intent) {
    is OrderIntent.StartNew -> startNew(state, intent)
    is OrderIntent.SetQuantity -> setQuantity(state, intent)
    OrderIntent.DismissRemovedNotice -> state.copy(removedCakeNames = emptyList())
    is OrderIntent.ChooseDate -> state.copy(draft = state.draft.copy(date = intent.date), dateCleared = false)
    is OrderIntent.ChooseSlot -> state.copy(draft = state.draft.copy(slotId = intent.slotId))
    OrderIntent.LoadAvailability -> state.copy(availability = if (hasCakes(state)) Load.Loading else null)
    is OrderIntent.AvailabilityLoaded -> availabilityLoaded(state, intent)
    is OrderIntent.EditName,
    is OrderIntent.EditPhone,
    is OrderIntent.EditAddress,
    is OrderIntent.EditNote,
    is OrderIntent.ChooseDistrict,
    OrderIntent.SubmitRecipient,
    -> reduceRecipient(state, intent)
    OrderIntent.RetryCatalog -> state
    is OrderIntent.CatalogChanged -> reconcile(withCatalog(state, intent.catalog), intent.replacementKey)
    is OrderIntent.DraftRestored -> reconcile(
        state.copy(draft = intent.draft ?: state.draft, draftLoaded = true),
        intent.replacementKey,
    )
}

private fun hasCakes(state: OrderFlowState): Boolean = (state.summary?.totalQuantity ?: 0) > 0

private fun startNew(state: OrderFlowState, intent: OrderIntent.StartNew): OrderFlowState = state.copy(
    draft = OrderDraft(quantities = mapOf(intent.productId to 1), idempotencyKey = intent.idempotencyKey),
    removedCakeNames = emptyList(),
    availability = null,
    dateCleared = false,
    recipientErrors = emptyMap(),
    noteLimitHit = false,
)

private fun setQuantity(state: OrderFlowState, intent: OrderIntent.SetQuantity): OrderFlowState {
    val quantity = intent.quantity.coerceIn(0, state.maxQtyPerCake)
    val quantities = if (quantity == 0) state.draft.quantities - intent.productId else state.draft.quantities + (intent.productId to quantity)
    return state.copy(
        draft = state.draft.copy(quantities = quantities),
        removedCakeNames = emptyList(),
        // The answer was for another order size, so it is no longer shown.
        availability = null,
    )
}

private fun availabilityLoaded(state: OrderFlowState, intent: OrderIntent.AvailabilityLoaded): OrderFlowState {
    // A slow answer for an earlier order size must not replace a newer one.
    if (intent.cakes != state.summary?.totalQuantity) return state
    val loaded = state.copy(availability = intent.result.map { LoadedAvailability(intent.cakes, it) })
    val result = intent.result as? Load.Ready ?: return loaded
    val chosen = loaded.draft.date ?: return loaded
    val stillFree = result.value.dates.any { it.date == chosen && it.available }
    // Date lost its room: clear the date, keep the slot, tell the customer (UI document 5.6).
    return if (stillFree) loaded else loaded.copy(draft = loaded.draft.copy(date = null), dateCleared = true)
}

private fun withCatalog(state: OrderFlowState, catalog: Load<Catalog>): OrderFlowState {
    val names = (catalog as? Load.Ready)?.value?.products?.associate { it.id to it.name }.orEmpty()
    return state.copy(catalog = catalog, knownCakeNames = state.knownCakeNames + names)
}
