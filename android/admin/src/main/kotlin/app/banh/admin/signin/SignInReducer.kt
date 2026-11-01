package app.banh.admin.signin

import app.banh.core.design.sanitizeOtp

private const val MAX_EMAIL = 254
private val EMAIL_FORMAT = Regex("""^[^@\s]+@[^@\s]+\.[^@\s]+$""")

/** Format only (BR-4): the server decides whether the address is registered and never says so. */
fun isEmailFormat(text: String): Boolean = text.length <= MAX_EMAIL && EMAIL_FORMAT.matches(text)

/** The address as the server wants it: trimmed (the server lower-cases it). */
fun normalizedEmail(text: String): String = text.trim()

/** Pure state transitions of S-A1 and S-A2; the network work is in `SignInViewModel`. */
fun reduceSignIn(state: SignInState, intent: SignInIntent): SignInState = when (intent) {
    is SignInIntent.EmailChanged -> state.copy(email = intent.text.take(MAX_EMAIL), error = state.error.takeIf { it == SignInError.EmailInvalid })
    SignInIntent.SendCode -> sendCode(state)
    is SignInIntent.CodeSent -> state.copy(step = SignInStep.CODE, busy = false, code = "", error = null, resendSeconds = intent.resendSeconds)
    is SignInIntent.RequestFailed -> failRequest(state, intent)
    is SignInIntent.CodeChanged -> state.copy(code = sanitizeOtp(intent.text), error = null)
    SignInIntent.SubmitCode -> if (state.canSubmit) state.copy(busy = true, error = null) else state
    is SignInIntent.SignInFailed -> state.copy(busy = false, code = "", error = intent.error, shakeKey = state.shakeKey + 1)
    SignInIntent.Resend -> if (state.step == SignInStep.CODE && state.canResend) state.copy(busy = true, error = null) else state
    SignInIntent.Tick -> state.copy(resendSeconds = (state.resendSeconds - 1).coerceAtLeast(0))
    SignInIntent.ChangeEmail -> state.copy(step = SignInStep.EMAIL, code = "", error = null, resendSeconds = 0, busy = false)
}

private fun sendCode(state: SignInState): SignInState = when {
    state.busy -> state
    !isEmailFormat(normalizedEmail(state.email)) -> state.copy(triedEmail = true, error = SignInError.EmailInvalid)
    else -> state.copy(triedEmail = true, busy = true, error = null)
}

private fun failRequest(state: SignInState, intent: SignInIntent.RequestFailed): SignInState {
    // A resend wait means a code was just sent already: the person goes on to enter it (S-A2) with the wait that is left.
    val wait = intent.resendSeconds
    return if (wait != null) {
        state.copy(step = SignInStep.CODE, busy = false, error = null, resendSeconds = wait)
    } else {
        state.copy(busy = false, error = intent.error)
    }
}
