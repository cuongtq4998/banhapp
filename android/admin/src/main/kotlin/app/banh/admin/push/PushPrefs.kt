package app.banh.admin.push

import android.content.Context

/** [AskedFlag] kept in the app's preferences (not in the session file: it must survive sign-out, so the question is asked once per phone). */
class PrefsAskedFlag(context: Context) : AskedFlag {
    private val prefs = context.getSharedPreferences("admin_push", Context.MODE_PRIVATE)

    override var asked: Boolean
        get() = prefs.getBoolean(KEY, false)
        set(value) = prefs.edit().putBoolean(KEY, value).apply()

    private companion object {
        const val KEY = "asked"
    }
}
