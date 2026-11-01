package app.banh.admin.push

import app.banh.admin.auth.SessionEndedException
import app.banh.core.network.ApiException
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/** What a notification says, and nothing more (FR-26): the order code, the cake count and the delivery date as text. */
data class PushMessage(val orderCode: String, val cakes: String? = null, val date: String? = null)

/** Shows a system notification for a message that arrives while the app is in the background and the system did not draw one. */
fun interface PushNotifier {
    fun show(message: PushMessage)
}

/**
 * The app's push logic, free of Android classes so a fake [TokenProvider] tests all of it: registering the token, the foreground
 * message (toast), the order a tap asks for (kept in memory only until the session can open it), and forgetting on sign-out.
 */
class PushHub(
    val provider: TokenProvider,
    private val api: PushApi,
    val askedFlag: AskedFlag,
    private val notifier: PushNotifier = PushNotifier {},
) {
    private val registered = MutableStateFlow<String?>(null)
    private val mutableForeground = MutableSharedFlow<PushMessage>(extraBufferCapacity = BUFFER)
    private val mutableOrder = MutableStateFlow<String?>(null)
    private val visible = AtomicBoolean(false)

    /** Messages that arrived while the app was open: the root shows `A_NOTIF_FOREGROUND` for each. */
    val foregroundMessages: SharedFlow<PushMessage> = mutableForeground.asSharedFlow()

    /** The order code a notification tap asked for; the signed-in root opens S-A4 for it and clears it. Never written to disk. */
    val requestedOrder: StateFlow<String?> = mutableOrder.asStateFlow()

    /** The token last sent to the server in this process (tests read it). */
    val lastRegistered: String? get() = registered.value

    fun setForeground(value: Boolean) = visible.set(value)

    fun deliver(message: PushMessage) {
        if (visible.get()) mutableForeground.tryEmit(message) else notifier.show(message)
    }

    fun requestOrder(code: String) {
        mutableOrder.value = code
    }

    fun orderOpened() {
        mutableOrder.value = null
    }

    /** Sends the current token. Failures are quiet: the next start or the next new token tries again (nothing depends on it). */
    suspend fun register() {
        val token = provider.token() ?: return
        if (token == registered.value) return
        try {
            api.register(token)
            registered.value = token
        } catch (e: CancellationException) {
            throw e
        } catch (_: SessionEndedException) {
            Unit
        } catch (_: ApiException) {
            Unit
        }
    }

    /** Sign-out, by any path: forget the token here (the server stops sending at once, AC-44). */
    suspend fun forget() {
        registered.value = null
        provider.forget()
    }

    private companion object {
        const val BUFFER = 4
    }
}
