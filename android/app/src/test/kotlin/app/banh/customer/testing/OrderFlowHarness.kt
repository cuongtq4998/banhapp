package app.banh.customer.testing

import app.banh.customer.data.Load
import app.banh.customer.order.OrderDependencies
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowViewModel

/** Everything an order flow store needs, with fakes, so view model tests read as the behaviour they check. */
class OrderFlowHarness {
    val catalog = FakeCatalogRepository(Load.Ready(orderCatalog()))
    val drafts = InMemoryDraftStore()
    val clock = MutableClock()
    private var keyCount = 0

    fun viewModel(
        availability: FakeAvailabilityApi = FakeAvailabilityApi(fixtureAvailability()),
        orders: FakeOrderApi = FakeOrderApi(fixtureReceipt()),
    ) = OrderFlowViewModel(OrderDependencies(catalog, availability, drafts, clock, orders)) { "key-${++keyCount}" }

    /** A store that restored [savedDraft]: complete, so confirm is on. */
    fun readyViewModel(orders: FakeOrderApi): OrderFlowViewModel {
        drafts.draft = savedDraft()
        return viewModel(orders = orders)
    }

    /** A complete draft written a moment ago; every field is filled so a restore is checked field by field. */
    fun savedDraft() = OrderDraft(
        quantities = mapOf("product-1" to 2, "product-2" to 1),
        date = "2026-11-06",
        slotId = "slot-1",
        name = "An",
        phone = "0912345678",
        address = "12 Duong Hoa Sen",
        districtId = "district-1",
        note = "Giao sang",
        idempotencyKey = "saved-key",
        savedAtEpochMillis = clock.millis(),
    )
}
