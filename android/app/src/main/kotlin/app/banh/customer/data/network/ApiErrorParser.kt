package app.banh.customer.data.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull

/** Error body of every non-2xx JSON response (api.md section 1). */
@Serializable
data class ErrorEnvelope(
    val error: ErrorBody,
    @SerialName("request_id") val requestId: String? = null,
)

@Serializable
data class ErrorBody(
    val code: String,
    @SerialName("message_key") val messageKey: String,
    /** Specific to the code; only `retry_after_seconds` is read so far. */
    val details: JsonObject? = null,
)

private const val DEFAULT_RETRY_AFTER_SECONDS = 60
private const val RETRY_AFTER_DETAIL = "retry_after_seconds"
private const val HTTP_TOO_MANY_REQUESTS = 429
private const val HTTP_SERVICE_UNAVAILABLE = 503
private const val FALLBACK_MESSAGE_KEY = "ERR_SERVER"

/**
 * Turns a non-success response into a typed error. A body that is not the contract envelope (for example
 * an answer from a proxy in front of the host) is classified by its status only.
 */
internal fun parseApiError(status: Int, body: String, retryAfterHeader: String?, json: Json): ApiException {
    val envelope = runCatching { json.decodeFromString<ErrorEnvelope>(body) }.getOrNull()
    val code = envelope?.let { ApiErrorCode.fromWire(it.error.code) } ?: codeForStatus(status)
    val requestId = envelope?.requestId
    if (code == ApiErrorCode.RATE_LIMITED) {
        val detail = (envelope?.error?.details?.get(RETRY_AFTER_DETAIL) as? JsonPrimitive)?.intOrNull
        val seconds = detail ?: retryAfterHeader?.trim()?.toIntOrNull() ?: DEFAULT_RETRY_AFTER_SECONDS
        return ApiException.RateLimited(seconds, requestId)
    }
    return ApiException.Service(code, envelope?.error?.messageKey ?: FALLBACK_MESSAGE_KEY, status, requestId)
}

private fun codeForStatus(status: Int): ApiErrorCode = when (status) {
    HTTP_TOO_MANY_REQUESTS -> ApiErrorCode.RATE_LIMITED
    HTTP_SERVICE_UNAVAILABLE -> ApiErrorCode.SERVICE_UNAVAILABLE
    else -> ApiErrorCode.INTERNAL_ERROR
}
