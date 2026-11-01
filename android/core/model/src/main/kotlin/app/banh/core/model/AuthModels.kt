package app.banh.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class Role {
    @SerialName("owner") OWNER,
    @SerialName("staff") STAFF,
}

@Serializable
data class Account(val name: String, val role: Role)

@Serializable
data class CodeRequest(val email: String)

@Serializable
data class CodeRequested(
    @SerialName("resend_after_seconds") val resendAfterSeconds: Int,
    @SerialName("expires_in_seconds") val expiresInSeconds: Int,
)

@Serializable
data class SignInRequest(
    val email: String,
    val code: String,
    @SerialName("installation_id") val installationId: String,
    @SerialName("device_name") val deviceName: String,
)

/** The answer of sign-in (201). Tokens are secrets, so `toString` never prints them (BR-7: nothing sensitive in logs). */
@Serializable
data class SessionCreated(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("access_expires_in") val accessExpiresIn: Int,
    @SerialName("device_id") val deviceId: String,
    val account: Account,
    @SerialName("server_date") val serverDate: String,
) {
    override fun toString(): String = "SessionCreated(role=${account.role})"
}

@Serializable
data class RefreshRequest(@SerialName("refresh_token") val refreshToken: String)

/** The answer of a refresh: a new pair; the old refresh token is dead after the grace window. */
@Serializable
data class TokenPair(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("access_expires_in") val accessExpiresIn: Int,
) {
    override fun toString(): String = "TokenPair(expiresIn=$accessExpiresIn)"
}

@Serializable
data class Me(
    val account: Account,
    @SerialName("device_id") val deviceId: String,
    @SerialName("server_date") val serverDate: String,
)
