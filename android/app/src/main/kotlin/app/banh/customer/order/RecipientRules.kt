package app.banh.customer.order

/** The fields of S-7 that can fail on Next, in screen order (the first one gets the focus). */
enum class RecipientField { NAME, PHONE, ADDRESS, DISTRICT }

/** One per message key of UI document 5.7; the screen maps them to text. */
enum class RecipientError { NAME_REQUIRED, PHONE_REQUIRED, PHONE_INVALID, ADDRESS_REQUIRED, DISTRICT_REQUIRED }

/** Validation of S-7 (FR-13, AC-12); pure, so the shared fixtures and the unit tests run it without Android. */
object RecipientRules {
    /** Every failing field, in screen order; empty when the draft can go on to the review. */
    fun validate(draft: OrderDraft, servedDistrictIds: Set<String>): Map<RecipientField, RecipientError> {
        val errors = linkedMapOf<RecipientField, RecipientError>()
        RecipientField.entries.forEach { field -> errorOf(field, draft, servedDistrictIds)?.let { errors[field] = it } }
        return errors
    }

    fun errorOf(field: RecipientField, draft: OrderDraft, servedDistrictIds: Set<String>): RecipientError? = when (field) {
        RecipientField.NAME ->
            if (FieldRules.isValid(TextInput.NAME, draft.name)) null else RecipientError.NAME_REQUIRED
        RecipientField.PHONE -> when {
            draft.phone.isBlank() -> RecipientError.PHONE_REQUIRED
            !PhoneNumber.isValid(draft.phone) -> RecipientError.PHONE_INVALID
            else -> null
        }
        RecipientField.ADDRESS ->
            if (FieldRules.isValid(TextInput.ADDRESS, draft.address)) null else RecipientError.ADDRESS_REQUIRED
        // A district that is not on the served list counts as missing: it cannot be chosen (AC-11).
        RecipientField.DISTRICT ->
            if (draft.districtId in servedDistrictIds) null else RecipientError.DISTRICT_REQUIRED
    }
}
