package app.banh.admin.stub

import app.banh.core.model.Account
import app.banh.core.model.DateChangeRequest
import app.banh.core.model.FeeChangeRequest
import app.banh.core.model.Me
import app.banh.core.model.OrderDetail
import app.banh.core.model.Role
import app.banh.core.model.SessionCreated
import app.banh.core.model.StatusChangeRequest
import app.banh.core.model.TokenPair
import java.io.IOException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put

private val json = Json { ignoreUnknownKeys = true }
private const val VALID_CODE = "123456"
private const val EXPIRED_CODE = "999999"

/**
 * A fake of the admin API that answers from contracts/fixtures/admin (debug builds only). It is stateful, so the whole flow works:
 * sign in (code 123456; 000000 is wrong, 999999 is expired; an address with "owner" signs in as owner, "limit" gets the hourly limit,
 * "offline" fails like a lost connection), rotating tokens, the order list with filters and search, status changes and the
 * conflict of FR-19 (the order BT-9C5D3F is changed by someone else before the first attempt).
 */
class StubBackend(private val fixtures: Fixtures, serverDate: String = "2026-11-02") {
    fun interface Fixtures {
        fun read(name: String): String
    }

    private val template = json.decodeFromJsonElement(OrderDetail.serializer(), body("order-detail"))
    private val store = StubOrders(template, serverDate)
    private val date = serverDate

    private val owner = StubOwner(fixtures)
    private var account = Account("Nhan Vien A", Role.STAFF)
    private var email = "nhanvien.a@example.com"
    private var accessGeneration = 0
    private var refreshGeneration = 0
    private var previousRefresh: String? = null

    /** Makes the current access token expire, as after 5 minutes: the next call answers ACCESS_TOKEN_EXPIRED (tests). */
    fun expireAccessToken() {
        accessGeneration += 1
    }

    @Synchronized
    fun handle(request: StubRequest): StubResponse {
        val path = request.path
        return when {
            request.method == "POST" && path == "v1/auth/code-requests" -> codeRequest(request)
            request.method == "POST" && path == "v1/auth/sessions" -> signIn(request)
            request.method == "POST" && path == "v1/auth/refresh" -> refresh(request)
            !authorized(request) -> error("error-access-token-expired", 401)
            request.method == "GET" && path == "v1/admin/me" -> ok(json.encodeToString(Me.serializer(), Me(account, email, "5B0C2F6A-0000-4A00-8000-000000000001", date)))
            request.method == "PUT" && path == "v1/admin/push-token" -> pushToken(request)
            path.startsWith(OWNER_PREFIX) -> if (account.role != Role.OWNER) error("error-forbidden", 403) else owner.handle(request.method, path, request) ?: error("error-order-not-found", 404)
            request.method == "DELETE" && (path == "v1/admin/session" || path == "v1/admin/sessions/others") -> signOut(path)
            request.method == "GET" && path == "v1/admin/orders" -> failOnSearch(request) ?: ok(json.encodeToString(app.banh.core.model.OrdersPage.serializer(), store.list(request.query)))
            path.startsWith("v1/admin/orders/") -> orderRoute(request)
            else -> error("error-order-not-found", 404)
        }
    }

    private fun codeRequest(request: StubRequest): StubResponse {
        val email = emailOf(request.body)
        if (email.contains("offline")) throw IOException("stub offline")
        if (email.contains("limit")) return error("error-code-request-limit", 429, retryAfter = 1800)
        return ok(fixtures.read("code-request").let { json.parseToJsonElement(it).jsonObject["body"].toString() }, 202)
    }

    private fun signIn(request: StubRequest): StubResponse {
        val sent = json.parseToJsonElement(request.body.orEmpty()).jsonObject
        val code = sent["code"]?.let { (it as JsonPrimitive).content }
        if (code == EXPIRED_CODE) return error("error-code-expired", 422)
        if (code != VALID_CODE) return error("error-code-invalid", 422)
        email = emailOf(request.body)
        account = if (email.contains("owner")) Account("Chu Tiem", Role.OWNER) else Account("Nhan Vien A", Role.STAFF)
        accessGeneration += 1
        refreshGeneration += 1
        previousRefresh = null
        val created = json.decodeFromJsonElement(SessionCreated.serializer(), body("session-created"))
        return ok(json.encodeToString(SessionCreated.serializer(), created.copy(accessToken = accessToken(), refreshToken = refreshToken(), account = account, serverDate = date)), 201)
    }

