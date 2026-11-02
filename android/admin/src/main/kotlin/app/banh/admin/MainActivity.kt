package app.banh.admin

import android.content.Intent
import android.graphics.Color
import app.banh.admin.push.EXTRA_ORDER_CODE
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import app.banh.admin.ui.AdminRoot

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val transparentLight = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
        enableEdgeToEdge(statusBarStyle = transparentLight, navigationBarStyle = transparentLight)
        // Debug builds may switch to the stub backend through intent extras (UI tests, screenshots); release does nothing.
        BuildBackend.handleLaunch(this, intent, savedInstanceState == null)
        val container = (application as AdminApplication).container
        openRequestedOrder(intent)
        setContent { AdminRoot(container) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openRequestedOrder(intent)
    }

    override fun onStart() {
        super.onStart()
        (application as AdminApplication).container.push.setForeground(true)
    }

    override fun onStop() {
        (application as AdminApplication).container.push.setForeground(false)
        super.onStop()
    }

    // A tap on a new-order notification carries the order code; the signed-in root opens S-A4 for it (FR-26).
    private fun openRequestedOrder(intent: Intent?) {
        intent?.getStringExtra(EXTRA_ORDER_CODE)?.takeIf { it.isNotBlank() }?.let { (application as AdminApplication).container.push.requestOrder(it) }
    }
}
