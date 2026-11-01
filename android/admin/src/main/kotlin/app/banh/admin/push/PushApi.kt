package app.banh.admin.push

import app.banh.admin.auth.SessionManager
import app.banh.admin.auth.bearer
import app.banh.core.network.ApiClient
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** `PUT /v1/admin/push-token` (api/06 10.8). There is no delete: the server clears the token on sign-out. */
fun interface PushApi {
    suspend fun register(token: String)
}

class HttpPushApi(private val client: ApiClient, private val session: SessionManager) : PushApi {
    override suspend fun register(token: String) {
        val body = buildJsonObject {
            put("platform", "android")
            put("token", token)
        }
        session.authorized { client.execute("PUT", "v1/admin/push-token", jsonBody = body.toString(), headers = bearer(it)) }
    }
}