    private fun refresh(request: StubRequest): StubResponse {
        val sent = (json.parseToJsonElement(request.body.orEmpty()).jsonObject["refresh_token"] as? JsonPrimitive)?.content
        // The current token rotates; the previous one is accepted once more (the 20 s grace of ADR-0022).
        if (sent != refreshToken() && sent != previousRefresh) return error("error-session-revoked", 401)
        previousRefresh = refreshToken()
        refreshGeneration += 1
        accessGeneration += 1
        return ok(json.encodeToString(TokenPair.serializer(), TokenPair(accessToken(), refreshToken(), 300)))
    }

    // 204 like the server; the token is recorded so tests can see that the phone registered (and what it did not send).
    private fun pushToken(request: StubRequest): StubResponse {
        val token = (json.parseToJsonElement(request.body.orEmpty()).jsonObject["token"] as? JsonPrimitive)?.content
        if (token != null) pushTokens.add(token)
        return StubResponse(204)
    }

    private fun signOut(path: String): StubResponse {
        if (path.endsWith("/session")) {
            accessGeneration += 1
            refreshGeneration += 1
        }
        return StubResponse(204)
    }

    private fun orderRoute(request: StubRequest): StubResponse {
        val parts = request.path.removePrefix("v1/admin/orders/").split("/")
        val code = parts[0]
        if (request.method == "GET" && parts.size == 1) {
            return store.detail(code)?.let { ok(json.encodeToString(OrderDetail.serializer(), it)) } ?: error("error-order-not-found", 404)
        }
        if (request.method == "POST" && parts.getOrNull(1) == "status") return changeStatus(code, request)
        if (request.method == "PUT" && parts.getOrNull(1) == "expected-delivery-date") return answer(store.changeDate(code, json.decodeFromString(DateChangeRequest.serializer(), request.body.orEmpty()), account.name))
        if (request.method == "PUT" && parts.getOrNull(1) == "delivery-fee") return answer(store.changeFee(code, json.decodeFromString(FeeChangeRequest.serializer(), request.body.orEmpty()), account.name))
        return error("error-order-not-found", 404)
    }

    private fun changeStatus(code: String, request: StubRequest): StubResponse =
        answer(store.change(code, json.decodeFromString(StatusChangeRequest.serializer(), request.body.orEmpty()), account.name))

    private fun answer(result: StubOrders.Change): StubResponse = when (result) {
        StubOrders.Change.NotFound -> error("error-order-not-found", 404)
        is StubOrders.Change.Done -> ok(json.encodeToString(OrderDetail.serializer(), result.detail))
        is StubOrders.Change.Conflict -> conflict(result.current)
        is StubOrders.Change.Refused -> error(result.fixture, result.status)
    }

    // `details.order` carries the order as it is now (api/06 10.11).
    private fun conflict(current: OrderDetail): StubResponse {
        val template = json.parseToJsonElement(fixtures.read("error-order-state-changed")).jsonObject
        val details = buildJsonObject { put("order", json.encodeToJsonElement(OrderDetail.serializer(), current)) }
        val errorBody = JsonObject(template["error"]!!.jsonObject + ("details" to details))
        return StubResponse(409, JsonObject(template + ("error" to errorBody)).toString())
    }

    private fun failOnSearch(request: StubRequest): StubResponse? {
        val q = request.query["q"].orEmpty()
        if (q.contains("offline", ignoreCase = true)) throw IOException("stub offline")
        return if (q.contains("error", ignoreCase = true)) StubResponse(500, """{"error":{"code":"INTERNAL_ERROR","message_key":"ERR_SERVER","details":{}}}""") else null
    }

    private fun authorized(request: StubRequest) = request.accessToken == accessToken()

    private fun accessToken() = "at_stub_$accessGeneration"

    private fun refreshToken() = "rt_stub_$refreshGeneration"

    private fun body(name: String): JsonElement = json.parseToJsonElement(fixtures.read(name)).jsonObject["body"]!!

    private fun ok(text: String, status: Int = 200) = StubResponse(status, text)

    private fun error(fixture: String, status: Int, retryAfter: Int? = null) =
        StubResponse(status, fixtures.read(fixture), retryAfter?.let { mapOf("Retry-After" to it.toString()) }.orEmpty())

    private fun emailOf(body: String?): String =
        (json.parseToJsonElement(body.orEmpty()).jsonObject["email"] as? JsonPrimitive)?.content.orEmpty().lowercase()

    companion object {
        /** Tokens the app sent with `PUT /v1/admin/push-token` (tests read and clear it). */
        val pushTokens = java.util.concurrent.CopyOnWriteArrayList<String>()
    }
}
