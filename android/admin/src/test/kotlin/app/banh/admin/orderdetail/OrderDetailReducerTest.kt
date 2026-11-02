package app.banh.admin.orderdetail

import app.banh.admin.testing.Fixtures
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OrderDetailReducerTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val new = json.decodeFromString<OrderDetail>(Fixtures.body("order-detail"))
    private val ready = reduceOrderDetail(OrderDetailState(new.orderCode), OrderDetailIntent.Loaded(new))

    private fun run(state: OrderDetailState, vararg intents: OrderDetailIntent) = intents.fold(state, ::reduceOrderDetail)

    @Test
    fun confirmIsOneTapWithNoDialog() {
        val s = run(ready, OrderDetailIntent.TapConfirm)
        assertEquals(BusyAction.CONFIRM, s.busy)
        assertFalse(s.completeDialog)
    }

    @Test
    fun secondActionIsIgnoredWhileOneRuns() {
        val s = run(ready, OrderDetailIntent.TapConfirm, OrderDetailIntent.TapCancel)
        assertFalse(s.cancelSheet)
    }

    @Test
    fun completeNeedsAConfirmedOrderAndOneConfirmation() {
        assertFalse(run(ready, OrderDetailIntent.TapComplete).completeDialog)
        val confirmed = ready.copy(detail = new.copy(status = OrderStatus.Confirmed))
        val asked = run(confirmed, OrderDetailIntent.TapComplete)
        assertTrue(asked.completeDialog)
        val done = run(asked, OrderDetailIntent.CompleteYes)
        assertEquals(BusyAction.COMPLETE, done.busy)
        assertFalse(done.completeDialog)
    }

    @Test
    fun cancelNeedsAReasonAndStartsNothingPreselected() {
        val sheet = run(ready, OrderDetailIntent.TapCancel)
        assertTrue(sheet.cancelSheet)
        assertNull(sheet.reason)
        assertNull(run(sheet, OrderDetailIntent.CancelConfirm).busy)
        val chosen = run(sheet, OrderDetailIntent.SelectReason(CancelReason.FAKE_SPAM), OrderDetailIntent.CancelConfirm)
        assertEquals(BusyAction.CANCEL, chosen.busy)
    }

    @Test
    fun conflictClosesSheetsAndShowsTheCurrentStatus() {
        val sheet = run(ready, OrderDetailIntent.TapCancel, OrderDetailIntent.SelectReason(CancelReason.CUSTOMER_ASKED), OrderDetailIntent.CancelConfirm)
        val now = new.copy(status = OrderStatus.Confirmed)
        val s = run(sheet, OrderDetailIntent.Conflicted(now))
        assertFalse(s.cancelSheet)
        assertNull(s.busy)
        assertEquals(OrderStatus.Confirmed, s.detail?.status)
        assertEquals(DetailBanner.Conflict(OrderStatus.Confirmed), s.banner)
    }

    @Test
    fun successUpdatesInPlaceAndRaisesTheToast() {
        val s = run(ready, OrderDetailIntent.TapConfirm, OrderDetailIntent.Changed(new.copy(status = OrderStatus.Confirmed)))
        assertEquals(OrderStatus.Confirmed, s.detail?.status)
        assertTrue(s.statusToast)
        assertFalse(run(s, OrderDetailIntent.ToastShown).statusToast)
    }

    @Test
    fun finalStatesHaveNoActions() {
        assertFalse(ready.copy(detail = new.copy(status = OrderStatus.Completed)).hasActions)
        assertFalse(ready.copy(detail = new.copy(status = OrderStatus.Cancelled)).hasActions)
    }

    @Test
    fun failedActionKeepsTheScreenAndShowsTheMessage() {
        val s = run(ready, OrderDetailIntent.TapConfirm, OrderDetailIntent.ChangeFailed(DetailBanner.ActionError))
        assertNull(s.busy)
        assertEquals(DetailBanner.ActionError, s.banner)
    }
}
