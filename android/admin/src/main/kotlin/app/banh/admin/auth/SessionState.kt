package app.banh.admin.auth

import app.banh.core.model.Account

/** What the app root shows. Anything but [SignedIn] means no customer data may be on screen or in memory (BR-7). */
sealed interface SessionState {
    /** The app started with a stored token and is renewing it. */
    data object Restoring : SessionState

    /** Renewing failed without an answer from the server (offline): the token is kept, the person can retry. */
    data object RestoreFailed : SessionState

    /**
     * [ended] is true when the server ended the session (any 401), so S-A1 shows `A_SESSION_ENDED`; [offline] is true after a
     * sign-out whose server call failed, so S-A1 shows `A_OFFLINE_SIGNOUT`.
     */
    data class SignedOut(val ended: Boolean = false, val offline: Boolean = false) : SessionState

    /** [id] changes with every sign-in, so screens keyed on it start empty. */
    data class SignedIn(val account: Account, val email: String?, val id: Long) : SessionState
}

/** Thrown to callers after the session was ended by a 401; the root has already moved to S-A1, so callers ignore it. */
class SessionEndedException : Exception("Session ended")
