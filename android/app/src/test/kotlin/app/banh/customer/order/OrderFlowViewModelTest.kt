package app.banh.customer.order

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.network.ApiException
import app.banh.customer.testing.FakeAvailabilityApi
import app.banh.customer.testing.MainDispatcherRule
import app.banh.customer.testing.OrderFlowHarness
import app.banh.customer.testing.fixtureAvailability
import java.io.IOException
import java.io.InterruptedIOException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/** The store around the reducer: availability for S-6, the check on S-7, and the catalog refresh. */
@OptIn(ExperimentalCoroutinesApi::class)
class OrderFlowViewModelTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val harness = OrderFlowHarness()
    private val catalog = harness.catalog

    private fun viewModel(availability: FakeAvailabilityApi = FakeAvailabilityApi(fixtureAvailability())) = harness.viewModel(availability)

    @Test
    fun availabilityIsAskedForTheTotalNumberOfCakes() {
        val api = FakeAvailabilityApi(fixtureAvailability())
        val flow = viewModel(api)
        flow.onIntent(OrderIntent.SetQuantity("product-1", 2))
        flow.onIntent(OrderIntent.SetQuantity("product-2", 1))

        flow.onIntent(OrderIntent.LoadAvailability)

        assertEquals(listOf(3), api.requestedCakes)
        val loaded = flow.state.value.availability as Load.Ready
        assertEquals(3, loaded.value.cakes)
        assertEquals(31, loaded.value.availability.dates.size)
    }

    @Test
    fun noRequestIsMadeForAnEmptyOrder() {
        val api = FakeAvailabilityApi(fixtureAvailability())
        val flow = viewModel(api)

        flow.onIntent(OrderIntent.LoadAvailability)

        assertTrue(api.requestedCakes.isEmpty())
        assertNull(flow.state.value.availability)
    }

    @Test
    fun offlineAndOtherFailuresAreTold() {
        val offline = FakeAvailabilityApi(ApiException.NetworkUnavailable(IOException("down")))
        val flow = viewModel(offline)
        flow.onIntent(OrderIntent.SetQuantity("product-1", 2))

        flow.onIntent(OrderIntent.LoadAvailability)
        assertEquals(Load.Failed(LoadFailure.NETWORK), flow.state.value.availability)

        val broken = viewModel(FakeAvailabilityApi(ApiException.InvalidResponse()))
        broken.onIntent(OrderIntent.SetQuantity("product-1", 2))
        broken.onIntent(OrderIntent.LoadAvailability)
        assertEquals(Load.Failed(LoadFailure.OTHER), broken.state.value.availability)
    }

    @Test
    fun retryAfterAFailureLoadsAgain() {
        val api = FakeAvailabilityApi(ApiException.Timeout(InterruptedIOException()), fixtureAvailability())
        val flow = viewModel(api)
        flow.onIntent(OrderIntent.SetQuantity("product-1", 2))

        flow.onIntent(OrderIntent.LoadAvailability)
        flow.onIntent(OrderIntent.LoadAvailability)

        assertEquals(2, api.requestedCakes.size)
        assertTrue(flow.state.value.availability is Load.Ready)
    }

    // AC-12: Next on an invalid form focuses the first failing field; on a valid form it goes to the review.
    @Test
    fun invalidRecipientFocusesTheFirstFailingField() = runTest {
        val flow = viewModel()
        flow.onIntent(OrderIntent.EditName("An"))

        flow.onIntent(OrderIntent.SubmitRecipient)

        assertEquals(OrderEffect.FocusField(RecipientField.PHONE), flow.effects.first())
    }

    @Test
    fun validRecipientGoesToTheReview() = runTest {
        val flow = viewModel()
        listOf(
            OrderIntent.EditName("An"),
            OrderIntent.EditPhone("0912345678"),
            OrderIntent.EditAddress("12 Duong Hoa Sen"),
            OrderIntent.ChooseDistrict("district-1"),
            OrderIntent.SubmitRecipient,
        ).forEach(flow::onIntent)

        assertEquals(OrderEffect.GoToReview, flow.effects.first())
    }

    @Test
    fun retryAsksTheCatalogToRefresh() {
        val flow = viewModel()

        flow.onIntent(OrderIntent.RetryCatalog)

        assertEquals(1, catalog.refreshCount)
    }
}
