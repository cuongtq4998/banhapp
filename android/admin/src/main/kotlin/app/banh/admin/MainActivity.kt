package app.banh.admin

import android.graphics.Color
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
        setContent { AdminRoot(container) }
    }
}
