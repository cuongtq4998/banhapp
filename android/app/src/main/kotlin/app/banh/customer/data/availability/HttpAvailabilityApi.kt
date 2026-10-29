package app.banh.customer.data.availability

import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.await
import app.banh.customer.data.network.parseApiError
import app.banh.customer.data.network.retryTransient
import app.banh.customer.data.network.toApiException
import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

private const val AVAILABILITY_PATH = "v1/availability"
private const val CAKES_PARAMETER = "cakes"
private const val RETRY_AFTER_HEADER = "Retry-After"

class HttpAvailabilityApi(
    private val client: OkHttpClient,
    baseUrl: HttpUrl,
    private val json: Json = ApiJson,
    /** Reading a body blocks, so it runs here and the caller may be on the main thread. */
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : AvailabilityApi {
    private val availabilityUrl: HttpUrl = baseUrl.newBuilder().addPathSegments(AVAILABILITY_PATH).build()

    override suspend fun fetchAvailability(cakes: Int): Availability {
        val url = availabilityUrl.newBuilder().addQueryParameter(CAKES_PARAMETER, cakes.toString()).build()
        val request = Request.Builder().url(url).build()
        return retryTransient { execute(request) }
    }

    private suspend fun execute(request: Request): Availability {
        val response = try {
            client.newCall(request).await()
        } catch (e: IOException) {
            throw e.toApiException()
        }
        return response.use { read(it) }
    }

    private suspend fun read(response: Response): Availability = withContext(ioDispatcher) {
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

    private fun decode(body: String): Availability = try {
        json.decodeFromString<Availability>(body)
    } catch (e: SerializationException) {
        throw ApiException.InvalidResponse(e)
    } catch (e: IllegalArgumentException) {
        throw ApiException.InvalidResponse(e)
    }
}
