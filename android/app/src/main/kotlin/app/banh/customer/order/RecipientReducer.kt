package app.banh.customer.order

/** The S-7 part of [reduce]: typing, choosing a district, and the check on Next. */
internal fun reduceRecipient(state: OrderFlowState, intent: OrderIntent): OrderFlowState = when (intent) {
    is OrderIntent.EditName -> {
        val cleaned = FieldRules.cleanInput(TextInput.NAME, intent.text)
        edited(state, RecipientField.NAME, state.draft.copy(name = cleaned.text))
    }
    is OrderIntent.EditPhone ->
        edited(state, RecipientField.PHONE, state.draft.copy(phone = intent.text.take(PHONE_INPUT_MAX)))
    is OrderIntent.EditAddress -> {
        val cleaned = FieldRules.cleanInput(TextInput.ADDRESS, intent.text)
        edited(state, RecipientField.ADDRESS, state.draft.copy(address = cleaned.text))
    }
    is OrderIntent.EditNote -> {
        val cleaned = FieldRules.cleanInput(TextInput.NOTE, intent.text, state.noteMaxLength)
        state.copy(draft = state.draft.copy(note = cleaned.text), noteLimitHit = cleaned.exceededLimit)
    }
    is OrderIntent.ChooseDistrict ->
        edited(state, RecipientField.DISTRICT, state.draft.copy(districtId = intent.districtId))
    OrderIntent.SubmitRecipient ->
        state.copy(recipientErrors = RecipientRules.validate(state.draft, state.servedDistrictIds))
    else -> state
}

/**
 * Longest phone entry that is kept. Not a business rule: the longest valid form, `+84` plus nine digits with
 * separators, fits easily, and this only stops absurd pastes (ADR-0009 input safety).
 */
private const val PHONE_INPUT_MAX = 20

// An error under a field goes away as soon as the field is valid, and changes if another rule now fails (FR-13).
private fun edited(state: OrderFlowState, field: RecipientField, draft: OrderDraft): OrderFlowState {
    val errors = if (field in state.recipientErrors) {
        val error = RecipientRules.errorOf(field, draft, state.servedDistrictIds)
        if (error == null) state.recipientErrors - field else state.recipientErrors + (field to error)
    } else {
        state.recipientErrors
    }
    return state.copy(draft = draft, recipientErrors = errors)
}
