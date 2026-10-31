package app.banh.customer.data.orders

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
import okhttp3.Response

private const val ORDERS_PATH = "v1/orders"
private const val IDEMPOTENCY_KEY_HEADER = "Idempotency-Key"
private const val RETRY_AFTER_HEADER = "Retry-After"
private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

/**
 * `POST /v1/orders`. [client] must carry the `X-Platform` and `X-App-Version` headers (see `HttpClients`) and the
 * 10 second call timeout of api.md section 5; a timeout surfaces as [ApiException.Timeout] (unknown outcome, retry
 * with the same key).
 */
class HttpOrderApi(
    private val client: OkHttpClient,
    baseUrl: HttpUrl,
    private val json: Json = ApiJson,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : OrderApi {
    private val ordersUrl: HttpUrl = baseUrl.newBuilder().addPathSegments(ORDERS_PATH).build()

    override suspend fun submit(request: OrderRequest, idempotencyKey: String): OrderReceipt {
        val body = json.encodeToString(OrderRequest.serializer(), request).toRequestBody(JSON_MEDIA_TYPE)
        val call = Request.Builder().url(ordersUrl).header(IDEMPOTENCY_KEY_HEADER, idempotencyKey).post(body).build()
        val response = try {
            client.newCall(call).await()
        } catch (e: IOException) {
            throw e.toApiException()
        }
        return response.use { read(it) }
    }

    private suspend fun read(response: Response): OrderReceipt = withContext(ioDispatcher) {
        try {
            if (response.isSuccessful) {
                decode(response.body.string())
            } else {
                throw parseApiError(
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

    private fun decode(body: String): OrderReceipt = try {
        json.decodeFromString(OrderReceipt.serializer(), body)
    } catch (e: SerializationException) {
        throw ApiException.InvalidResponse(e)
    } catch (e: IllegalArgumentException) {
        throw ApiException.InvalidResponse(e)
    }
}
