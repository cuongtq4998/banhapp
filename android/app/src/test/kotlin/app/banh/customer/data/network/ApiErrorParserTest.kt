package app.banh.customer.data.network

import app.banh.customer.testing.ContractFixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ApiErrorParserTest {
    private fun parse(status: Int, body: String, retryAfter: String? = null) = parseApiError(status, body, retryAfter, ApiJson)

    @Test
    fun readsTheContractEnvelopeOfAFixture() {
        val error = parse(409, ContractFixtures.read("error-date-capacity.json")) as ApiException.Service

        assertEquals(ApiErrorCode.DATE_CAPACITY, error.code)
        assertEquals("ERR_DATE_CAPACITY", error.messageKey)
        assertEquals(409, error.httpStatus)
    }

    @Test
    fun ignoresFieldErrorsItDoesNotModel() {
        val error = parse(422, ContractFixtures.read("error-validation-failed.json")) as ApiException.Service

        assertEquals(ApiErrorCode.VALIDATION_FAILED, error.code)
    }

    @Test
    fun routingErrorIsNotFound() {
        val error = parse(404, ContractFixtures.read("error-not-found.json")) as ApiException.Service

        assertEquals(ApiErrorCode.NOT_FOUND, error.code)
    }

    @Test
    fun rateLimitCarriesRetryAfterFromTheBody() {
        val error = parse(429, ContractFixtures.read("error-rate-limited.json"), retryAfter = "99") as ApiException.RateLimited

        assertEquals(30, error.retryAfterSeconds)
    }

    @Test
    fun rateLimitFallsBackToTheHeaderThenToSixtySeconds() {
        val noDetails = """{"error":{"code":"RATE_LIMITED","message_key":"ERR_RATE_LIMITED"}}"""

        assertEquals(15, (parse(429, noDetails, retryAfter = " 15 ") as ApiException.RateLimited).retryAfterSeconds)
        assertEquals(60, (parse(429, noDetails) as ApiException.RateLimited).retryAfterSeconds)
    }

    @Test
    fun unknownCodeBehavesLikeInternalError() {
        val body = """{"error":{"code":"SOMETHING_NEW","message_key":"ERR_SERVER"}}"""

        assertEquals(ApiErrorCode.INTERNAL_ERROR, (parse(500, body) as ApiException.Service).code)
    }

    @Test
    fun bodyThatIsNotTheEnvelopeIsClassifiedByStatus() {
        assertEquals(ApiErrorCode.SERVICE_UNAVAILABLE, (parse(503, "<html>Bad gateway</html>") as ApiException.Service).code)
        assertEquals(ApiErrorCode.INTERNAL_ERROR, (parse(500, "") as ApiException.Service).code)
        assertTrue(parse(429, "not json") is ApiException.RateLimited)
    }

    @Test
    fun serviceErrorsFallBackToTheGenericMessageKey() {
        assertEquals("ERR_SERVER", (parse(500, "") as ApiException.Service).messageKey)
    }
}
