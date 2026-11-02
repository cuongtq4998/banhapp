package app.banh.admin

import android.app.Application
import app.banh.admin.auth.SessionState
import app.banh.admin.push.OrderNotifier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class AdminApplication : Application() {
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    lateinit var container: AdminContainer
        private set

    override fun onCreate() {
        super.onCreate()
        rebuild()
    }

    /** Builds the services again; debug builds call it after the backend was switched. */
    fun rebuild() {
        val built = AdminContainer.create(this, BuildBackend.config(this))
        container = built
        OrderNotifier(this).ensureChannel()
        applicationScope.launch { built.session.restore() }
        // Whatever ends a sign-in (sign-out, a 401, a switch-off), the push token is forgotten on this phone (AC-44).
        applicationScope.launch { built.session.state.collect { if (it is SessionState.SignedOut) built.push.forget() } }
    }
}
