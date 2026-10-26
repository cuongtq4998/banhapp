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
private const val IMAGE_CACHE_BYTES = 20L * 1024 * 1024

object HttpClients {
    /** Client for API calls. No HTTP cache: the catalog has its own cache with a 7 day rule (ADR-0011). */
    fun createApiClient(appVersion: String): OkHttpClient = OkHttpClient.Builder()
        .callTimeout(READ_CALL_TIMEOUT)
        .addInterceptor(clientHeaders(appVersion))
        .build()

    /** Product images use the platform HTTP cache (ADR-0011): the same client plus an on-disk cache. */
    fun createImageClient(apiClient: OkHttpClient, cacheDirectory: File): OkHttpClient = apiClient.newBuilder()
        .cache(Cache(cacheDirectory, IMAGE_CACHE_BYTES))
        .build()

    // The backend logs these on every call to see which app versions are in use (api.md section 6).
    internal fun clientHeaders(appVersion: String) = Interceptor { chain ->
        chain.proceed(
            chain.request().newBuilder()
                .header(PLATFORM_HEADER, PLATFORM_ANDROID)
                .header(APP_VERSION_HEADER, appVersion)
                .build(),
        )
    }
}
