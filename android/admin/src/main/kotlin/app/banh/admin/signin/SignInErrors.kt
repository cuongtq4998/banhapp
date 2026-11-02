package app.banh.admin.signin

import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import kotlin.math.ceil

private const val SECONDS_PER_MINUTE = 60.0
private const val DEFAULT_WAIT_SECONDS = 3600

/** Maps a failed code request to the intent the store reduces. */
internal fun ApiException.toRequestFailure(): SignInIntent.RequestFailed = when {
    isOffline -> SignInIntent.RequestFailed(SignInError.Offline)
    this !is ApiException.Http -> SignInIntent.RequestFailed(SignInError.Generic)
    code == ErrorCodes.CODE_RESEND_WAIT -> SignInIntent.RequestFailed(SignInError.Generic, resendSeconds = retryAfterSeconds ?: 0)
    code == ErrorCodes.CODE_REQUEST_LIMIT || code == ErrorCodes.RATE_LIMITED -> SignInIntent.RequestFailed(SignInError.RateLimited(minutesOf(retryAfterSeconds)))
    code == ErrorCodes.VALIDATION_FAILED -> SignInIntent.RequestFailed(SignInError.EmailInvalid)
    else -> SignInIntent.RequestFailed(SignInError.Generic)
}

/** Maps a failed sign-in (code entry) to its error. Unknown address and wrong code look the same on purpose (api/05 10.2). */
internal fun ApiException.toSignInFailure(): SignInError = when {
    isOffline -> SignInError.Offline
    this !is ApiException.Http -> SignInError.Generic
    code == ErrorCodes.CODE_EXPIRED -> SignInError.CodeExpired
    code == ErrorCodes.CODE_INVALID || code == ErrorCodes.VALIDATION_FAILED -> SignInError.CodeWrong
    code == ErrorCodes.RATE_LIMITED -> SignInError.RateLimited(minutesOf(retryAfterSeconds))
    else -> SignInError.Generic
}

internal fun minutesOf(seconds: Int?): Int = ceil((seconds ?: DEFAULT_WAIT_SECONDS) / SECONDS_PER_MINUTE).toInt().coerceAtLeast(1)
