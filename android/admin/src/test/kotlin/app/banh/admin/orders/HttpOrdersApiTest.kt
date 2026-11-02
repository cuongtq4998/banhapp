package app.banh.admin.orders

import app.banh.admin.testing.FakeAuthApi
import app.banh.admin.testing.Fixtures
import app.banh.admin.testing.MemoryVault
import app.banh.admin.testing.newSession
import app.banh.admin.auth.StoredSession
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderStatus
import app.banh.core.network.ApiClient
import java.time.LocalDate
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
import org.junit.Test

class HttpOrdersApiTest {
    private val requests = mutableListOf<okhttp3.Request>()
    private var answer: Pair<Int, String> = 200 to Fixtures.body("orders-list")

    private val http = OkHttpClient.Builder().addInterceptor(
        Interceptor { chain ->
            requests += chain.request()
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(answer.first).message("x")
                .body(answer.second.toResponseBody("application/json".toMediaType())).build()
        },
    ).build()
    private val session = newSession(FakeAuthApi(), MemoryVault(StoredSession("rt")))
    private val api = HttpOrdersApi(ApiClient(http, "http://x.invalid/".toHttpUrl()), session)

    @Test
    fun listSendsTheFilterTheSearchAndTheBearerToken() = runTest {
        session.restore()
        val page = api.list(OrdersQuery(StatusFilter.RECEIVED, DateFilter.One(LocalDate.parse("2026-11-03")), "tran"), cursor = "c1")

        val url = requests.last().url
        assertEquals("Received", url.queryParameter("status"))
        assertEquals("2026-11-03", url.queryParameter("delivery_date"))
        assertEquals("tran", url.queryParameter("q"))
        assertEquals("c1", url.queryParameter("cursor"))
        assertEquals("Bearer at_1", requests.last().header("Authorization"))
        assertEquals(1, page.unfinishedCount)
        assertEquals("BT-7K3M9Q", page.items.single().orderCode)
    }

    @Test
    fun defaultQueryIsToDoWithoutDateOrSearch() {
        assertEquals(listOf("status" to "todo"), OrdersQuery().toParameters(null))
    }

    @Test
    fun conflictAnswerCarriesTheCurrentOrder() = runTest {
        session.restore()
        answer = 409 to Fixtures.text("error-order-state-changed")

        val result = api.changeStatus("BT-7K3M9Q", OrderStatus.Received, OrderStatus.Processing, null)

        assertTrue(result is StatusChange.Conflict)
        assertEquals(OrderStatus.Processing, (result as StatusChange.Conflict).current.status)
    }

    @Test
    fun cancelSendsExpectedStatusAndReason() = runTest {
        session.restore()
        answer = 200 to Fixtures.body("order-status-change")

        val result = api.changeStatus("BT-7K3M9Q", OrderStatus.Received, OrderStatus.Cancelled, CancelReason.CUSTOMER_ASKED)

        val sent = requests.last()
        assertEquals("POST", sent.method)
        val buffer = okio.Buffer().also { sent.body!!.writeTo(it) }.readUtf8()
        assertTrue(buffer.contains("\"expected_status\":\"Received\""))
        assertTrue(buffer.contains("\"cancel_reason\":\"customer_asked\""))
        assertEquals(OrderStatus.Cancelled, (result as StatusChange.Changed).detail.status)
    }
}
