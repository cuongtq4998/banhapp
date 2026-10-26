package app.banh.customer.data.catalog

import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.await
import app.banh.customer.data.network.parseApiError
import java.io.IOException
import java.io.InterruptedIOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

private const val CATALOG_PATH = "v1/catalog"
private const val ETAG_HEADER = "ETag"
private const val IF_NONE_MATCH_HEADER = "If-None-Match"
private const val RETRY_AFTER_HEADER = "Retry-After"
private const val HTTP_NOT_MODIFIED = 304

/** Reads are tried twice: the first call after idle can fail while the free host wakes (api.md section 1). */
private const val READ_ATTEMPTS = 2

class HttpCatalogApi(
    private val client: OkHttpClient,
    baseUrl: HttpUrl,
    private val json: Json = ApiJson,
    /** Reading a body blocks, so it runs here and the caller may be on the main thread. */
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : CatalogApi {
    private val catalogUrl: HttpUrl = baseUrl.newBuilder().addPathSegments(CATALOG_PATH).build()

    override suspend fun fetchCatalog(etag: String?): CatalogResponse {
        val request = Request.Builder()
            .url(catalogUrl)
            .apply { etag?.let { header(IF_NONE_MATCH_HEADER, it) } }
            .build()
        return retryTransient { execute(request) }
    }

    private suspend fun execute(request: Request): CatalogResponse {
        val response = try {
            client.newCall(request).await()
        } catch (e: IOException) {
            throw e.toApiException()
        }
        return response.use { read(it) }
    }

    private suspend fun read(response: Response): CatalogResponse = withContext(ioDispatcher) {
        try {
            when {
                response.code == HTTP_NOT_MODIFIED -> CatalogResponse.NotModified
                response.isSuccessful -> CatalogResponse.Modified(
                    catalog = decode(response.body.string()),
                    etag = response.header(ETAG_HEADER),
                )
                else -> throw parseApiError(
                    status = response.code,
                    body = response.body.string(),
                    retryAfterHeader = response.header(RETRY_AFTER_HEADER),
                    json = json,
                )
            }
        } catch (e: IOException) {
            throw e.toApiException()
        }
    }

    private fun decode(body: String): Catalog = try {
        json.decodeFromString<Catalog>(body)
    } catch (e: SerializationException) {
        throw ApiException.InvalidResponse(e)
    } catch (e: IllegalArgumentException) {
        throw ApiException.InvalidResponse(e)
    }

    private suspend fun <T> retryTransient(block: suspend () -> T): T {
        repeat(READ_ATTEMPTS - 1) {
            try {
                return block()
            } catch (e: ApiException) {
                if (!e.isTransient) throw e
            }
        }
        return block()
    }
}

// OkHttp reports its call timeout as an InterruptedIOException; SocketTimeoutException is a subclass.
private fun IOException.toApiException(): ApiException =
    if (this is InterruptedIOException) ApiException.Timeout(this) else ApiException.NetworkUnavailable(this)
