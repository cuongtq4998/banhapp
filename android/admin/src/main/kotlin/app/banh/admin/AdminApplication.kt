package app.banh.admin

import android.app.Application
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
        container = AdminContainer.create(this, BuildBackend.config(this))
        applicationScope.launch { container.session.restore() }
    }
}
