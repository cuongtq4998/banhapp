package app.banh.admin.orderdetail

import app.banh.admin.orders.OrderRuleError
import app.banh.admin.testing.OrderFixtures
import app.banh.core.model.DateRange
import app.banh.core.model.OrderAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SheetModelsTest {
    private val range = DateRange("2026-11-02", "2026-11-09")
    private val scheduled = OrderFixtures.detail("order-detail-delivery-date-scheduled")

    @Test
    fun onlyDaysInsideTheServerRangeArePickable() {
        assertTrue(isDayPickable("2026-11-02", range))
        assertTrue(isDayPickable("2026-11-09", range))
        assertFalse(isDayPickable("2026-11-01", range))
        assertFalse(isDayPickable("2026-11-10", range))
        assertFalse(isDayPickable("2026-11-05", null))
    }

    @Test
    fun pickerOpensOnExpectedThenRequestedThenRangeStart() {
        assertEquals("2026-11-05", openingDateOf(scheduled))
        assertEquals("2026-11-02", openingDateOf(scheduled.copy(expectedDeliveryDate = "2026-10-30")))
        val farRequested = scheduled.copy(expectedDeliveryDate = null, requestedDeliveryDate = "2026-10-01", deliveryDate = "2026-10-01")
        assertEquals("2026-11-02", openingDateOf(farRequested))
        assertNull(openingDateOf(scheduled.copy(expectedDateRange = null)))
    }

    @Test
    fun everyRuleErrorMapsToItsFieldErrorAndTheTransitionToNone() {
        assertEquals(SheetError.DATE_PAST, OrderRuleError.DatePast(range).sheetError())
        assertEquals(SheetError.DATE_TOO_FAR, OrderRuleError.DateTooFar(null).sheetError())
        assertEquals(SheetError.DATE_UNCHANGED, OrderRuleError.DateUnchanged.sheetError())
        assertEquals(SheetError.FEE_REQUIRED, OrderRuleError.FeeRequired.sheetError())
        assertEquals(SheetError.FEE_INVALID, OrderRuleError.FeeInvalid.sheetError())
        assertEquals(SheetError.FEE_UNCHANGED, OrderRuleError.FeeUnchanged.sheetError())
        assertEquals(SheetError.FEE_NOT_ALLOWED, OrderRuleError.FeeCorrectionNotAllowed.sheetError())
        assertNull(OrderRuleError.TransitionInvalid.sheetError())
    }

    @Test
    fun feePreviewSumsOnlyAValidTypedFee() {
        assertEquals(FeePreview(null, null), feePreviewOf(100_000, ""))
        assertEquals(FeePreview(0, 100_000), feePreviewOf(100_000, "0"))
        assertEquals(FeePreview(30_000, 130_000), feePreviewOf(100_000, "30000"))
        assertEquals(FeePreview(null, null), feePreviewOf(100_000, "10000001"))
    }

    @Test
    fun deliveryCardShowsExpectedDateAndTapsOnlyWhenChangeIsAllowed() {
        val allowed = deliveryLinesOf(scheduled, canChangeDate = true)
        assertEquals(DeliveryLines("2026-11-02", "2026-11-05", true), allowed)
        assertFalse(deliveryLinesOf(scheduled, canChangeDate = false).expectedTappable)
        val received = deliveryLinesOf(OrderFixtures.detail("order-detail-received"), canChangeDate = true)
        assertNull(received.expectedDate)
        assertFalse(received.expectedTappable)
    }

    @Test
    fun feeConflictNamesTheNewFeeOnlyWhenACorrectionLostTheRace() {
        val started = OrderFixtures.detail("order-detail-delivery-started")
        val open = reduceOrderDetail(OrderDetailState("x"), OrderDetailIntent.Loaded(started))
        val correcting = reduceOrderDetail(open, OrderDetailIntent.Tap(OrderAction.CORRECT_FEE))
        val lost = reduceOrderDetail(correcting, OrderDetailIntent.Conflicted(started))
        assertEquals(DetailBanner.FeeConflict(started.deliveryFeeFinalVnd!!), lost.banner)
        assertNull(lost.sheet)
        val other = reduceOrderDetail(open, OrderDetailIntent.Conflicted(started))
        assertTrue(other.banner is DetailBanner.Conflict)
    }
}
