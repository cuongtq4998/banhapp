package app.banh.admin.auth

import app.banh.core.model.SignInRequest
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Owns the credentials (ADR-0022): the access token in memory, the refresh token in the [TokenVault]. Every authorised call goes
 * through [authorized], which renews an expired access token once (single flight, rotation) and ends the session on a 401 that
 * cannot be repaired. A network failure while renewing keeps the stored token, so a retry inside the 20 s grace window works.
 */
class SessionManager(
    private val auth: AuthApi,
    private val vault: TokenVault,
    private val installation: InstallationId,
    private val deviceName: String,
) {
    private val refreshLock = Mutex()
    private val generation = AtomicLong(0)

    @Volatile
    private var accessToken: String? = null

    private val mutableState = MutableStateFlow<SessionState>(SessionState.Restoring)
    val state: StateFlow<SessionState> = mutableState.asStateFlow()

    /** Reads the vault at app start: finishes a pending sign-out, or renews the session and loads the account. */
    suspend fun restore() {
        val stored = vault.load()
        if (stored == null) {
            mutableState.value = SessionState.SignedOut()
        } else if (stored.pendingSignOut) {
            finishPendingSignOut(stored)
        } else {
            mutableState.value = SessionState.Restoring
            try {
                val me = authorized { auth.me(it) }
                mutableState.value = SessionState.SignedIn(me.account, email = me.email, id = generation.incrementAndGet())
            } catch (_: SessionEndedException) {
                Unit // endSession already moved to SignedOut(ended = true)
            } catch (e: ApiException) {
                if (e is ApiException.Http && e.status == UNAUTHORIZED) endSession() else mutableState.value = SessionState.RestoreFailed
            }
        }
    }

    suspend fun signIn(email: String, code: String) {
        val created = auth.signIn(SignInRequest(email, code, installation.get(), deviceName))
        vault.save(StoredSession(created.refreshToken))
        accessToken = created.accessToken
        mutableState.value = SessionState.SignedIn(created.account, email, generation.incrementAndGet())
    }

    /** Runs [block] with a valid access token; see the class comment. */
    suspend fun <T> authorized(block: suspend (accessToken: String) -> T): T {
        val first = accessToken ?: refreshLocked(stale = null)
        try {
            return block(first)
        } catch (e: ApiException.Http) {
            if (e.status != UNAUTHORIZED) throw e
            // api/08: an expired or an unrecognised access token gets one renewal; a revoked or ended session does not.
            if (e.code != ErrorCodes.ACCESS_TOKEN_EXPIRED && e.code != ErrorCodes.UNAUTHENTICATED) return failSession()
        }
        val second = refreshLocked(stale = first)
        try {
            return block(second)
        } catch (e: ApiException.Http) {
            if (e.status == UNAUTHORIZED) return failSession()
            throw e
        }
    }

    suspend fun signOutOthers() {
        authorized { auth.signOutOthers(it) }
    }

    /**
     * Clears the phone first, so no customer data survives even offline (BR-7), then tells the server. When the server cannot
     * be reached only the refresh token stays, flagged, and the call is repeated at the next start (TQ-D6). Returns false then.
     */
    suspend fun signOut(): Boolean {
        val stored = vault.load()
        val token = accessToken
        accessToken = null
        vault.clear()
        mutableState.value = SessionState.SignedOut()
        if (stored == null) return true
        val reached = remoteSignOut(stored.copy(pendingSignOut = true), token)
        if (!reached) mutableState.value = SessionState.SignedOut(offline = true)
        return reached
    }

    private suspend fun finishPendingSignOut(stored: StoredSession) {
        remoteSignOut(stored, accessToken = null)
        mutableState.value = SessionState.SignedOut()
    }

    private suspend fun remoteSignOut(stored: StoredSession, accessToken: String?): Boolean {
        var kept = stored
        try {
            val token = accessToken ?: auth.refresh(stored.refreshToken).also {
                kept = StoredSession(it.refreshToken, pendingSignOut = true)
            }.accessToken
            auth.signOut(token)
        } catch (e: ApiException.Http) {
            if (e.status != UNAUTHORIZED) vault.save(kept) // 401 means the server already forgot this phone
            else vault.clear()
            return e.status == UNAUTHORIZED
        } catch (e: ApiException) {
            vault.save(kept)
            return false
        }
        vault.clear()
        return true
    }

    private suspend fun refreshLocked(stale: String?): String = refreshLock.withLock {
        accessToken?.let { if (it != stale) return it }
        val stored = vault.load() ?: return failSession()
        try {
            val pair = auth.refresh(stored.refreshToken)
            // The new refresh token is stored before anything uses the pair: the old one is dead once the grace window ends.
            vault.save(stored.copy(refreshToken = pair.refreshToken))
            accessToken = pair.accessToken
            pair.accessToken
        } catch (e: ApiException.Http) {
            if (e.status == UNAUTHORIZED) failSession() else throw e
        }
    }

    private fun endSession() {
        accessToken = null
        vault.clear()
        mutableState.value = SessionState.SignedOut(ended = true)
    }

    private fun failSession(): Nothing {
        endSession()
        throw SessionEndedException()
    }

    companion object {
        private const val UNAUTHORIZED = 401
    }
}
