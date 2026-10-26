package app.banh.customer

import android.content.Context
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.DefaultCatalogRepository
import app.banh.customer.data.catalog.FileCatalogCache
import app.banh.customer.data.catalog.HttpCatalogApi
import app.banh.customer.data.network.HttpClients
import app.banh.customer.ui.common.ImageLoader
import app.banh.customer.ui.common.OkHttpImageLoader
import java.io.File
import java.time.Clock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.HttpUrl.Companion.toHttpUrl

private const val CATALOG_CACHE_FILE = "catalog-cache.json"
private const val IMAGE_CACHE_DIRECTORY = "http-images"

/** Manual wiring of the app's services (ADR-0007: no DI framework). One instance lives as long as the process. */
class AppContainer(context: Context) {
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val apiBaseUrl = BuildConfig.API_BASE_URL.toHttpUrl()
    private val apiClient = HttpClients.createApiClient(BuildConfig.VERSION_NAME)

    val catalogRepository: CatalogRepository = DefaultCatalogRepository(
        api = HttpCatalogApi(apiClient, apiBaseUrl),
        cache = FileCatalogCache(File(context.noBackupFilesDir, CATALOG_CACHE_FILE)),
        clock = Clock.systemUTC(),
    )

    val imageLoader: ImageLoader = OkHttpImageLoader(
        client = HttpClients.createImageClient(apiClient, File(context.cacheDir, IMAGE_CACHE_DIRECTORY)),
        baseUrl = apiBaseUrl,
    )

    /** Starts the work that must not wait for a screen: loading the catalog also wakes a sleeping host (ADR-0003). */
    fun start() {
        applicationScope.launch { catalogRepository.refresh() }
    }
}
