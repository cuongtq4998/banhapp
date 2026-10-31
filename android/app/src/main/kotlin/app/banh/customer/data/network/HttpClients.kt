package app.banh.customer.data.network

import java.io.File
import java.time.Duration
import okhttp3.Cache
import okhttp3.Interceptor
import okhttp3.OkHttpClient

private const val PLATFORM_HEADER = "X-Platform"
private const val APP_VERSION_HEADER = "X-App-Version"
private const val PLATFORM_ANDROID = "android"

/** Reads time out after 15 s (api.md section 1, ADR-0007). */
private val READ_CALL_TIMEOUT: Duration = Duration.ofSeconds(15)
/** Creating an order waits at most 10 s; after that the outcome is unknown and the customer retries with the same key (api.md section 5). */
private val ORDER_CALL_TIMEOUT: Duration = Duration.ofSeconds(10)
private val APP_VERSION_PATTERN = Regex("""^\d+\.\d+\.\d+""")
private const val UNKNOWN_APP_VERSION = "0.0.0"
private const val IMAGE_CACHE_BYTES = 20L * 1024 * 1024

object HttpClients {
    /** Client for API calls. No HTTP cache: the catalog has its own cache with a 7 day rule (ADR-0011). */
    fun createApiClient(appVersion: String): OkHttpClient = OkHttpClient.Builder()
        .callTimeout(READ_CALL_TIMEOUT)
        .addInterceptor(clientHeaders(appVersion))
        .build()

    /** Client for `POST /v1/orders`: the API client with the 10 s timeout of an order. */
    fun createOrderClient(apiClient: OkHttpClient): OkHttpClient = apiClient.newBuilder()
        .callTimeout(ORDER_CALL_TIMEOUT)
        .build()

    /** Product images use the platform HTTP cache (ADR-0011): the same client plus an on-disk cache. */
    fun createImageClient(apiClient: OkHttpClient, cacheDirectory: File): OkHttpClient = apiClient.newBuilder()
        .cache(Cache(cacheDirectory, IMAGE_CACHE_BYTES))
        .build()

    // The backend logs these on every call to see which app versions are in use (api.md section 6).
    // The header holds digits only (`N.N.N`, api.md 4.3): a suffix such as `-debug` would be refused with HEADER_INVALID.
    internal fun clientHeaders(appVersion: String) = Interceptor { chain ->
        val version = APP_VERSION_PATTERN.find(appVersion)?.value ?: UNKNOWN_APP_VERSION
        chain.proceed(
            chain.request().newBuilder()
                .header(PLATFORM_HEADER, PLATFORM_ANDROID)
                .header(APP_VERSION_HEADER, version)
                .build(),
        )
    }
}
