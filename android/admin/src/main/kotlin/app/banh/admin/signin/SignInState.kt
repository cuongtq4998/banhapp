package app.banh.admin.signin

enum class SignInStep { EMAIL, CODE }

/** What went wrong, as the screen needs to say it (copy keys in docs/design/admin-orders/08). */
sealed interface SignInError {
    data object EmailInvalid : SignInError

    /** 3 codes an hour used (AC-4); the text names the minutes to wait. */
    data class RateLimited(val minutes: Int) : SignInError

    data object Generic : SignInError

    data object Offline : SignInError

    data object CodeWrong : SignInError

    /** Expired, or voided by 5 wrong entries: the same text, the person asks for a new code (AC-2). */
    data object CodeExpired : SignInError
}

data class SignInState(
    val step: SignInStep = SignInStep.EMAIL,
    val email: String = "",
    val code: String = "",
    val busy: Boolean = false,
    val error: SignInError? = null,
    val resendSeconds: Int = 0,
    /** Counts wrong codes; the code field shakes once per change. */
    val shakeKey: Int = 0,
    /** True after the first send attempt, so the format message waits until then (S-A1 Validation). */
    val triedEmail: Boolean = false,
) {
    val canSend: Boolean get() = email.isNotBlank() && !busy
    val canSubmit: Boolean get() = code.length == CODE_LENGTH && !busy
    val canResend: Boolean get() = resendSeconds == 0 && !busy

    companion object {
        const val CODE_LENGTH = 6
    }
}

sealed interface SignInIntent {
    data class EmailChanged(val text: String) : SignInIntent

    data object SendCode : SignInIntent

    data class CodeSent(val resendSeconds: Int) : SignInIntent

    data class RequestFailed(val error: SignInError, val resendSeconds: Int? = null) : SignInIntent

    data class CodeChanged(val text: String) : SignInIntent

    data object SubmitCode : SignInIntent

    data class SignInFailed(val error: SignInError) : SignInIntent

    data object Resend : SignInIntent

    data object Tick : SignInIntent

    data object ChangeEmail : SignInIntent
}
