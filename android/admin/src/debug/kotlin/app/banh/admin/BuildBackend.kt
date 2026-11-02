package app.banh.admin

import android.app.Activity
import android.content.Context
import android.content.Intent
import app.banh.admin.stub.StubBackend
import app.banh.admin.stub.StubInterceptor
import app.banh.admin.stub.StubPhotoChooser
import app.banh.admin.stub.StubTokenProvider
import java.io.File
import okhttp3.HttpUrl.Companion.toHttpUrl

private const val PREFERENCES = "admin_debug"
private const val KEY_BACKEND = "backend"
private const val STUB = "stub"
private const val LOCAL = "local"

/**
 * Debug builds: the backend is chosen at run time. `local` (default) talks to BuildConfig.API_BASE_URL, which is the emulator's alias
 * of the developer machine (`http://10.0.2.2:8080/`); `stub` answers from contracts/fixtures/admin, so UI tests and screenshots need no server.
 * Launch extras: `backend` = `stub` or `local`, `reset` (default true) = forget the stored session first.
 */
object BuildBackend {
    const val EXTRA_BACKEND = "backend"
    const val EXTRA_RESET = "reset"

    fun config(context: Context): BackendConfig {
        val mode = preferences(context).getString(KEY_BACKEND, LOCAL)
        if (mode != STUB) return BackendConfig(configuredBaseUrl())
        val fixtures = StubBackend.Fixtures { name -> context.assets.open("admin-fixtures/$name.json").bufferedReader().use { it.readText() } }
        return BackendConfig("http://stub.invalid/".toHttpUrl(), listOf(StubInterceptor(StubBackend(fixtures))), photos = StubPhotoChooser(context), tokens = StubTokenProvider)
    }

    fun handleLaunch(activity: Activity, intent: Intent?, firstLaunch: Boolean) {
        val mode = intent?.getStringExtra(EXTRA_BACKEND)
        if (mode == null || !firstLaunch) return
        preferences(activity).edit().putString(KEY_BACKEND, if (mode == STUB) STUB else LOCAL).commit()
        if (intent.getBooleanExtra(EXTRA_RESET, true)) File(activity.noBackupFilesDir, "admin-session.bin").delete()
        (activity.application as AdminApplication).rebuild()
    }

    private fun preferences(context: Context) = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
