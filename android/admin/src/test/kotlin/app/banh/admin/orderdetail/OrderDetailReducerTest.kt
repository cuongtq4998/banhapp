package app.banh.admin.orderdetail

import app.banh.admin.orders.OrderRuleError
import app.banh.admin.testing.OrderFixtures
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OrderDetailReducerTest {
    private val received = OrderFixtures.detail("order-detail-received")
    private val ready = reduceOrderDetail(OrderDetailState(received.orderCode), OrderDetailIntent.Loaded(received))

    private fun run(state: OrderDetailState, vararg intents: OrderDetailIntent) = intents.fold(state, ::reduceOrderDetail)

    private fun readyWith(fixture: String) = run(OrderDetailState("x"), OrderDetailIntent.Loaded(OrderFixtures.detail(fixture)))

    @Test
    fun processIsOneTapWithNoDialog() {
        val s = run(ready, OrderDetailIntent.Tap(OrderAction.PROCESS))
        assertEquals(BusyAction.PROCESS, s.busy)
        assertNull(s.sheet)
    }

    @Test
    fun anActionTheServerDidNotAllowIsIgnored() {
        assertEquals(ready, run(ready, OrderDetailIntent.Tap(OrderAction.FINISH)))
        assertEquals(ready, run(ready, OrderDetailIntent.Tap(OrderAction.START_DELIVERY)))
    }

    @Test
    fun secondActionIsIgnoredWhileOneRuns() {
        val s = run(ready, OrderDetailIntent.Tap(OrderAction.PROCESS), OrderDetailIntent.Tap(OrderAction.CANCEL))
        assertNull(s.sheet)
    }

    @Test
    fun finishAsksOnceAndCancelNeedsAReason() {
        val started = readyWith("order-detail-delivery-started")
        val asked = run(started, OrderDetailIntent.Tap(OrderAction.FINISH))
        assertEquals(DetailSheet.FinishDialog, asked.sheet)
        assertEquals(BusyAction.FINISH, run(asked, OrderDetailIntent.FinishYes).busy)

        val cancel = run(ready, OrderDetailIntent.Tap(OrderAction.CANCEL), OrderDetailIntent.Submit)
        assertNull(cancel.busy)
        val reasoned = run(cancel, OrderDetailIntent.SelectReason(CancelReason.FAKE_SPAM), OrderDetailIntent.Submit)
        assertEquals(BusyAction.CANCEL, reasoned.busy)
    }

    @Test
    fun dateSaveNeedsADateInsideTheServerRangeAndDifferentFromTheCurrentOne() {
        val scheduled = readyWith("order-detail-delivery-date-scheduled")
        val range = scheduled.detail!!.expectedDateRange!!
        val open = run(scheduled, OrderDetailIntent.Tap(OrderAction.CHANGE_DATE))
        assertFalse(open.canSaveDate)
        assertFalse(run(open, OrderDetailIntent.PickDate(scheduled.detail!!.expectedDeliveryDate!!)).canSaveDate)
        assertFalse(run(open, OrderDetailIntent.PickDate("2000-01-01")).canSaveDate)
        assertFalse(run(open, OrderDetailIntent.PickDate("2999-01-01")).canSaveDate)
        val other = run(open, OrderDetailIntent.PickDate(range.max))
        assertEquals(scheduled.detail!!.expectedDeliveryDate != range.max, other.canSaveDate)
    }

    @Test
    fun feeSheetStartsEmptyAcceptsZeroAndRefusesOutOfRange() {
        val processing = readyWith("order-detail-delivery-date-scheduled")
        val open = run(processing, OrderDetailIntent.Tap(OrderAction.START_DELIVERY))
        assertEquals(DetailSheet.Fee(), open.sheet)
        assertFalse(open.canSaveFee)
        assertTrue(run(open, OrderDetailIntent.EditFee("0")).canSaveFee)
        assertTrue(run(open, OrderDetailIntent.EditFee("10000000")).canSaveFee)
        assertFalse(run(open, OrderDetailIntent.EditFee("10000001")).canSaveFee)
        assertEquals("12", (run(open, OrderDetailIntent.EditFee("1a2")).sheet as DetailSheet.Fee).text)
    }

    @Test
    fun feeCorrectionRefusesTheSameFee() {
        val started = readyWith("order-detail-delivery-started")
        val open = run(started, OrderDetailIntent.Tap(OrderAction.CORRECT_FEE))
        val current = started.detail!!.deliveryFeeFinalVnd!!.toString()
        assertFalse(run(open, OrderDetailIntent.EditFee(current)).canSaveFeeCorrection)
        assertTrue(run(open, OrderDetailIntent.EditFee("1")).canSaveFeeCorrection || current == "1")
    }

    @Test
    fun aRefusalStaysBesideTheFieldAndKeepsTheSheetOpen() {
        val open = run(readyWith("order-detail-delivery-date-scheduled"), OrderDetailIntent.Tap(OrderAction.START_DELIVERY), OrderDetailIntent.EditFee("5"), OrderDetailIntent.Submit)
        val s = run(open, OrderDetailIntent.Refused(OrderRuleError.FeeInvalid))
        assertNull(s.busy)
        assertEquals(DetailSheet.Fee("5", OrderRuleError.FeeInvalid), s.sheet)
    }

    @Test
    fun conflictReplacesTheOrderAndClosesTheSheet() {
        val current = OrderFixtures.detail("order-detail-fee-corrected")
        val open = run(ready, OrderDetailIntent.Tap(OrderAction.CANCEL))
        val s = run(open, OrderDetailIntent.Conflicted(current))
        assertEquals(current, s.detail)
        assertNull(s.sheet)
        assertEquals(DetailBanner.Conflict(OrderStatus.DeliveryStarted), s.banner)
    }

    @Test
    fun changeShowsTheToastOnce() {
        val s = run(ready, OrderDetailIntent.Changed(received))
        assertTrue(s.toast)
        assertFalse(run(s, OrderDetailIntent.ToastShown).toast)
    }
}
