package app.banh.admin.push

/**
 * Where the phone's push token comes from. The real one is Firebase Messaging, which needs a Firebase project config that is not in
 * this repository (see `docs/engineering/dev-guide.md`); everything else in the app talks to this interface only.
 */
interface TokenProvider {
    /** False when no push service is built in: the app then never asks for the notification permission and never registers. */
    val available: Boolean

    /** The current token, or null when none can be had now. */
    suspend fun token(): String?

    /** Drops the token on this phone (sign-out): a later sign-in gets a fresh one. The server clears its copy itself (api/06 10.8). */
    suspend fun forget()
}

/** Push is off: no Firebase config in this build. */
object NoTokenProvider : TokenProvider {
    override val available = false

    override suspend fun token(): String? = null

    override suspend fun forget() = Unit
}
