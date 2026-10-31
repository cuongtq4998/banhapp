package app.banh.customer.order

/**
 * ADR-0008 v1.1: a new idempotency key on every change of any field of the order request, the same key for a pure
 * retry (offline, timeout, 5xx, 429, ORDERING_PAUSED, restart of the app; none of these touches the draft).
 *
 * Applied to the result of [reduce] for the intents that edit the draft. A new draft, the restore, the catalog
 * reconciliation (see [reconcile]) and the answers to a send decide the key themselves; the restore must keep the saved key.
 */
internal fun withKeyRule(before: OrderFlowState, after: OrderFlowState, intent: OrderIntent, newKey: () -> String): OrderFlowState {
    val decidesItself = intent is OrderIntent.StartNew || intent is OrderIntent.CatalogChanged || intent is OrderIntent.DraftRestored ||
        intent is OrderIntent.SubmitFailed || intent is OrderIntent.ReplaceKey || intent is OrderIntent.FinishOrder
    if (decidesItself || after.draft.hasSameBodyAs(before.draft)) return after
    return after.copy(draft = after.draft.copy(idempotencyKey = newKey()))
}
