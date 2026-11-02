package app.banh.admin.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The only thing kept on disk about a session (ADR-0022): the refresh token, and a flag for a sign-out that could not reach
 * the server yet. The access token lives in memory only. Customer data is never stored.
 */
@Serializable
data class StoredSession(
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("pending_sign_out") val pendingSignOut: Boolean = false,
) {
    override fun toString(): String = "StoredSession(pendingSignOut=$pendingSignOut)"
}

interface TokenVault {
    /** Null when nothing is stored, or when it cannot be read (a lost key counts as signed out). */
    fun load(): StoredSession?

    fun save(session: StoredSession)

    fun clear()
}
