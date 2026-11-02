package app.banh.admin.push

import app.banh.admin.auth.SessionEndedException
import app.banh.admin.testing.offline
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PushTest {
    private class FakeProvider(override val available: Boolean = true, var token: String? = "tok-1") : TokenProvider {
        var forgotten = 0

        override suspend fun token() = token

        override suspend fun forget() {
            forgotten++
            token = null
        }
    }

    private class FakeApi : PushApi {
        val sent = mutableListOf<String>()
        var failure: Throwable? = null

        override suspend fun register(token: String) {
            failure?.let { throw it }
            sent += token
        }
    }

    private val provider = FakeProvider()
    private val api = FakeApi()
    private val shown = mutableListOf<PushMessage>()
    private val hub = PushHub(provider, api, MemoryAskedFlag()) { shown += it }

    @Test
    fun theQuestionIsAskedOnceAndARefusalIsFinalAndSilent() {
        assertEquals(PushStep.ASK, decidePush(available = true, granted = false, alreadyAsked = false))
        assertEquals(PushStep.NOTHING, decidePush(available = true, granted = false, alreadyAsked = true))
        assertEquals(PushStep.REGISTER, decidePush(available = true, granted = true, alreadyAsked = true))
        assertEquals(PushStep.REGISTER, decidePush(available = true, granted = true, alreadyAsked = false))
        assertEquals(PushStep.NOTHING, decidePush(available = false, granted = false, alreadyAsked = false))
        assertEquals(PushStep.NOTHING, decidePush(available = false, granted = true, alreadyAsked = false))
    }

    @Test
    fun registerSendsTheTokenOnceAndAgainOnlyWhenItChanges() = runTest {
        hub.register()
        hub.register()
        provider.token = "tok-2"
        hub.register()
        assertEquals(listOf("tok-1", "tok-2"), api.sent)
        assertEquals("tok-2", hub.lastRegistered)
    }

    @Test
    fun noTokenMeansNoCall() = runTest {
        provider.token = null
        hub.register()
        assertTrue(api.sent.isEmpty())
        val off = PushHub(NoTokenProvider, api, MemoryAskedFlag())
        off.register()
        assertTrue(api.sent.isEmpty())
    }

    @Test
    fun aFailedRegistrationIsQuietAndTriedAgainNextTime() = runTest {
        api.failure = offline()
        hub.register()
        assertNull(hub.lastRegistered)
        api.failure = SessionEndedException()
        hub.register()
        api.failure = null
        hub.register()
        assertEquals(listOf("tok-1"), api.sent)
    }

    @Test
    fun forgetClearsTheTokenHereAndLetsTheNextSignInRegisterAgain() = runTest {
        hub.register()
        hub.forget()
        assertEquals(1, provider.forgotten)
        assertNull(hub.lastRegistered)
        provider.token = "tok-1"
        hub.register()
        assertEquals(listOf("tok-1", "tok-1"), api.sent)
    }

    @Test
    fun aMessageIsAToastWhileOpenAndANotificationOtherwise() = runTest {
        val message = PushMessage("BT-1", "2", "03/11/2026")
        hub.deliver(message)
        assertEquals(listOf(message), shown)
        hub.setForeground(true)
        val received = mutableListOf<PushMessage>()
        val job = launch(Dispatchers.Unconfined) { hub.foregroundMessages.collect { received += it } }
        hub.deliver(message)
        job.cancel()
        assertEquals(listOf(message), received)
        assertEquals(1, shown.size)
    }

    @Test
    fun theRequestedOrderIsKeptUntilItIsOpened() {
        hub.requestOrder("BT-9")
        assertEquals("BT-9", hub.requestedOrder.value)
        hub.orderOpened()
        assertNull(hub.requestedOrder.value)
    }
}
