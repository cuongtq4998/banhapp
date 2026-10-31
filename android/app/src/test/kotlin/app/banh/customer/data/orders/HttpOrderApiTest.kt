package app.banh.customer.data.orders

import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.HttpClients
import app.banh.customer.testing.ContractFixtures
import app.banh.customer.testing.fixtureOrderRequest
import app.banh.customer.testing.fixtureReceipt
import java.io.IOException
import java.io.InterruptedIOException
import kotlinx.coroutines.test.runTest
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** `POST /v1/orders` (api/03-orders.md): headers, body, and the answers of the order-* fixtures. */
class HttpOrderApiTest {
    private val requests = mutableListOf<Request>()
    private var sentBody = ""

    private fun answer(code: Int, text: String = "", headers: Map<String, String> = emptyMap()): (Interceptor.Chain) -> Response = { chain ->
        val builder = Response.Builder()
            .request(chain.request())
            .protocol(Protocol.HTTP_1_1)
            .code(code)
            .message("scripted")
            .body(text.toResponseBody("application/json".toMediaType()))
        headers.forEach { (name, value) -> builder.header(name, value) }
        builder.build()
    }

    private fun apiAnswering(vararg script: (Interceptor.Chain) -> Response): HttpOrderApi {
        val queue = ArrayDeque(script.toList())
        val client = OkHttpClient.Builder()
            .addInterceptor(HttpClients.clientHeaders("1.2.3"))
            .addInterceptor(
                Interceptor { chain ->
                    requests += chain.request()
                    sentBody = Buffer().also { buffer -> chain.request().body?.writeTo(buffer) }.readUtf8()
                    queue.removeFirst()(chain)
                },
            )
            .build()
        return HttpOrderApi(client, "http://api.test/".toHttpUrl())
    }

    private fun fixtureBody(name: String): String =
        ApiJson.parseToJsonElement(ContractFixtures.read(name)).let { (it as kotlinx.serialization.json.JsonObject).getValue("body").toString() }

    private suspend fun failureOf(api: HttpOrderApi): ApiException = try {
        api.submit(fixtureOrderRequest(), "key-1")
        fail("expected a failure")
        error("unreachable")
    } catch (e: ApiException) {
        e
    }

    @Test
    fun sendsTheContractBodyWithTheThreeHeaders() = runTest {
        val api = apiAnswering(answer(201, fixtureBody("order-created.json")))

        val receipt = api.submit(fixtureOrderRequest(), "5e0c2f6a-4c47-4a0e-9b6e-0f3a5d9c1a10")

        assertEquals(fixtureReceipt(), receipt)
        val request = requests.single()
        assertEquals("POST", request.method)
        assertEquals("http://api.test/v1/orders", request.url.toString())
        assertEquals("5e0c2f6a-4c47-4a0e-9b6e-0f3a5d9c1a10", request.header("Idempotency-Key"))
        assertEquals("android", request.header("X-Platform"))
        assertEquals("1.2.3", request.header("X-App-Version"))
        assertEquals(ApiJson.parseToJsonElement(ContractFixtures.read("order-request.json")), ApiJson.parseToJsonElement(sentBody))
    }

    // AC-19: the replay answers 200 with the same body.
    @Test
    fun aReplayIsASuccessWithTheSameReceipt() = runTest {
        val api = apiAnswering(answer(200, fixtureBody("order-replay.json"), mapOf("Idempotent-Replay" to "true")))

        assertEquals(fixtureReceipt(), api.submit(fixtureOrderRequest(), "key-1"))
    }

    @Test
    fun aBodyThatIsNotTheContractIsInvalid() = runTest {
        val failure = failureOf(apiAnswering(answer(201, "<html>")))

        assertTrue(failure is ApiException.InvalidResponse)
    }

    // Unknown outcome: no automatic retry, the caller decides (same key).
    @Test
    fun timeoutAndNoConnectionAreTypedAndNotRepeated() = runTest {
        val timeout = apiAnswering({ throw InterruptedIOException("timeout") })
        assertTrue(failureOf(timeout) is ApiException.Timeout)
        assertEquals(1, requests.size)

        val offline = apiAnswering({ throw IOException("down") })
        assertTrue(failureOf(offline) is ApiException.NetworkUnavailable)
        assertEquals(2, requests.size)
    }

    @Test
    fun errorFixturesKeepTheirDetailsAndFields() = runTest {
        val priceChanged = failureOf(apiAnswering(answer(409, ContractFixtures.read("order-error-price-changed.json")))) as ApiException.Service
        assertEquals(ApiErrorCode.PRICE_CHANGED, priceChanged.code)
        assertEquals("MSG_PRICE_CHANGED", priceChanged.messageKey)
        assertTrue(priceChanged.details!!.containsKey("total_vnd"))

        val invalid = failureOf(apiAnswering(answer(422, ContractFixtures.read("order-error-validation-failed.json")))) as ApiException.Service
        assertEquals(listOf("NAME_REQUIRED", "PHONE_INVALID"), invalid.fields.map { it.code })
        assertEquals(listOf("customer.name", "customer.phone"), invalid.fields.map { it.field })
    }

    @Test
    fun rateLimitedCarriesRetryAfter() = runTest {
        val failure = failureOf(apiAnswering(answer(429, ContractFixtures.read("order-error-rate-limited.json"), mapOf("Retry-After" to "3600"))))

        assertEquals(3600, (failure as ApiException.RateLimited).retryAfterSeconds)
    }
}
