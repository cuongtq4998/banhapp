package app.banh.customer.lookup

import app.banh.customer.data.lookup.TrackingStatus
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.parseApiError
import app.banh.customer.testing.ContractFixtures
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LookupFixturesTest {
    @Test
    fun everyAnswerFixtureDecodes() {
        val names = ContractFixtures.names("order-lookup-answer-")
        assertEquals(7, names.size)
        names.forEach { lookupFixture(it) }
    }

    @Test
    fun openAnswerKeepsServerOrderAndStatuses() {
        val answer = lookupFixture("order-lookup-answer-open.json")
        assertEquals(listOf("BT-FIX001", "BT-FIX002", "BT-FIX003", "BT-FIX004"), answer.orders.map { it.orderCode })
        assertEquals(TrackingStatus.Known.DELIVERY_STARTED, answer.orders[3].status)
        assertEquals("2026-11-02T05:00:00Z", answer.asOf)
        assertNull(answer.orders[0].expectedDeliveryDate)
        assertEquals(2, answer.orders[0].items[1].quantity)
    }

    @Test
    fun unknownStatusKeepsRawText() {
        val order = lookupFixture("order-lookup-answer-open.json").orders[0].copy(statusWire = "Paused")
        assertEquals(TrackingStatus.Unknown("Paused"), order.status)
    }

    @Test
    fun feeStatesFollowTheServerAmountOnly() {
        val open = lookupFixture("order-lookup-answer-open.json").orders
        assertEquals(LookupFee.Unknown(150000, 20000), open[0].feeState())
        assertEquals(LookupFee.Known(150000, 25000, 175000), open[3].feeState())
        val free = lookupFixture("order-lookup-answer-fee-zero.json").orders[0]
        assertEquals(LookupFee.Free(150000, 150000), free.feeState())
        assertEquals(LookupFee.Known(150000, 35000, 185000), lookupFixture("order-lookup-answer-fee-corrected.json").orders[0].feeState())
        assertEquals(LookupFee.None, lookupFixture("order-lookup-answer-cancelled.json").orders[0].feeState())
    }

    @Test
    fun finishedWithNullAmountIsStillUnknown() {
        val finished = lookupFixture("order-lookup-answer-fee-zero.json").orders[0].copy(amountToCollectVnd = null)
        assertTrue(finished.feeState() is LookupFee.Unknown)
    }

    @Test
    fun emptyAnswerHasNoOrders() {
        val state = LookupState().withFirstPage(lookupFixture("order-lookup-answer-empty.json"))
        assertTrue(state.isEmpty)
    }

    @Test
    fun errorFixturesMapToFailures() {
        assertEquals(LookupFailure.PhoneRejected("ERR_FIELD_INVALID"), failure("error-lookup-phone-invalid.json", 422))
        assertEquals(LookupFailure.PhoneRejected("ERR_FIELD_REQUIRED"), failure("error-lookup-phone-required.json", 422))
        assertEquals(LookupFailure.CursorInvalid, failure("error-lookup-cursor-invalid.json", 422))
        assertEquals(LookupFailure.RateLimited(3600), failure("error-lookup-rate-limited.json", 429))
    }

    @Test
    fun otherFailuresMap() {
        assertEquals(LookupFailure.Generic, parseApiError(413, "", null, ApiJson).toLookupFailure())
        assertEquals(LookupFailure.Generic, parseApiError(503, "", null, ApiJson).toLookupFailure())
        assertEquals(LookupFailure.RateLimited(90), parseApiError(429, "", "90", ApiJson).toLookupFailure())
        assertEquals(LookupFailure.Offline, ApiException.NetworkUnavailable(java.io.IOException()).toLookupFailure())
        assertEquals(LookupFailure.Offline, ApiException.Timeout(java.io.IOException()).toLookupFailure())
        assertEquals(LookupFailure.Generic, ApiException.InvalidResponse().toLookupFailure())
    }

    private fun failure(name: String, status: Int) =
        parseApiError(status, ContractFixtures.read(name), null, ApiJson).toLookupFailure()
}
