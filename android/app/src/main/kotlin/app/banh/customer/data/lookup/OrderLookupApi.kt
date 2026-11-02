package app.banh.customer.data.lookup

import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.await
import app.banh.customer.data.network.parseApiError
import app.banh.customer.data.network.toApiException
import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

private const val LOOKUP_PATH = "v1/orders/lookup"
private const val RETRY_AFTER_HEADER = "Retry-After"
private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

/** Customer order lookup by phone (api/10). Failures are thrown as [ApiException]. */
interface OrderLookupApi {
    suspend fun lookup(phone: String, cursor: String?): LookupAnswer
}

/** `POST /v1/orders/lookup` over the shared customer client; the phone goes in the body only, never in a URL or log. */
class HttpOrderLookupApi(
    private val client: OkHttpClient,
    baseUrl: HttpUrl,
    private val json: Json = ApiJson,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : OrderLookupApi {
    private val url: HttpUrl = baseUrl.newBuilder().addPathSegments(LOOKUP_PATH).build()

    override suspend fun lookup(phone: String, cursor: String?): LookupAnswer {
        val body = json.encodeToString(LookupRequest.serializer(), LookupRequest(phone, cursor))
        val call = Request.Builder().url(url).post(body.toRequestBody(JSON_MEDIA_TYPE)).build()
        val response = try {
            client.newCall(call).await()
        } catch (e: IOException) {
            throw e.toApiException()
        }
        return withContext(ioDispatcher) {
            response.use {
                try {
                    val text = it.body.string()
                    if (!it.isSuccessful) throw parseApiError(it.code, text, it.header(RETRY_AFTER_HEADER), json)
                    decode(text)
                } catch (e: IOException) {
                    throw e.toApiException()
                }
            }
        }
    }

    private fun decode(text: String): LookupAnswer = try {
        json.decodeFromString(LookupAnswer.serializer(), text)
    } catch (e: SerializationException) {
        throw ApiException.InvalidResponse(e)
    } catch (e: IllegalArgumentException) {
        throw ApiException.InvalidResponse(e)
    }
}
