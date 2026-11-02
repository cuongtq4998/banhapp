package app.banh.admin.auth

import app.banh.core.model.CodeRequest
import app.banh.core.model.CodeRequested
import app.banh.core.model.Me
import app.banh.core.model.RefreshRequest
import app.banh.core.model.SessionCreated
import app.banh.core.model.SignInRequest
import app.banh.core.model.TokenPair
import app.banh.core.network.ApiClient

/** The sign-in and session endpoints (api/05, api/06 10.6). Errors surface as `ApiException`. */
interface AuthApi {
    suspend fun requestCode(email: String): CodeRequested

    suspend fun signIn(request: SignInRequest): SessionCreated

    suspend fun refresh(refreshToken: String): TokenPair

    suspend fun me(accessToken: String): Me

    suspend fun signOut(accessToken: String)

    suspend fun signOutOthers(accessToken: String)
}

class HttpAuthApi(private val client: ApiClient) : AuthApi {
    override suspend fun requestCode(email: String): CodeRequested =
        client.post("v1/auth/code-requests", CodeRequest(email), CodeRequest.serializer(), CodeRequested.serializer())

    override suspend fun signIn(request: SignInRequest): SessionCreated =
        client.post("v1/auth/sessions", request, SignInRequest.serializer(), SessionCreated.serializer())

    override suspend fun refresh(refreshToken: String): TokenPair =
        client.post("v1/auth/refresh", RefreshRequest(refreshToken), RefreshRequest.serializer(), TokenPair.serializer())

    override suspend fun me(accessToken: String): Me = client.get("v1/admin/me", Me.serializer(), headers = bearer(accessToken))

    override suspend fun signOut(accessToken: String) {
        client.execute("DELETE", "v1/admin/session", headers = bearer(accessToken))
    }

    override suspend fun signOutOthers(accessToken: String) {
        client.execute("DELETE", "v1/admin/sessions/others", headers = bearer(accessToken))
    }
}

fun bearer(accessToken: String): Map<String, String> = mapOf("Authorization" to "Bearer $accessToken")
