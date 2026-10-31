package app.banh.customer.order

import app.banh.customer.data.catalog.Catalog

/** Where the send of the order stands (UI document 5.8). Not saved: a restart begins at [Idle] with the same draft. */
sealed interface SubmitState {
    data object Idle : SubmitState

    /** The request is out: confirm and the Edit controls are off, so a second send cannot start (AC-19). */
    data object Sending : SubmitState

    data class Failed(val problem: SubmitProblem) : SubmitState

    /** The order was received (201 or replay 200); S-9 shows [orderCode]. */
    data class Confirmed(val orderCode: String) : SubmitState
}

/** The step that fixes a broken rule. */
enum class FixStep { CAKES, DATE, RECIPIENT }

/** Rules the server checks at confirmation time that the client cannot fully know (FR-10). Each blocks confirm until fixed. */
enum class SubmitRule(val fixStep: FixStep) {
    MIN_QTY(FixStep.CAKES),
    DATE_CAPACITY(FixStep.DATE),
    DATE_LEAD(FixStep.DATE),
    DATE_HORIZON(FixStep.DATE),
    DISTRICT_UNSERVED(FixStep.RECIPIENT),
    PRODUCT_UNAVAILABLE(FixStep.CAKES),
    SLOT_UNAVAILABLE(FixStep.DATE),
}

/** Why nothing was sent or the outcome is unknown; the same key is used for the retry (ADR-0008). */
enum class NotSentReason { OFFLINE, TIMEOUT, SERVER, RATE_LIMITED }

sealed interface SubmitProblem {
    /** [number] is `min_qty`, `lead_days` or `max_days_ahead`; [date] is the delivery date of `DATE_CAPACITY`. */
    data class Rule(val rule: SubmitRule, val number: Int = 0, val date: String? = null) : SubmitProblem

    data class NotSent(val reason: NotSentReason) : SubmitProblem

    /** Prices were replaced from the answer; confirm stays enabled (ADR-0010). */
    data object PriceChanged : SubmitProblem
}

/**
 * The prices the server named in `PRICE_CHANGED`, applied over the catalog so the review shows what the server will
 * charge. Valid for [districtId] only. The `changed*` sets drive the highlight (UI document 5.8 c).
 */
data class PriceUpdate(
    val districtId: String?,
    val pricesVnd: Map<String, Long>,
    val deliveryFeeVnd: Long,
    val changedProductIds: Set<String> = emptySet(),
    val feeChanged: Boolean = false,
    val totalChanged: Boolean = false,
)

/** The catalog with the server's prices over it; the fee applies only while [chosenDistrictId] is the district it was for. */
fun PriceUpdate.applyTo(catalog: Catalog, chosenDistrictId: String?): Catalog = catalog.copy(
    products = catalog.products.map { product -> pricesVnd[product.id]?.let { product.copy(priceVnd = it) } ?: product },
    districts = catalog.districts.map { district ->
        if (district.id == districtId && district.id == chosenDistrictId) district.copy(deliveryFeeVnd = deliveryFeeVnd) else district
    },
)
