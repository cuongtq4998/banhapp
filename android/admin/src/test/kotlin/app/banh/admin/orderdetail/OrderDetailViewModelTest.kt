package app.banh.admin.orderdetail

import app.banh.admin.orders.OrderChanges
import app.banh.admin.orders.OrdersApi
import app.banh.admin.orders.OrdersQuery
import app.banh.admin.orders.StatusChange
import app.banh.admin.testing.Fixtures
import app.banh.admin.testing.httpError
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrdersPage
import app.banh.core.network.ErrorCodes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class OrderDetailViewModelTest {
    private val new = Json { ignoreUnknownKeys = true }.decodeFromString<OrderDetail>(Fixtures.body("order-detail-received"))
    private var changeResult: () -> StatusChange = { StatusChange.Changed(new.copy(status = OrderStatus.Processing)) }
    private var detailResult: () -> OrderDetail = { new }
    private val calls = mutableListOf<Triple<OrderStatus, OrderStatus, CancelReason?>>()
    private val changes = OrderChanges()

    private val api = object : OrdersApi {
        override suspend fun list(query: OrdersQuery, cursor: String?): OrdersPage = error("unused")

        override suspend fun detail(orderCode: String) = detailResult()

        override suspend fun changeStatus(
            orderCode: String,
            expected: OrderStatus,
            to: OrderStatus,
            reason: CancelReason?,
            expectedDate: String?,
            feeVnd: Long?,
        ): StatusChange {
            calls += Triple(expected, to, reason)
            return changeResult()
        }

        override suspend fun changeExpectedDate(orderCode: String, previous: String, new: String): StatusChange = changeResult()

        override suspend fun correctFee(orderCode: String, previous: Long, new: Long): StatusChange = changeResult()
    }

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    @Test
    fun confirmSendsTheStatusTheScreenShowsAndNotifiesTheList() {
        val model = OrderDetailViewModel(new.orderCode, api, changes)
        model.dispatch(OrderDetailIntent.Tap(OrderAction.PROCESS))

        assertEquals(listOf(Triple(OrderStatus.Received, OrderStatus.Processing, null)), calls)
        assertEquals(OrderStatus.Processing, model.state.value.detail?.status)
        assertEquals(1, changes.version.value)
    }

    @Test
    fun conflictShowsTheCurrentStatusAndNotAnError() {
        changeResult = { StatusChange.Conflict(new.copy(status = OrderStatus.Processing)) }
        val model = OrderDetailViewModel(new.orderCode, api, changes)
        model.dispatch(OrderDetailIntent.Tap(OrderAction.CANCEL))
        model.dispatch(OrderDetailIntent.SelectReason(CancelReason.CUSTOMER_ASKED))
        model.dispatch(OrderDetailIntent.Submit)

        assertEquals(DetailBanner.Conflict(OrderStatus.Processing), model.state.value.banner)
        assertNull(model.state.value.sheet)
        assertEquals(CancelReason.CUSTOMER_ASKED, calls.single().third)
    }

    @Test
    fun unknownOrderShowsTheGoneState() {
        detailResult = { throw httpError(404, ErrorCodes.ORDER_NOT_FOUND) }
        assertEquals(DetailPhase.GONE, OrderDetailViewModel("BT-AAAAAA", api, changes).state.value.phase)
    }

    @Test
    fun offlineLoadAndOfflineActionAreTold() {
        detailResult = { throw app.banh.admin.testing.offline() }
        assertEquals(DetailPhase.OFFLINE, OrderDetailViewModel(new.orderCode, api, changes).state.value.phase)

        detailResult = { new }
        changeResult = { throw app.banh.admin.testing.offline() }
        val model = OrderDetailViewModel(new.orderCode, api, changes)
        model.dispatch(OrderDetailIntent.Tap(OrderAction.PROCESS))
        assertEquals(DetailBanner.ActionOffline, model.state.value.banner)
        assertNull(model.state.value.busy)
    }
}
