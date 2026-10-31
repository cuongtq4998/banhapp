package app.banh.customer.order

import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.FieldIssue
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.longOrNull

/** What a failed send means for the flow; the result of [classifySubmitFailure]. */
sealed interface SubmitFailure {
    data class Problem(val problem: SubmitProblem) : SubmitFailure

    /** `PRICE_CHANGED`; [update] has no highlight sets yet, the reducer compares with the summary it replaces. */
    data class PriceChanged(val update: PriceUpdate) : SubmitFailure

    /** `PRODUCT_UNAVAILABLE`: only these cakes leave the draft (ADR-0011). */
    data class ProductsGone(val productIds: List<String>) : SubmitFailure

    /** `VALIDATION_FAILED` with its `fields[]`. */
    data class Invalid(val issues: List<FieldIssue>) : SubmitFailure
}

private fun notSent(reason: NotSentReason) = SubmitFailure.Problem(SubmitProblem.NotSent(reason))

/** Every error code of api.md 4.3 and section 5 mapped to its S-8 state. */
fun classifySubmitFailure(e: ApiException): SubmitFailure = when (e) {
    is ApiException.NetworkUnavailable -> notSent(NotSentReason.OFFLINE)
    is ApiException.Timeout -> notSent(NotSentReason.TIMEOUT)
    is ApiException.RateLimited -> notSent(NotSentReason.RATE_LIMITED)
    is ApiException.InvalidResponse -> notSent(NotSentReason.SERVER)
    is ApiException.Service -> classifyService(e)
}

private fun classifyService(e: ApiException.Service): SubmitFailure {
    val details = e.details
    return when (e.code) {
        ApiErrorCode.VALIDATION_FAILED -> SubmitFailure.Invalid(e.fields)
        ApiErrorCode.MIN_QTY -> rule(SubmitRule.MIN_QTY, details.int("min_qty"))
        ApiErrorCode.DATE_LEAD -> rule(SubmitRule.DATE_LEAD, details.int("lead_days"))
        ApiErrorCode.DATE_HORIZON -> rule(SubmitRule.DATE_HORIZON, details.int("max_days_ahead"))
        ApiErrorCode.DATE_CAPACITY -> rule(SubmitRule.DATE_CAPACITY, date = details.text("delivery_date"))
        ApiErrorCode.DISTRICT_UNSERVED -> rule(SubmitRule.DISTRICT_UNSERVED)
        ApiErrorCode.SLOT_UNAVAILABLE -> rule(SubmitRule.SLOT_UNAVAILABLE)
        ApiErrorCode.PRODUCT_UNAVAILABLE ->
            SubmitFailure.ProductsGone((details?.get("product_ids") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull })
        ApiErrorCode.PRICE_CHANGED -> priceChanged(details) ?: notSent(NotSentReason.SERVER)
        // Client defects, pause, outage, unknown: the shop can be called; retry uses the same key.
        else -> notSent(NotSentReason.SERVER)
    }
}

private fun rule(rule: SubmitRule, number: Int = 0, date: String? = null) =
    SubmitFailure.Problem(SubmitProblem.Rule(rule, number, date))

private fun JsonObject?.int(key: String): Int = ((this?.get(key)) as? JsonPrimitive)?.intOrNull ?: 0

private fun JsonObject?.text(key: String): String? = ((this?.get(key)) as? JsonPrimitive)?.contentOrNull

private fun JsonElement?.long(): Long? = (this as? JsonPrimitive)?.longOrNull

/** `details`: `{ items: [{product_id, price_vnd}], delivery_fee_vnd, total_vnd }`; null when it does not have that shape. */
private fun priceChanged(details: JsonObject?): SubmitFailure.PriceChanged? {
    if (details == null) return null
    val items = details["items"] as? JsonArray ?: return null
    val fee = details["delivery_fee_vnd"].long() ?: return null
    val prices = items.associate { item ->
        val entry = item as? JsonObject ?: return null
        val id = entry.text("product_id") ?: return null
        id to (entry["price_vnd"].long() ?: return null)
    }
    return SubmitFailure.PriceChanged(PriceUpdate(districtId = null, pricesVnd = prices, deliveryFeeVnd = fee))
}

/** The S-7 fields the server can name with a message of the UI document; other codes are not shown next to a field. */
fun recipientErrorsOf(issues: List<FieldIssue>): Map<RecipientField, RecipientError> {
    val errors = linkedMapOf<RecipientField, RecipientError>()
    issues.forEach { issue ->
        when (issue.code) {
            "NAME_REQUIRED" -> errors.putIfAbsent(RecipientField.NAME, RecipientError.NAME_REQUIRED)
            "PHONE_REQUIRED" -> errors.putIfAbsent(RecipientField.PHONE, RecipientError.PHONE_REQUIRED)
            "PHONE_INVALID" -> errors.putIfAbsent(RecipientField.PHONE, RecipientError.PHONE_INVALID)
            "ADDRESS_REQUIRED" -> errors.putIfAbsent(RecipientField.ADDRESS, RecipientError.ADDRESS_REQUIRED)
            "DISTRICT_REQUIRED" -> errors.putIfAbsent(RecipientField.DISTRICT, RecipientError.DISTRICT_REQUIRED)
            else -> Unit
        }
    }
    return errors.toList().sortedBy { it.first.ordinal }.toMap()
}

fun hasNoteIssue(issues: List<FieldIssue>): Boolean = issues.any { it.code == "NOTE_TOO_LONG" }
