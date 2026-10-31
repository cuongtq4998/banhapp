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

/** The key lifecycle (ADR-0008 v1.1) and every error code of POST /v1/orders mapped to its S-8 state. */
@OptIn(ExperimentalCoroutinesApi::class)
class OrderSubmitErrorsTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val harness = OrderFlowHarness()

    private fun ready(vararg outcomes: Any): Pair<OrderFlowViewModel, FakeOrderApi> {
        val api = FakeOrderApi(*outcomes)
        return harness.readyViewModel(api) to api
    }


    // TC-124, TC-157, AC-19: offline, timeout and 5xx keep the data and retry with the same key.
    @Test
    fun notSentErrorsKeepTheKeyAndRetryReturnsTheStoredOrder() {
        val cases = mapOf(
            NotSentReason.OFFLINE to ApiException.NetworkUnavailable(IOException("down")),
            NotSentReason.TIMEOUT to ApiException.Timeout(InterruptedIOException("10 s")),
            NotSentReason.SERVER to orderFixtureError("service-unavailable"),
        )
        cases.forEach { (reason, error) ->
            val (flow, api) = ready(error, fixtureReceipt())
            val key = flow.state.value.draft.idempotencyKey

            flow.onIntent(OrderIntent.Confirm)
            assertEquals(SubmitProblem.NotSent(reason), flow.problem())
            assertTrue(flow.state.value.canConfirm)
            flow.onIntent(OrderIntent.Confirm)

            assertEquals(listOf(key, key), api.keys)
            assertTrue(flow.state.value.submit is SubmitState.Confirmed)
        }
    }

    @Test
    fun serverSideCodesWithoutAScreenShowTheGeneralMessage() {
        listOf("internal-error", "ordering-paused", "header-invalid", "idempotency-key-required", "payload-too-large").forEach { name ->
            val (flow, _) = ready(orderFixtureError(name))
            flow.onIntent(OrderIntent.Confirm)
            assertEquals(name, SubmitProblem.NotSent(NotSentReason.SERVER), flow.problem())
        }
    }

    @Test
    fun rateLimitedKeepsRetryAvailable() {
        val (flow, _) = ready(orderFixtureError("rate-limited", retryAfterHeader = "3600"))

        flow.onIntent(OrderIntent.Confirm)

        assertEquals(SubmitProblem.NotSent(NotSentReason.RATE_LIMITED), flow.problem())
        assertTrue(flow.state.value.canConfirm)
    }

    // TC-113, TC-117, TC-126, TC-138: a rule error blocks confirm and names its step; the data stays.
    @Test
    fun ruleErrorsBlockConfirmAndKeepTheDraft() {
        val expected = mapOf(
            "min-qty" to SubmitProblem.Rule(SubmitRule.MIN_QTY, number = 2),
            "date-capacity" to SubmitProblem.Rule(SubmitRule.DATE_CAPACITY, date = "2026-11-05"),
            "date-lead" to SubmitProblem.Rule(SubmitRule.DATE_LEAD, number = 2),
            "date-horizon" to SubmitProblem.Rule(SubmitRule.DATE_HORIZON, number = 30),
            "district-unserved" to SubmitProblem.Rule(SubmitRule.DISTRICT_UNSERVED),
            "slot-unavailable" to SubmitProblem.Rule(SubmitRule.SLOT_UNAVAILABLE),
        )
        expected.forEach { (name, problem) ->
            val (flow, api) = ready(orderFixtureError(name))
            val before = flow.state.value.draft

            flow.onIntent(OrderIntent.Confirm)

            assertEquals(name, problem, flow.problem())
            assertFalse(name, flow.state.value.canConfirm)
            assertEquals(name, before, flow.state.value.draft)
            assertEquals(1, api.calls.size)
            flow.onIntent(OrderIntent.LeaveReview)
            assertTrue(name, flow.state.value.canConfirm)
        }
    }

    // ADR-0011, AC-34: only the named cake leaves the draft, with a new key; the catalog is refreshed.
    @Test
    fun unavailableProductIsDroppedAloneWithANewKey() {
        val (flow, _) = ready(orderFixtureError("product-unavailable"))
        val key = flow.state.value.draft.idempotencyKey

        flow.onIntent(OrderIntent.SubmitFailed(SubmitFailure.ProductsGone(listOf("product-2")), "new-key"))

        val state = flow.state.value
        assertEquals(mapOf("product-1" to 2), state.draft.quantities)
        assertEquals(listOf("Cake 2"), state.removedCakeNames)
        assertEquals("new-key", state.draft.idempotencyKey)
        assertNotEquals(key, state.draft.idempotencyKey)
        assertEquals("Giao sang", state.draft.note)
        assertEquals(SubmitProblem.Rule(SubmitRule.PRODUCT_UNAVAILABLE), flow.problem())
    }

    @Test
    fun productUnavailableAnswerBlocksConfirmAndRefreshesTheCatalog() {
        val (flow, _) = ready(orderFixtureError("product-unavailable"))

        flow.onIntent(OrderIntent.Confirm)

        assertEquals(SubmitProblem.Rule(SubmitRule.PRODUCT_UNAVAILABLE), flow.problem())
        assertFalse(flow.state.value.canConfirm)
        assertEquals(1, harness.catalog.refreshCount)
    }

    @Test
    fun serverPricesReplaceTheReviewAndTheHighlightNamesWhatChanged() {
        val (flow, api) = ready(fixtureReceipt())
        val update = PriceUpdate(districtId = null, pricesVnd = mapOf("product-1" to 60_000L), deliveryFeeVnd = 25_000L)

        flow.onIntent(OrderIntent.SubmitFailed(SubmitFailure.PriceChanged(update), "k2"))

        val state = flow.state.value
        assertEquals(197_000L, state.summary!!.totalVnd)
        assertEquals(setOf("product-1"), state.priceUpdate!!.changedProductIds)
        assertTrue(state.priceUpdate!!.feeChanged && state.priceUpdate!!.totalChanged)
        flow.onIntent(OrderIntent.Confirm)
        assertEquals(197_000L, api.calls.single().first.expectedTotalVnd)
        assertEquals("k2", api.keys.single())
    }

    // ADR-0010, ADR-0008 v1.1, TC-127: new prices at once, new key, next request carries the new total.
    @Test
    fun priceChangedReplacesPricesAndKeyAndTheNextSendUsesTheNewTotal() {
        val (flow, api) = ready(orderFixtureError("price-changed"), fixtureReceipt())
        val key = flow.state.value.draft.idempotencyKey

        flow.onIntent(OrderIntent.Confirm)

        assertEquals(SubmitProblem.PriceChanged, flow.problem())
        assertNotEquals(key, flow.state.value.draft.idempotencyKey)
        assertTrue(flow.state.value.canConfirm)
        flow.onIntent(OrderIntent.Confirm)
        assertEquals(flow.state.value.summary!!.totalVnd, api.calls[1].first.expectedTotalVnd)
        assertNotEquals(api.keys[0], api.keys[1])
        assertTrue(flow.state.value.submit is SubmitState.Confirmed)
    }

    // ADR-0008 v1.1: IDEMPOTENCY_KEY_REUSED replaces the key and retries once; a second one is the general error.
    @Test
    fun keyReusedIsRetriedOnceWithANewKey() {
        val (flow, api) = ready(orderFixtureError("idempotency-key-reused"), fixtureReceipt())

        flow.onIntent(OrderIntent.Confirm)

        assertEquals(2, api.calls.size)
        assertNotEquals(api.keys[0], api.keys[1])
        assertTrue(flow.state.value.submit is SubmitState.Confirmed)

        val (again, twice) = ready(orderFixtureError("idempotency-key-reused"))
        again.onIntent(OrderIntent.Confirm)
        assertEquals(2, twice.calls.size)
        assertEquals(SubmitProblem.NotSent(NotSentReason.SERVER), again.problem())
    }

    // Error table: VALIDATION_FAILED fields go to S-7.
    @Test
    fun validationFailedMapsFieldsToTheRecipientStepAndEmitsTheEffect() = runTest {
        val (flow, _) = ready(orderFixtureError("validation-failed"))

        flow.onIntent(OrderIntent.Confirm)

        assertEquals(
            mapOf(RecipientField.NAME to RecipientError.NAME_REQUIRED, RecipientField.PHONE to RecipientError.PHONE_INVALID),
            flow.state.value.recipientErrors,
        )
        assertEquals(SubmitState.Idle, flow.state.value.submit)
        assertEquals(OrderEffect.GoToRecipient, flow.effects.first())
    }
}
