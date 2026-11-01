package app.banh.core.network

import java.time.Duration
import okhttp3.Interceptor
import okhttp3.OkHttpClient

private const val PLATFORM_HEADER = "X-Platform"
private const val APP_VERSION_HEADER = "X-App-Version"
private val CALL_TIMEOUT: Duration = Duration.ofSeconds(15)
private val APP_VERSION_PATTERN = Regex("""^\d+\.\d+\.\d+""")
private const val UNKNOWN_APP_VERSION = "0.0.0"

object HttpClients {
    /** Client for API calls; the headers of api/05 section 9 go on every request. [extra] lets debug builds add the stub. */
    fun createApiClient(appVersion: String, extra: List<Interceptor> = emptyList()): OkHttpClient =
        OkHttpClient.Builder()
            .callTimeout(CALL_TIMEOUT)
            .addInterceptor(clientHeaders(appVersion))
            .apply { extra.forEach(::addInterceptor) }
            .build()

    // The header holds digits only (`N.N.N`): a suffix such as `-debug` would be refused with HEADER_INVALID.
    internal fun clientHeaders(appVersion: String) = Interceptor { chain ->
        val version = APP_VERSION_PATTERN.find(appVersion)?.value ?: UNKNOWN_APP_VERSION
        chain.proceed(
            chain.request().newBuilder()
                .header(PLATFORM_HEADER, "android")
                .header(APP_VERSION_HEADER, version)
                .build(),
        )
    }
}
