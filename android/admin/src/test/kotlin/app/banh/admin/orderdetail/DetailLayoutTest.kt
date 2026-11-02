package app.banh.admin.orderdetail

import app.banh.admin.testing.OrderFixtures
import app.banh.admin.ui.AdminOrderTags
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DetailLayoutTest {
    private fun detail(name: String) = OrderFixtures.detail(name)

    private fun stateOf(name: String) = reduceOrderDetail(OrderDetailState("x"), OrderDetailIntent.Loaded(detail(name)))

    @Test
    fun stepperMarksDoneCurrentAndNext() {
        val d = StepState.DONE
        val c = StepState.CURRENT
        val n = StepState.NEXT
        assertEquals(listOf(c, n, n, n, n), stepStatesOf(OrderStatus.Received))
        assertEquals(listOf(d, d, c, n, n), stepStatesOf(OrderStatus.DeliveryDateScheduled))
        assertEquals(listOf(d, d, d, c, n), stepStatesOf(OrderStatus.DeliveryStarted))
        assertEquals(List(STEP_COUNT) { d }, stepStatesOf(OrderStatus.Finished))
    }

    @Test
    fun cancelledAndUnknownHaveNoStepper() {
        assertNull(stepStatesOf(OrderStatus.Cancelled))
        assertNull(stepStatesOf(OrderStatus.Unknown("Other")))
    }

    @Test
    fun barHoldsOnlyTheServerActions() {
        assertEquals(BarActions(OrderAction.CANCEL, OrderAction.PROCESS), barActionsOf(listOf(OrderAction.CANCEL, OrderAction.PROCESS)))
        assertEquals(BarActions(OrderAction.CANCEL, OrderAction.SCHEDULE_DELIVERY), barActionsOf(listOf(OrderAction.CANCEL, OrderAction.SCHEDULE_DELIVERY)))
        assertEquals(BarActions(OrderAction.CHANGE_DATE, OrderAction.START_DELIVERY), barActionsOf(listOf(OrderAction.CHANGE_DATE, OrderAction.START_DELIVERY)))
        assertEquals(BarActions(null, OrderAction.FINISH), barActionsOf(listOf(OrderAction.FINISH, OrderAction.CORRECT_FEE)))
        assertEquals(BarActions(null, null), barActionsOf(emptyList()))
    }

    @Test
    fun barFollowsTheFixtureLists() {
        val received = stateOf("order-detail-received")
        assertEquals(received.detail!!.allowedActions.contains(OrderAction.CANCEL), barActionsOf(received.detail!!.allowedActions).left == OrderAction.CANCEL)
        val scheduled = stateOf("order-detail-delivery-date-scheduled")
        assertFalse(OrderAction.CANCEL in scheduled.detail!!.allowedActions)
        assertEquals(OrderAction.START_DELIVERY, barActionsOf(scheduled.detail!!.allowedActions).right)
    }

    @Test
    fun cancelBlockedNamesWhyFromTheScheduledStepOn() {
        assertTrue(stateOf("order-detail-delivery-date-scheduled").cancelBlocked())
        assertTrue(stateOf("order-detail-delivery-started").cancelBlocked())
        assertFalse(stateOf("order-detail-received").cancelBlocked())
    }

    @Test
    fun feeRowIsPendingBeforeTheFeeAndFreeAtZero() {
        assertTrue(feeRowOf(detail("order-detail-delivery-date-scheduled")) is FeeRow.Pending)
        assertEquals(FeeRow.Free, feeRowOf(detail("order-detail-delivery-started-free")))
        val fee = feeRowOf(detail("order-detail-delivery-started"))
        assertTrue(fee is FeeRow.Amount || fee == FeeRow.Free)
    }

    @Test
    fun amountToCollectIsTheServerValueOrAbsent() {
        val scheduled = detail("order-detail-delivery-date-scheduled")
        assertEquals(scheduled.amountToCollectVnd, amountToCollectOf(scheduled))
        assertEquals(100_000L, amountToCollectOf(detail("order-detail-delivery-started-free")))
        assertNull(amountToCollectOf(detail("order-detail-delivery-started-free").copy(amountToCollectVnd = null)))
        assertEquals(FeeRow.Amount(30_000), feeRowOf(detail("order-detail-delivery-started-free").copy(deliveryFeeFinalVnd = 30_000)))
    }

    @Test
    fun tagsAreUnique() {
        val tags = listOf(
            AdminOrderTags.ORDER_STEPPER, AdminOrderTags.ORDER_PROCESS, AdminOrderTags.ORDER_SCHEDULE, AdminOrderTags.ORDER_CHANGE_DATE,
            AdminOrderTags.ORDER_START_DELIVERY, AdminOrderTags.ORDER_FINISH, AdminOrderTags.ORDER_FEE_CORRECT, AdminOrderTags.ORDER_CANCEL_BLOCKED,
            AdminOrderTags.ORDER_FEE, AdminOrderTags.ORDER_FEE_ESTIMATE, AdminOrderTags.ORDER_TOTAL_COLLECT, AdminOrderTags.ORDER_FEE_HISTORY,
            AdminOrderTags.DETAIL_CANCEL,
        ) + (1..STEP_COUNT).map(AdminOrderTags::orderStep) + (1..3).map(AdminOrderTags::feeHistoryRow) +
            listOf("A1", "B2").flatMap { listOf(AdminOrderTags.orderRow(it), AdminOrderTags.orderExpected(it), AdminOrderTags.orderDue(it)) }
        assertEquals(tags.size, tags.toSet().size)
    }
}
