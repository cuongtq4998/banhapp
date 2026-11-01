package app.banh.core.network

import java.io.IOException
import java.io.InterruptedIOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

/** One decoder for every API body; unknown response fields are ignored (api/01 section 6). */
val ApiJson: Json = Json { ignoreUnknownKeys = true }

/** A 2xx answer: the body text (empty for 204) and the headers the app reads. */
class ApiResponse(val status: Int, val body: String, val headers: Map<String, String>)

private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

/** Thin typed layer over OkHttp: JSON in, JSON out, non-2xx turned into [ApiException.Http]. Holds no tokens. */
class ApiClient(private val http: OkHttpClient, private val baseUrl: HttpUrl, val json: Json = ApiJson) {
    suspend fun execute(
        method: String,
        path: String,
        query: List<Pair<String, String>> = emptyList(),
        jsonBody: String? = null,
        headers: Map<String, String> = emptyMap(),
        /** A prepared body (multipart upload); takes the place of [jsonBody]. */
        body: RequestBody? = null,
    ): ApiResponse {
        val url = baseUrl.newBuilder().addPathSegments(path.trimStart('/')).apply {
            query.forEach { (name, value) -> addQueryParameter(name, value) }
        }.build()
        val builder = Request.Builder().url(url)
        headers.forEach { (name, value) -> builder.header(name, value) }
        builder.method(method, body ?: jsonBody?.toRequestBody(JSON_MEDIA_TYPE) ?: if (method == "POST") "".toRequestBody() else null)
        val response = try {
            http.newCall(builder.build()).await()
        } catch (e: IOException) {
            throw if (e is InterruptedIOException) ApiException.Timeout(e) else ApiException.Network(e)
        }
        return response.use { read(it) }
    }

    private fun read(response: Response): ApiResponse {
        val text = try {
            response.body.string()
        } catch (e: IOException) {
            throw ApiException.Network(e)
        }
        if (!response.isSuccessful) throw parseHttpError(response.code, text, response.header("Retry-After"), json)
        return ApiResponse(response.code, text, response.headers.toMultimap().mapValues { it.value.first() })
    }

    suspend fun <T> get(path: String, serializer: KSerializer<T>, query: List<Pair<String, String>> = emptyList(), headers: Map<String, String> = emptyMap()): T =
        decode(execute("GET", path, query, null, headers), serializer)

    suspend fun <T, B> post(path: String, body: B, bodySerializer: KSerializer<B>, serializer: KSerializer<T>, headers: Map<String, String> = emptyMap()): T =
        decode(execute("POST", path, jsonBody = json.encodeToString(bodySerializer, body), headers = headers), serializer)

    fun <T> decode(response: ApiResponse, serializer: KSerializer<T>): T = try {
        json.decodeFromString(serializer, response.body)
    } catch (e: SerializationException) {
        throw ApiException.InvalidResponse(e)
    } catch (e: IllegalArgumentException) {
        throw ApiException.InvalidResponse(e)
    }
}

/** Runs the call without blocking the caller's thread and cancels the call when the coroutine is cancelled. */
internal suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    continuation.invokeOnCancellation { cancel() }
    enqueue(
        object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (continuation.isActive) continuation.resume(response) else response.close()
            }

            override fun onFailure(call: Call, e: IOException) {
                if (continuation.isActive) continuation.resumeWithException(e)
            }
        },
    )
}
