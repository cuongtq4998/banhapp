package app.banh.customer.data.network

import java.io.IOException

/** Every way a call to the backend can fail, so callers branch on types and never on message text. */
sealed class ApiException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    /** True when repeating the same request can succeed (the free host may be waking up, ADR-0003). */
    open val isTransient: Boolean get() = false

    class NetworkUnavailable(cause: IOException) : ApiException("Network unavailable", cause) {
        override val isTransient: Boolean = true
    }

    class Timeout(cause: IOException) : ApiException("Request timed out", cause) {
        override val isTransient: Boolean = true
    }

    /** The server answered with the contract error body (api.md section 1). */
    class Service(
        val code: ApiErrorCode,
        /** UI document key; the app shows its own text for it, never server text. */
        val messageKey: String,
        val httpStatus: Int,
        val requestId: String?,
    ) : ApiException("API error $code ($httpStatus)")

    class RateLimited(val retryAfterSeconds: Int, val requestId: String?) :
        ApiException("Rate limited, retry after $retryAfterSeconds s")

    /** A success status with a body that does not match the contract. */
    class InvalidResponse(cause: Throwable? = null) : ApiException("Response does not match the contract", cause)
}
