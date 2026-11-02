package app.banh.admin.orders

import app.banh.core.model.DateRange
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/** A refusal the action sheets show beside the field or in a banner (api/09 10.13.1 to 10.13.6). */
sealed interface OrderRuleError {
    data class DatePast(val range: DateRange?) : OrderRuleError

    data class DateTooFar(val range: DateRange?) : OrderRuleError

    data object DateUnchanged : OrderRuleError

    data object FeeInvalid : OrderRuleError

    data object FeeRequired : OrderRuleError

    data object FeeUnchanged : OrderRuleError

    data object FeeCorrectionNotAllowed : OrderRuleError

    data object TransitionInvalid : OrderRuleError
}

/** Maps a 422 to its rule error; null means the failure is not one of these (the caller shows the generic message). */
fun ApiException.Http.toRuleError(json: Json): OrderRuleError? {
    val codes = listOf(code) + fields.map { it.code }
    val range = details?.rangeOf(json)
    return when {
        ErrorCodes.EXPECTED_DATE_PAST in codes -> OrderRuleError.DatePast(range)
        ErrorCodes.EXPECTED_DATE_TOO_FAR in codes -> OrderRuleError.DateTooFar(range)
        ErrorCodes.EXPECTED_DATE_UNCHANGED in codes -> OrderRuleError.DateUnchanged
        ErrorCodes.FEE_INVALID in codes -> OrderRuleError.FeeInvalid
        ErrorCodes.FEE_REQUIRED in codes -> OrderRuleError.FeeRequired
        ErrorCodes.FEE_UNCHANGED in codes -> OrderRuleError.FeeUnchanged
        ErrorCodes.FEE_CORRECTION_NOT_ALLOWED in codes -> OrderRuleError.FeeCorrectionNotAllowed
        ErrorCodes.STATUS_TRANSITION_INVALID in codes -> OrderRuleError.TransitionInvalid
        else -> null
    }
}

private const val RANGE_KEY = "expected_date_range"

private fun JsonObject.rangeOf(json: Json): DateRange? =
    get(RANGE_KEY)?.let { runCatching { json.decodeFromJsonElement(DateRange.serializer(), it) }.getOrNull() }
