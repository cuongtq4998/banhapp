package app.banh.core.network

import java.io.IOException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/** Every way a call can fail, so callers branch on types and codes, never on message text. */
sealed class ApiException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    /** No connection or a dropped one: the screen says "offline" and offers a retry. */
    class Network(cause: IOException) : ApiException("Network unavailable", cause)

    class Timeout(cause: IOException) : ApiException("Request timed out", cause)

    /** A success status whose body does not match the contract. */
    class InvalidResponse(cause: Throwable? = null) : ApiException("Response does not match the contract", cause)

    /** The server answered with the error envelope (api/01 section 1). [code] is the wire string, new codes need no release. */
    class Http(
        val status: Int,
        val code: String,
        val messageKey: String,
        val requestId: String?,
        val details: JsonObject?,
        val fields: List<FieldIssue>,
        val retryAfterSeconds: Int?,
    ) : ApiException("API error $code ($status)")

    /** True when the network failed, whatever the exact reason. */
    val isOffline: Boolean get() = this is Network || this is Timeout
}

@Serializable
data class FieldIssue(
    val field: String,
    val code: String,
    @SerialName("message_key") val messageKey: String = "ERR_SERVER",
)
