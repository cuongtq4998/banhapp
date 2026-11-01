package app.banh.admin.auth

import app.banh.admin.testing.FakeAuthApi
import app.banh.admin.testing.MemoryVault
import app.banh.admin.testing.httpError
import app.banh.admin.testing.newSession
import app.banh.admin.testing.offline
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SessionManagerTest {
    private val auth = FakeAuthApi()
    private val vault = MemoryVault(StoredSession("rt_old"))
    private val session = newSession(auth, vault)

    @Test
    fun signInKeepsTheRefreshTokenOnDiskAndTheAccessTokenOnlyInMemory() = runTest {
        vault.clear()
        session.signIn("a@example.com", "123456")

        assertEquals("rt_0", vault.load()?.refreshToken)
        assertTrue(session.state.value is SessionState.SignedIn)
    }

    @Test
    fun restoreRefreshesStoresTheRotatedTokenAndLoadsTheAccount() = runTest {
        session.restore()

        assertEquals(listOf("rt_old"), auth.refreshTokensSeen)
        assertEquals("rt_1", vault.load()?.refreshToken)
        assertEquals(listOf("at_1"), auth.bearersSeen)
        assertTrue(session.state.value is SessionState.SignedIn)
    }

    @Test
    fun expiredAccessTokenIsRefreshedOnceAndTheCallRepeated() = runTest {
        session.restore()
        var calls = 0
        val result = session.authorized { token ->
            calls++
            if (calls == 1) throw httpError(401, ErrorCodes.ACCESS_TOKEN_EXPIRED)
            token
        }

        assertEquals("at_2", result)
        assertEquals(2, calls)
        assertEquals("rt_2", vault.load()?.refreshToken)
    }

    @Test
    fun concurrentExpiredCallsShareOneRefresh() = runTest {
        session.restore()
        val stale = "at_1"
        val a = session.authorized { if (it == stale) throw httpError(401, ErrorCodes.ACCESS_TOKEN_EXPIRED) else it }
        val b = session.authorized { if (it == stale) throw httpError(401, ErrorCodes.ACCESS_TOKEN_EXPIRED) else it }

        // The second call starts with the already renewed token: no second refresh.
        assertEquals(listOf("rt_old", "rt_1"), auth.refreshTokensSeen)
        assertEquals(a, b)
    }

    @Test
    fun revokedSessionClearsTheTokenAndEndsTheSession() = runTest {
        session.restore()
        try {
            session.authorized<Unit> { throw httpError(401, ErrorCodes.SESSION_REVOKED) }
            fail()
        } catch (_: SessionEndedException) {
        }

        assertNull(vault.load())
        assertEquals(SessionState.SignedOut(ended = true), session.state.value)
    }

    @Test
    fun refreshRejectedWith401EndsTheSession() = runTest {
        auth.refreshResults.add(httpError(401, ErrorCodes.SESSION_REVOKED))
        session.restore()

        assertNull(vault.load())
        assertEquals(SessionState.SignedOut(ended = true), session.state.value)
    }

    @Test
    fun lostRefreshResponseKeepsTheOldTokenSoARetryInsideTheGraceWindowWorks() = runTest {
        auth.refreshResults.add(offline())
        session.restore()
        assertEquals(SessionState.RestoreFailed, session.state.value)
        assertEquals("rt_old", vault.load()?.refreshToken)

        session.restore()

        assertEquals(listOf("rt_old", "rt_old"), auth.refreshTokensSeen)
        assertTrue(session.state.value is SessionState.SignedIn)
    }

    @Test
    fun serverErrorWhileRefreshingKeepsTheSession() = runTest {
        session.restore()
        try {
            session.authorized<Unit> { throw httpError(503, ErrorCodes.SERVICE_UNAVAILABLE) }
            fail()
        } catch (e: ApiException.Http) {
            assertEquals(503, e.status)
        }
        assertEquals("rt_1", vault.load()?.refreshToken)
    }

    @Test
    fun signOutClearsThePhoneFirstAndTellsTheServer() = runTest {
        session.restore()
        assertTrue(session.signOut())

        assertNull(vault.load())
        assertEquals(1, auth.signOutCalls)
        assertEquals(SessionState.SignedOut(), session.state.value)
    }

    @Test
    fun offlineSignOutKeepsOnlyAPendingRefreshTokenAndRepeatsAtNextStart() = runTest {
        session.restore()
        auth.signOutResult = offline()
        assertEquals(false, session.signOut())
        assertEquals(true, vault.load()?.pendingSignOut)
        assertEquals(SessionState.SignedOut(offline = true), session.state.value)

        auth.signOutResult = null
        newSession(auth, vault).restore()

        assertNull(vault.load())
        assertEquals(2, auth.signOutCalls)
    }

    @Test
    fun signOutOthersGoesThroughAuthorizedCall() = runTest {
        session.restore()
        session.signOutOthers()
        assertEquals(1, auth.othersCalls)
    }
}
