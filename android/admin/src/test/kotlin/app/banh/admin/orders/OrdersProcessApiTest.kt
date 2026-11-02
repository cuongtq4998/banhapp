package app.banh.admin.orders

import app.banh.admin.auth.StoredSession
import app.banh.admin.testing.FakeAuthApi
import app.banh.admin.testing.Fixtures
import app.banh.admin.testing.MemoryVault
import app.banh.admin.testing.newSession
import app.banh.core.model.OrderStatus
import app.banh.core.network.ApiClient
import app.banh.core.network.ApiException
import app.banh.core.network.ApiJson
import kotlinx.coroutines.test.runTest
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class OrdersProcessApiTest {
    private val requests = mutableListOf<okhttp3.Request>()
    private var answer: Pair<Int, String> = 200 to Fixtures.body("order-detail-delivery-started")

    private val http = OkHttpClient.Builder().addInterceptor(
        Interceptor { chain ->
            requests += chain.request()
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(answer.first).message("x")
                .body(answer.second.toResponseBody("application/json".toMediaType())).build()
        },
    ).build()
    private val session = newSession(FakeAuthApi(), MemoryVault(StoredSession("rt")))
    private val api = HttpOrdersApi(ApiClient(http, "http://x.invalid/".toHttpUrl()), session)

    private fun sentBody(): String = okio.Buffer().also { requests.last().body!!.writeTo(it) }.readUtf8()

    private fun fails(name: String, status: Int): OrderRuleError? {
        answer = status to Fixtures.text(name)
        return try {
            kotlinx.coroutines.runBlocking { api.changeExpectedDate("BT-7K3M9Q", "2026-11-05", "2026-11-20") }
            fail("expected a failure")
            null
        } catch (e: ApiException.Http) {
            e.toRuleError(ApiJson)
        }
    }

    @Test
    fun scheduleAndStartDeliverySendTheirExtrasOnTheStatusRoute() = runTest {
        session.restore()
        api.changeStatus("BT-7K3M9Q", OrderStatus.Processing, OrderStatus.DeliveryDateScheduled, expectedDate = "2026-11-05")
        assertTrue(sentBody().contains("\"to_status\":\"DeliveryDateScheduled\",\"expected_delivery_date\":\"2026-11-05\""))
        api.changeStatus("BT-7K3M9Q", OrderStatus.DeliveryDateScheduled, OrderStatus.DeliveryStarted, feeVnd = 0)
        assertTrue(sentBody().contains("\"delivery_fee_vnd\":0"))
    }

    @Test
    fun dateAndFeeCorrectionsUsePutWithThePreviousValue() = runTest {
        session.restore()
        api.changeExpectedDate("BT-7K3M9Q", "2026-11-05", "2026-11-06")
        assertEquals("PUT", requests.last().method)
        assertTrue(requests.last().url.encodedPath.endsWith("/orders/BT-7K3M9Q/expected-delivery-date"))
        assertTrue(sentBody().contains("\"expected_status\":\"DeliveryDateScheduled\",\"previous_expected_delivery_date\":\"2026-11-05\",\"expected_delivery_date\":\"2026-11-06\""))

        api.correctFee("BT-7K3M9Q", 25000, 30000)
        assertTrue(requests.last().url.encodedPath.endsWith("/delivery-fee"))
        assertTrue(sentBody().contains("\"previous_delivery_fee_vnd\":25000,\"delivery_fee_vnd\":30000"))
    }

    @Test
    fun aConflictOnEitherPutReturnsTheCurrentOrder() = runTest {
        session.restore()
        answer = 409 to Fixtures.text("error-order-state-changed-fee")
        val result = api.correctFee("BT-7K3M9Q", 25000, 30000) as StatusChange.Conflict
        assertEquals(35000L, result.current.deliveryFeeFinalVnd)
    }

    @Test
    fun rulesMapToTheirErrors() {
        kotlinx.coroutines.runBlocking { session.restore() }
        assertEquals(OrderRuleError.DatePast(null).javaClass, fails("error-validation-expected-date-past", 422)?.javaClass)
        val far = fails("error-validation-expected-date-too-far", 422) as OrderRuleError.DateTooFar
        assertEquals("2026-11-09", far.range?.max)
        assertEquals(OrderRuleError.FeeInvalid, fails("error-validation-fee-invalid", 422))
        assertEquals(OrderRuleError.FeeRequired, fails("error-validation-fee-required", 422))
        assertEquals(OrderRuleError.FeeCorrectionNotAllowed, fails("error-fee-correction-not-allowed", 422))
        assertEquals(OrderRuleError.TransitionInvalid, fails("error-status-transition-invalid", 422))
        assertEquals(OrderRuleError.TransitionInvalid, fails("error-status-transition-invalid-cancel", 422))
    }
}
