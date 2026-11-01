package app.banh.admin.ui

import android.app.Activity
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import app.banh.admin.BuildConfig

/**
 * Keeps customer data out of the task switcher and screenshots while S-A3 and S-A4 are on screen (BR-7, AC-45).
 * Debug builds skip it so that the emulator screenshots of the test plan can be taken.
 */
@Composable
fun SecureWindow() {
    if (BuildConfig.DEBUG) return
    val window = (LocalContext.current as? Activity)?.window ?: return
    DisposableEffect(window) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        onDispose { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
    }
}
