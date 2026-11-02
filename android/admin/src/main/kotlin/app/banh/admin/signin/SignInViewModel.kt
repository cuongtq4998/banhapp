package app.banh.admin.signin

import app.banh.admin.auth.AuthApi
import app.banh.admin.auth.SessionManager
import app.banh.core.common.MviViewModel
import app.banh.core.network.ApiException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val TICK_MILLIS = 1_000L

/** Store of S-A1 and S-A2 (one store, two steps, so "change e-mail" keeps the address, AC-3). */
class SignInViewModel(
    private val auth: AuthApi,
    private val session: SessionManager,
) : MviViewModel<SignInState, SignInIntent, Nothing>(SignInState()) {
    private var ticker: Job? = null

    // The reducer ignores a second tap while busy, but `handle` still runs; this keeps it to one request at a time.
    private var working = false

    override fun reduce(state: SignInState, intent: SignInIntent): SignInState = reduceSignIn(state, intent)

    override suspend fun handle(intent: SignInIntent) {
        when (intent) {
            SignInIntent.SendCode, SignInIntent.Resend -> if (current.busy && current.step == stepFor(intent)) requestCode()
            SignInIntent.SubmitCode -> if (current.busy) signIn()
            is SignInIntent.CodeSent -> startTicker()
            is SignInIntent.RequestFailed -> if (intent.resendSeconds != null) startTicker()
            SignInIntent.ChangeEmail -> ticker?.cancel()
            else -> Unit
        }
    }

    private fun stepFor(intent: SignInIntent) = if (intent == SignInIntent.Resend) SignInStep.CODE else SignInStep.EMAIL

    private suspend fun requestCode() {
        if (working) return
        working = true
        try {
            val answer = auth.requestCode(normalizedEmail(current.email))
            dispatch(SignInIntent.CodeSent(answer.resendAfterSeconds))
        } catch (e: ApiException) {
            dispatch(e.toRequestFailure())
        } finally {
            working = false
        }
    }

    private suspend fun signIn() {
        if (working) return
        working = true
        try {
            session.signIn(normalizedEmail(current.email), current.code)
        } catch (e: CancellationException) {
            throw e
        } catch (e: ApiException) {
            dispatch(SignInIntent.SignInFailed(e.toSignInFailure()))
        } finally {
            working = false
        }
    }

    private fun startTicker() {
        ticker?.cancel()
        ticker = scope.launch {
            while (current.resendSeconds > 0) {
                delay(TICK_MILLIS)
                dispatch(SignInIntent.Tick)
            }
        }
    }
}
