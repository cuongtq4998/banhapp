package app.banh.admin.testing

import app.banh.admin.auth.AuthApi
import app.banh.admin.auth.InstallationId
import app.banh.admin.auth.SessionManager
import app.banh.admin.auth.StoredSession
import app.banh.admin.auth.TokenVault
import app.banh.core.model.Account
import app.banh.core.model.CodeRequested
import app.banh.core.model.Me
import app.banh.core.model.Role
import app.banh.core.model.SessionCreated
import app.banh.core.model.SignInRequest
import app.banh.core.model.TokenPair
import app.banh.core.network.ApiException
import java.io.File
import java.io.IOException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject

class MemoryVault(var stored: StoredSession? = null) : TokenVault {
    override fun load() = stored

    override fun save(session: StoredSession) {
        stored = session
    }

    override fun clear() {
        stored = null
    }
}

fun httpError(status: Int, code: String, retryAfter: Int? = null) =
    ApiException.Http(status, code, "ERR", null, null, emptyList(), retryAfter)

/** Records calls; each endpoint answers from a queue of results (a Throwable is thrown). */
class FakeAuthApi : AuthApi {
    val refreshTokensSeen = mutableListOf<String>()
    val bearersSeen = mutableListOf<String>()
    var refreshResults = ArrayDeque<Any>()
    var meResults = ArrayDeque<Any>()
    var signOutResult: Throwable? = null
    var signOutCalls = 0
    var othersCalls = 0
    private var counter = 0

    fun nextPair() = TokenPair("at_${++counter}", "rt_$counter", 300)

    override suspend fun requestCode(email: String) = CodeRequested(30, 600)

    override suspend fun signIn(request: SignInRequest) =
        SessionCreated("at_0", "rt_0", 300, "dev", Account("A", Role.STAFF), "2026-11-02")

    override suspend fun refresh(refreshToken: String): TokenPair {
        refreshTokensSeen += refreshToken
        return when (val r = refreshResults.removeFirstOrNull() ?: nextPair()) {
            is Throwable -> throw r
            else -> r as TokenPair
        }
    }

    override suspend fun me(accessToken: String): Me {
        bearersSeen += accessToken
        return when (val r = meResults.removeFirstOrNull() ?: Me(Account("A", Role.STAFF), "dev", "2026-11-02")) {
            is Throwable -> throw r
            else -> r as Me
        }
    }

    override suspend fun signOut(accessToken: String) {
        signOutCalls++
        signOutResult?.let { throw it }
    }

    override suspend fun signOutOthers(accessToken: String) {
        othersCalls++
    }
}

fun newSession(auth: AuthApi, vault: TokenVault) = SessionManager(auth, vault, InstallationId { "install" }, "Test device")

fun offline() = ApiException.Network(IOException("offline"))

object Fixtures {
    private val json = Json { ignoreUnknownKeys = true }
    private val dir = File(checkNotNull(System.getProperty("contracts.fixtures.dir")), "admin")

    fun text(name: String): String = File(dir, "$name.json").readText()

    fun body(name: String): String = json.parseToJsonElement(text(name)).jsonObject.getValue("body").toString()
}
