package app.banh.customer.data.availability

import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.testing.ContractFixtures
import java.io.IOException
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** `GET /v1/availability` (api.md 4.2): the shared fixture, the request, and the failures. */
class AvailabilityApiTest {
    private val requests = mutableListOf<Request>()
    private val body get() = ContractFixtures.read("availability-ok.json")

    private fun answer(code: Int, text: String = ""): (Interceptor.Chain) -> Response = { chain ->
        Response.Builder()
            .request(chain.request())
            .protocol(Protocol.HTTP_1_1)
            .code(code)
            .message("scripted")
            .body(text.toResponseBody("application/json".toMediaType()))
            .build()
    }

    private fun apiAnswering(vararg script: (Interceptor.Chain) -> Response): HttpAvailabilityApi {
        val queue = ArrayDeque(script.toList())
        val client = OkHttpClient.Builder()
            .addInterceptor(Interceptor { chain ->
                requests += chain.request()
                queue.removeFirst()(chain)
            })
            .build()
        return HttpAvailabilityApi(client, "http://api.test/".toHttpUrl())
    }

    @Test
    fun fixtureDecodesWithReasonsAsTheContractDescribesThem() {
        val availability = ApiJson.decodeFromString<Availability>(body)

        assertEquals("2026-11-02", availability.serverDate)
        assertEquals(31, availability.dates.size)
        assertEquals(UnavailableReason.TOO_SOON, availability.dates[0].unavailableReason)
        assertEquals(UnavailableReason.TOO_SOON, availability.dates[1].unavailableReason)
        assertNull(availability.dates[2].unavailableReason)
        assertEquals("2026-11-05", availability.dates[3].date)
        assertEquals(UnavailableReason.FULL, availability.dates[3].unavailableReason)
        assertTrue(availability.dates.last().available)
    }

    @Test
    fun unknownReasonIsTreatedAsFullSoTheDateStaysClosed() {
        val entry = AvailableDate(date = "2026-11-09", available = false, reason = "SOMETHING_NEW")

        assertEquals(UnavailableReason.FULL, entry.unavailableReason)
    }

    @Test
    fun requestsTheVersionedPathWithTheCakeCount() = runTest {
        val api = apiAnswering(answer(200, body))

        val availability = api.fetchAvailability(cakes = 3)

        assertEquals("http://api.test/v1/availability?cakes=3", requests.single().url.toString())
        assertEquals(31, availability.dates.size)
        assertFalse(availability.dates[0].available)
    }

    @Test
    fun validationErrorBecomesATypedServiceError() = runTest {
        val rejected = """{"error":{"code":"VALIDATION_FAILED","message_key":"ERR_SERVER","fields":[{"field":"cakes","code":"CAKES_INVALID","message_key":"ERR_SERVER"}]},"request_id":"r-2"}"""
        val api = apiAnswering(answer(422, rejected))

        val error = failureOf { api.fetchAvailability(0) } as ApiException.Service

        assertEquals(ApiErrorCode.VALIDATION_FAILED, error.code)
        assertEquals(1, requests.size)
    }

    @Test
    fun transientFailureIsRetriedOnce() = runTest {
        val api = apiAnswering({ throw IOException("reset") }, answer(200, body))

        assertEquals(31, api.fetchAvailability(2).dates.size)
        assertEquals(2, requests.size)
    }

    @Test
    fun bodyThatDoesNotMatchTheContractIsInvalid() = runTest {
        val api = apiAnswering(answer(200, """{"unexpected":true}"""))

        assertTrue(failureOf { api.fetchAvailability(2) } is ApiException.InvalidResponse)
    }

    private suspend fun failureOf(block: suspend () -> Unit): ApiException {
        try {
            block()
        } catch (e: ApiException) {
            return e
        }
        fail("expected an ApiException")
        error("unreachable")
    }
}
