package app.banh.customer.data.network

import java.io.IOException
import java.io.InterruptedIOException

/** Reads are tried twice: the first call after idle can fail while the free host wakes (api.md section 1). */
private const val READ_ATTEMPTS = 2

/** Runs a read and repeats it once when it failed in a way that can pass on the next try. */
internal suspend fun <T> retryTransient(block: suspend () -> T): T {
    repeat(READ_ATTEMPTS - 1) {
        try {
            return block()
        } catch (e: ApiException) {
            if (!e.isTransient) throw e
        }
    }
    return block()
}

// OkHttp reports its call timeout as an InterruptedIOException; SocketTimeoutException is a subclass.
internal fun IOException.toApiException(): ApiException =
    if (this is InterruptedIOException) ApiException.Timeout(this) else ApiException.NetworkUnavailable(this)
