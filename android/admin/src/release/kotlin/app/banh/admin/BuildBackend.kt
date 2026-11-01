package app.banh.admin

import android.app.Activity
import android.content.Context
import android.content.Intent

/** Release: the configured HTTPS host only. No stub, no fixtures, no debug switch. */
object BuildBackend {
    fun config(context: Context): BackendConfig = BackendConfig(configuredBaseUrl())

    @Suppress("UNUSED_PARAMETER")
    fun handleLaunch(activity: Activity, intent: Intent?, firstLaunch: Boolean) = Unit
}
