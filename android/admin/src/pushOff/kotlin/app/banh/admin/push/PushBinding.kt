package app.banh.admin.push

import android.content.Context

/** Build without a Firebase config (the repository default): push is off, nothing asks for the notification permission. */
object PushBinding {
    @Suppress("UNUSED_PARAMETER")
    fun provider(context: Context): TokenProvider = NoTokenProvider
}
