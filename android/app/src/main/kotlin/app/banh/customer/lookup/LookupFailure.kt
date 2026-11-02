package app.banh.customer.lookup

import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.FieldIssue

private const val FIELD_PHONE = "phone"
private const val CODE_PHONE_REQUIRED = "PHONE_REQUIRED"
private const val CODE_PHONE_INVALID = "PHONE_INVALID"
private const val CODE_CURSOR_INVALID = "CURSOR_INVALID"

/** What a failed lookup means for the screen; the server text is never shown (api/10 section 10.14.6). */
sealed interface LookupFailure {
    /** 422 on the phone; both codes show the same text (field key `ERR_FIELD_REQUIRED` or `ERR_FIELD_INVALID`). */
    data class PhoneRejected(val fieldKey: String) : LookupFailure

    /** 422 on the cursor: the list restarts at page 1. */
    data object CursorInvalid : LookupFailure

    data class RateLimited(val waitSeconds: Int) : LookupFailure

    data object Offline : LookupFailure

    /** 413, 503, a broken body and anything else. */
    data object Generic : LookupFailure
}

fun Throwable.toLookupFailure(): LookupFailure = when (this) {
    is ApiException.RateLimited -> LookupFailure.RateLimited(retryAfterSeconds)
    is ApiException.NetworkUnavailable, is ApiException.Timeout -> LookupFailure.Offline
    is ApiException.Service -> fields.toValidationFailure(code)
    else -> LookupFailure.Generic
}

private fun List<FieldIssue>.toValidationFailure(code: ApiErrorCode): LookupFailure {
    if (code != ApiErrorCode.VALIDATION_FAILED) return LookupFailure.Generic
    firstOrNull { it.code == CODE_CURSOR_INVALID }?.let { return LookupFailure.CursorInvalid }
    val phone = firstOrNull { it.field == FIELD_PHONE || it.code == CODE_PHONE_REQUIRED || it.code == CODE_PHONE_INVALID }
    return phone?.let { LookupFailure.PhoneRejected(it.messageKey) } ?: LookupFailure.Generic
}
