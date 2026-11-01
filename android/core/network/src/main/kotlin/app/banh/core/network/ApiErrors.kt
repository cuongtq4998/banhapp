package app.banh.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull

/** Codes the admin app branches on (api/05, api/06, api/08). Everything else is shown as a generic failure. */
object ErrorCodes {
    const val UNAUTHENTICATED = "UNAUTHENTICATED"
    const val ACCESS_TOKEN_EXPIRED = "ACCESS_TOKEN_EXPIRED"
    const val SESSION_REVOKED = "SESSION_REVOKED"
    const val SESSION_EXPIRED = "SESSION_EXPIRED"
    const val FORBIDDEN = "FORBIDDEN"
    const val CODE_INVALID = "CODE_INVALID"
    const val CODE_EXPIRED = "CODE_EXPIRED"
    const val CODE_RESEND_WAIT = "CODE_RESEND_WAIT"
    const val CODE_REQUEST_LIMIT = "CODE_REQUEST_LIMIT"
    const val VALIDATION_FAILED = "VALIDATION_FAILED"
    const val ORDER_NOT_FOUND = "ORDER_NOT_FOUND"
    const val ORDER_STATE_CHANGED = "ORDER_STATE_CHANGED"
    const val STATUS_TRANSITION_INVALID = "STATUS_TRANSITION_INVALID"
    const val CANCEL_REASON_REQUIRED = "CANCEL_REASON_REQUIRED"
    const val RATE_LIMITED = "RATE_LIMITED"
    const val SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
}

@Serializable
internal data class ErrorEnvelope(
    val error: ErrorBody,
    @SerialName("request_id") val requestId: String? = null,
)

@Serializable
internal data class ErrorBody(
    val code: String,
    @SerialName("message_key") val messageKey: String = "ERR_SERVER",
    val details: JsonObject? = null,
    val fields: List<FieldIssue>? = null,
)

private const val RETRY_AFTER_DETAIL = "retry_after_seconds"
private const val FALLBACK_MESSAGE_KEY = "ERR_SERVER"

/** A body that is not the envelope (a proxy page, for example) is classified by its status only. */
internal fun parseHttpError(status: Int, body: String, retryAfterHeader: String?, json: Json): ApiException.Http {
    val envelope = runCatching { json.decodeFromString<ErrorEnvelope>(body) }.getOrNull()
    val retry = (envelope?.error?.details?.get(RETRY_AFTER_DETAIL) as? JsonPrimitive)?.intOrNull
        ?: retryAfterHeader?.trim()?.toIntOrNull()
    return ApiException.Http(
        status = status,
        code = envelope?.error?.code ?: codeForStatus(status),
        messageKey = envelope?.error?.messageKey ?: FALLBACK_MESSAGE_KEY,
        requestId = envelope?.requestId,
        details = envelope?.error?.details,
        fields = envelope?.error?.fields.orEmpty(),
        retryAfterSeconds = retry,
    )
}

private fun codeForStatus(status: Int): String = when (status) {
    401 -> ErrorCodes.UNAUTHENTICATED
    403 -> ErrorCodes.FORBIDDEN
    404 -> ErrorCodes.ORDER_NOT_FOUND
    429 -> ErrorCodes.RATE_LIMITED
    503 -> ErrorCodes.SERVICE_UNAVAILABLE
    else -> "INTERNAL_ERROR"
}
