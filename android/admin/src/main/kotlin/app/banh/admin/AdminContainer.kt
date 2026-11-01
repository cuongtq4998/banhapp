package app.banh.admin

import android.content.Context
import android.os.Build
import app.banh.admin.auth.AuthApi
import app.banh.admin.auth.FileInstallationId
import app.banh.admin.auth.HttpAuthApi
import app.banh.admin.auth.KeystoreTokenVault
import app.banh.admin.auth.SessionManager
import app.banh.admin.auth.TokenVault
import app.banh.admin.orders.HttpOrdersApi
import app.banh.admin.orders.OrderChanges
import app.banh.admin.orders.OrdersApi
import app.banh.admin.orders.ServerDateHolder
import app.banh.core.network.ApiClient
import app.banh.core.network.HttpClients
import java.io.File
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor

private const val SESSION_FILE = "admin-session.bin"
private const val INSTALLATION_FILE = "installation-id"

/** Where the app talks to: a base URL and, in debug builds, an interceptor that answers from fixtures instead of the network. */
class BackendConfig(val baseUrl: HttpUrl, val interceptors: List<Interceptor> = emptyList())

/** Manual wiring of the app's services (ADR-0007: no DI framework). One instance lives as long as the process (or until debug switches backend). */
class AdminContainer(
    val session: SessionManager,
    val auth: AuthApi,
    val orders: OrdersApi,
    val orderChanges: OrderChanges = OrderChanges(),
    val serverDate: ServerDateHolder = ServerDateHolder(),
) {
    /** Id of the latest sign-in; the sign-in screens use it as their scope key so each sign-out starts a blank form. */
    @Volatile
    var signInPeriod: Long = 0

    companion object {
        fun create(context: Context, backend: BackendConfig, vault: TokenVault? = null): AdminContainer {
            val http = HttpClients.createApiClient(BuildConfig.VERSION_NAME, backend.interceptors)
            val client = ApiClient(http, backend.baseUrl)
            val auth = HttpAuthApi(client)
            val session = SessionManager(
                auth = auth,
                // Session data lives in no_backup storage and is excluded from backup (ADR-0022).
                vault = vault ?: KeystoreTokenVault(File(context.noBackupFilesDir, SESSION_FILE)),
                installation = FileInstallationId(File(context.noBackupFilesDir, INSTALLATION_FILE)),
                deviceName = deviceName(),
            )
            return AdminContainer(session, auth, HttpOrdersApi(client, session))
        }

        // "<Manufacturer> <Model> (Android 14)" (api/05 10.2): never a name the person chose.
        private fun deviceName(): String =
            "${Build.MANUFACTURER} ${Build.MODEL} (Android ${Build.VERSION.RELEASE})".take(DEVICE_NAME_MAX)

        private const val DEVICE_NAME_MAX = 60
    }
}

/** The release backend: the URL from BuildConfig, nothing else. Debug builds replace this in `src/debug`. */
fun configuredBaseUrl(): HttpUrl = BuildConfig.API_BASE_URL.toHttpUrl()
