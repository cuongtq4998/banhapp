package app.banh.customer.data.catalog

import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.HttpClients
import app.banh.customer.testing.ContractFixtures
import app.banh.customer.testing.SampleCatalogJson
import java.io.IOException
import java.net.SocketTimeoutException
import kotlinx.coroutines.test.runTest
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** Runs the real client against scripted answers placed in the OkHttp chain, so no socket is opened. */
class HttpCatalogApiTest {
    private val requests = mutableListOf<Request>()

    private fun answer(code: Int, body: String = "", headers: Map<String, String> = emptyMap()): (Interceptor.Chain) -> Response = { chain ->
        Response.Builder()
            .request(chain.request())
            .protocol(Protocol.HTTP_1_1)
            .code(code)
            .message("scripted")
            .apply { headers.forEach { (name, value) -> header(name, value) } }
            .body(body.toResponseBody("application/json".toMediaType()))
            .build()
    }

    private fun apiAnswering(vararg script: (Interceptor.Chain) -> Response): HttpCatalogApi {
        val queue = ArrayDeque(script.toList())
        val client = OkHttpClient.Builder()
            .addInterceptor(Interceptor { chain ->
                requests += chain.request()
                queue.removeFirst()(chain)
            })
            .build()
        return HttpCatalogApi(client, "http://api.test/".toHttpUrl())
    }

    private val catalogBody get() = SampleCatalogJson.BODY

    @Test
    fun requestsTheVersionedCatalogPathWithoutEtagWhenNoneIsKnown() = runTest {
        val api = apiAnswering(answer(200, catalogBody))

        api.fetchCatalog(null)

        assertEquals("http://api.test/v1/catalog", requests.single().url.toString())
        assertNull(requests.single().header("If-None-Match"))
    }

    @Test
    fun decodesTheBodyAndReturnsTheEtag() = runTest {
        val api = apiAnswering(answer(200, catalogBody, mapOf("ETag" to "\"abc\"")))

        val response = api.fetchCatalog("\"old\"") as CatalogResponse.Modified

        assertEquals("\"abc\"", response.etag)
        assertEquals("\"old\"", requests.single().header("If-None-Match"))
        assertTrue(response.catalog.products.isNotEmpty())
    }

    @Test
    fun notModifiedHasNoBody() = runTest {
        val api = apiAnswering(answer(304))

        assertEquals(CatalogResponse.NotModified, api.fetchCatalog("\"abc\""))
    }

    @Test
    fun errorBodyBecomesATypedServiceError() = runTest {
        val api = apiAnswering(answer(503, """{"error":{"code":"SERVICE_UNAVAILABLE","message_key":"ERR_SERVER"},"request_id":"r-1"}"""))

        val error = failureOf { api.fetchCatalog(null) } as ApiException.Service

        assertEquals(ApiErrorCode.SERVICE_UNAVAILABLE, error.code)
        assertEquals("r-1", error.requestId)
    }

    @Test
    fun rateLimitIsNotRetried() = runTest {
        val body = ContractFixtures.read("error-rate-limited.json")
        val api = apiAnswering(answer(429, body, mapOf("Retry-After" to "30")))

        val error = failureOf { api.fetchCatalog(null) } as ApiException.RateLimited

        assertEquals(30, error.retryAfterSeconds)
        assertEquals(1, requests.size)
    }

    @Test
    fun bodyThatDoesNotMatchTheContractIsInvalid() = runTest {
        val api = apiAnswering(answer(200, """{"unexpected":true}"""))

        assertTrue(failureOf { api.fetchCatalog(null) } is ApiException.InvalidResponse)
    }

    @Test
    fun transientFailureIsRetriedOnce() = runTest {
        val api = apiAnswering({ throw IOException("reset") }, answer(200, catalogBody))

        assertTrue(api.fetchCatalog(null) is CatalogResponse.Modified)
        assertEquals(2, requests.size)
    }

    @Test
    fun secondTransientFailureIsReportedAsNetworkUnavailable() = runTest {
        val api = apiAnswering({ throw IOException("reset") }, { throw IOException("reset") })

        assertTrue(failureOf { api.fetchCatalog(null) } is ApiException.NetworkUnavailable)
        assertEquals(2, requests.size)
    }

    @Test
    fun timeoutIsReportedAsTimeout() = runTest {
        val api = apiAnswering({ throw SocketTimeoutException("slow") }, { throw SocketTimeoutException("slow") })

        assertTrue(failureOf { api.fetchCatalog(null) } is ApiException.Timeout)
    }

    @Test
    fun clientHeadersNameThePlatformAndVersion() {
        val client = OkHttpClient.Builder()
            .addInterceptor(HttpClients.clientHeaders("1.2.3"))
            .addInterceptor(Interceptor { chain ->
                requests += chain.request()
                answer(200)(chain)
            })
            .build()

        client.newCall(Request.Builder().url("http://api.test/x").build()).execute().close()

        assertEquals("android", requests.single().header("X-Platform"))
        assertEquals("1.2.3", requests.single().header("X-App-Version"))
    }

    private inline fun failureOf(block: () -> Unit): ApiException {
        try {
            block()
        } catch (e: ApiException) {
            return e
        }
        fail("Expected an ApiException")
        error("unreachable")
    }
}
