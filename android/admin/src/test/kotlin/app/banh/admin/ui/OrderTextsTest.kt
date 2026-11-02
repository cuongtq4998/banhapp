package app.banh.admin.ui

import app.banh.core.design.BadgeTone
import app.banh.core.model.OrderStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class OrderTextsTest {
    @Test
    fun everyStatusHasOneOfTheExistingTones() {
        assertEquals(BadgeTone.NEW, OrderStatus.Received.tone())
        assertEquals(BadgeTone.CONFIRMED, OrderStatus.Processing.tone())
        assertEquals(BadgeTone.CONFIRMED, OrderStatus.DeliveryDateScheduled.tone())
        assertEquals(BadgeTone.CONFIRMED, OrderStatus.DeliveryStarted.tone())
        assertEquals(BadgeTone.COMPLETED, OrderStatus.Finished.tone())
        assertEquals(BadgeTone.CANCELLED, OrderStatus.Cancelled.tone())
        assertEquals(BadgeTone.CANCELLED, OrderStatus.Unknown("Other").tone())
    }
}
