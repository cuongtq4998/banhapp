package app.banh.customer.order

/** The send-related part of [reduce]: confirm, the answer, and the end of the order. Pure like the rest of the reducer. */
internal fun reduceSubmit(state: OrderFlowState, intent: OrderIntent): OrderFlowState = when (intent) {
    OrderIntent.Confirm -> if (state.canConfirm) state.copy(submit = SubmitState.Sending) else state
    is OrderIntent.Submitted -> state.copy(submit = SubmitState.Confirmed(intent.orderCode))
    is OrderIntent.ReplaceKey -> state.copy(draft = state.draft.copy(idempotencyKey = intent.key))
    is OrderIntent.SubmitFailed -> failed(state, intent.failure, intent.replacementKey)
    OrderIntent.LeaveReview -> if (state.submit is SubmitState.Failed) state.copy(submit = SubmitState.Idle) else state
    is OrderIntent.FinishOrder -> OrderFlowState(
        draft = OrderDraft.blank(intent.freshKey),
        draftLoaded = true,
        catalog = state.catalog,
        knownCakeNames = state.knownCakeNames,
    )
    else -> state
}

private fun failed(state: OrderFlowState, failure: SubmitFailure, replacementKey: String): OrderFlowState = when (failure) {
    is SubmitFailure.Problem -> state.copy(submit = SubmitState.Failed(failure.problem))
    is SubmitFailure.PriceChanged -> priceChanged(state, failure.update, replacementKey)
    is SubmitFailure.ProductsGone -> productsGone(state, failure.productIds, replacementKey)
    is SubmitFailure.Invalid -> invalid(state, failure)
}

// ADR-0008 v1.1 and ADR-0010: the expected total changes, so the request body changes, so the key is replaced.
private fun priceChanged(state: OrderFlowState, update: PriceUpdate, replacementKey: String): OrderFlowState {
    val before = state.summary
    val withUpdate = state.copy(priceUpdate = update.copy(districtId = state.draft.districtId))
    val after = withUpdate.summary
    val changedLines = after?.lines.orEmpty()
        .filter { line -> before?.lines?.firstOrNull { it.product.id == line.product.id }?.product?.priceVnd != line.product.priceVnd }
        .map { it.product.id }
        .toSet()
    val highlighted = withUpdate.priceUpdate?.copy(
        changedProductIds = changedLines,
        feeChanged = before?.deliveryFeeVnd != after?.deliveryFeeVnd,
        totalChanged = before?.totalVnd != after?.totalVnd,
    )
    return withUpdate.copy(
        priceUpdate = highlighted,
        draft = state.draft.copy(idempotencyKey = replacementKey),
        submit = SubmitState.Failed(SubmitProblem.PriceChanged),
    )
}

// ADR-0011: only the named cakes leave the draft; the order content changed, so the key is new.
private fun productsGone(state: OrderFlowState, ids: List<String>, replacementKey: String): OrderFlowState {
    val names = ids.filter { it in state.draft.quantities }.map { state.knownCakeNames[it].orEmpty() }
    val draft = state.draft.copy(quantities = state.draft.quantities - ids.toSet(), idempotencyKey = replacementKey)
    return state.copy(
        draft = draft,
        removedCakeNames = (state.removedCakeNames + names).distinct(),
        availability = null,
        submit = SubmitState.Failed(SubmitProblem.Rule(SubmitRule.PRODUCT_UNAVAILABLE)),
    )
}

// Fields S-7 can name go back to S-7; anything else is a client defect and shows the general message with retry.
private fun invalid(state: OrderFlowState, failure: SubmitFailure.Invalid): OrderFlowState {
    val errors = recipientErrorsOf(failure.issues)
    val noteIssue = hasNoteIssue(failure.issues)
    if (errors.isEmpty() && !noteIssue) return state.copy(submit = SubmitState.Failed(SubmitProblem.NotSent(NotSentReason.SERVER)))
    return state.copy(submit = SubmitState.Idle, recipientErrors = errors, noteLimitHit = noteIssue || state.noteLimitHit)
}
