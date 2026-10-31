package app.banh.customer.order

import app.banh.customer.data.network.ApiException
import app.banh.customer.testing.FakeOrderApi
import app.banh.customer.testing.MainDispatcherRule
import app.banh.customer.testing.OrderFlowHarness
import app.banh.customer.testing.problem
import app.banh.customer.testing.fixtureReceipt
import app.banh.customer.testing.orderFixtureError
import java.io.IOException
import java.io.InterruptedIOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/** The send of the order (slice 3): the request, no double send, success and the end of the order. */
@OptIn(ExperimentalCoroutinesApi::class)
class OrderSubmitTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val harness = OrderFlowHarness()

    private fun ready(vararg outcomes: Any): Pair<OrderFlowViewModel, FakeOrderApi> {
        val api = FakeOrderApi(*outcomes)
        return harness.readyViewModel(api) to api
    }


    @Test
    fun theRequestCarriesTheDraftAndTheTotalTheReviewShows() {
        val (flow, api) = ready(fixtureReceipt())
        val key = flow.state.value.draft.idempotencyKey

        flow.onIntent(OrderIntent.Confirm)

        val (request, sentKey) = api.calls.single()
        assertEquals(key, sentKey)
        assertEquals(listOf("product-1" to 2, "product-2" to 1), request.items.map { it.productId to it.quantity })
        assertEquals("2026-11-06", request.deliveryDate)
        assertEquals("slot-1", request.slotId)
        assertEquals("district-1", request.customer.districtId)
        assertEquals("Giao sang", request.note)
        assertEquals(174_000L, request.expectedTotalVnd)
    }

    // AC-19: a second tap while the request is out sends nothing.
    @Test
    fun confirmWhileSendingDoesNotSendTwice() {
        val (flow, api) = ready(fixtureReceipt())
        api.gate = CompletableDeferred()

        flow.onIntent(OrderIntent.Confirm)
        flow.onIntent(OrderIntent.Confirm)

        assertEquals(SubmitState.Sending, flow.state.value.submit)
        assertFalse(flow.state.value.canConfirm)
        assertEquals(1, api.calls.size)
    }

    // TC-119: success shows the code and clears the saved draft.
    @Test
    fun successConfirmsWithTheCodeAndClearsTheSavedDraft() {
        val (flow, _) = ready(fixtureReceipt())

        flow.onIntent(OrderIntent.Confirm)

        assertEquals(SubmitState.Confirmed("BT-7K3M9Q"), flow.state.value.submit)
        assertEquals(1, harness.drafts.cleared)
    }

    // S-9 Home: the data and the key are gone.
    @Test
    fun finishingClearsTheDraftAndTheKey() {
        val (flow, _) = ready(fixtureReceipt())
        val key = flow.state.value.draft.idempotencyKey
        flow.onIntent(OrderIntent.Confirm)

        flow.onIntent(OrderIntent.FinishOrder("fresh"))

        val state = flow.state.value
        assertTrue(state.draft.quantities.isEmpty())
        assertEquals("fresh", state.draft.idempotencyKey)
        assertNotEquals(key, state.draft.idempotencyKey)
        assertEquals(SubmitState.Idle, state.submit)
        assertNull(harness.drafts.draft)
    }

    @Test
    fun leavingTheReviewDismissesTheProblemButNotASend() {
        val (flow, api) = ready(orderFixtureError("internal-error"))
        flow.onIntent(OrderIntent.Confirm)
        flow.onIntent(OrderIntent.LeaveReview)
        assertEquals(SubmitState.Idle, flow.state.value.submit)

        api.gate = CompletableDeferred()
        flow.onIntent(OrderIntent.Confirm)
        flow.onIntent(OrderIntent.LeaveReview)
        assertEquals(SubmitState.Sending, flow.state.value.submit)
    }
}
