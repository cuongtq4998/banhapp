package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.data.availability.Availability
import app.banh.customer.data.catalog.Catalog

/** The answer of the availability endpoint for one order size; stale when the cake count has changed since. */
data class LoadedAvailability(val cakes: Int, val availability: Availability)

/**
 * The state of the whole order flow, shared by S-5 to S-8 (ADR-0007: one store scoped to the order graph). The draft
 * is the part that is saved; everything else is derived from the catalog or belongs to the current visit.
 */
data class OrderFlowState(
    val draft: OrderDraft,
    /** False until the saved draft has been read, so nothing overwrites it before that. */
    val draftLoaded: Boolean = false,
    val catalog: Load<Catalog> = Load.Loading,
    /** Names of cakes seen in the catalog, to name a cake that has since been hidden (BR-13). */
    val knownCakeNames: Map<String, String> = emptyMap(),
    /** Cakes dropped from the draft because the shop hid them; shown on S-5 until the customer acts. */
    val removedCakeNames: List<String> = emptyList(),
    /** Null until S-6 asks. */
    val availability: Load<LoadedAvailability>? = null,
    /** The chosen date lost its room after a quantity change (UI document 5.6). */
    val dateCleared: Boolean = false,
    val recipientErrors: Map<RecipientField, RecipientError> = emptyMap(),
    /** The customer tried to type or paste beyond the note limit (AC-26). */
    val noteLimitHit: Boolean = false,
) {
    private val readyCatalog: Catalog? get() = (catalog as? Load.Ready)?.value

    /** Null while the catalog is not known. */
    val summary: OrderSummary? get() = readyCatalog?.let { OrderSummary.of(draft, it) }

    val minQty: Int get() = readyCatalog?.settings?.minQty ?: DEFAULT_MIN_QTY
    val maxQtyPerCake: Int get() = readyCatalog?.settings?.maxQtyPerCake ?: DEFAULT_MAX_QTY_PER_CAKE
    val noteMaxLength: Int get() = readyCatalog?.settings?.noteMaxLength ?: FieldRules.NOTE_MAX

    val servedDistrictIds: Set<String> get() = readyCatalog?.districts?.map { it.id }?.toSet().orEmpty()

    companion object {
        const val DEFAULT_MIN_QTY = 2
        const val DEFAULT_MAX_QTY_PER_CAKE = 99
    }
}

/** What the customer or the store itself asks of the flow. The only way to change [OrderFlowState] (see [reduce]). */
sealed interface OrderIntent {
    /** A new draft; from a cake detail with that cake at 1, otherwise empty (FR-4, AC-5). */
    data class StartNew(val productId: String, val idempotencyKey: String) : OrderIntent

    data class SetQuantity(val productId: String, val quantity: Int) : OrderIntent
    data object DismissRemovedNotice : OrderIntent

    data class ChooseDate(val date: String) : OrderIntent
    data class ChooseSlot(val slotId: String) : OrderIntent
    data object LoadAvailability : OrderIntent

    data class EditName(val text: String) : OrderIntent
    data class EditPhone(val text: String) : OrderIntent
    data class EditAddress(val text: String) : OrderIntent
    data class EditNote(val text: String) : OrderIntent
    data class ChooseDistrict(val districtId: String) : OrderIntent
    data object SubmitRecipient : OrderIntent

    data object RetryCatalog : OrderIntent

    /** Results the store feeds back to itself. [replacementKey] is used only when the draft content changes. */
    data class CatalogChanged(val catalog: Load<Catalog>, val replacementKey: String) : OrderIntent
    data class DraftRestored(val draft: OrderDraft?, val replacementKey: String) : OrderIntent
    data class AvailabilityLoaded(val cakes: Int, val result: Load<Availability>) : OrderIntent
}

/** One-shot results for the host (ADR-0007): they are consumed once, not kept in the state. */
sealed interface OrderEffect {
    data class FocusField(val field: RecipientField) : OrderEffect
    data object GoToReview : OrderEffect
}
