package app.banh.customer.testing

import app.banh.customer.data.availability.Availability
import app.banh.customer.data.availability.AvailabilityApi
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.District
import app.banh.customer.data.catalog.Slot
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.order.DraftStore
import app.banh.customer.order.OrderDraft

/** The availability answer of the shared fixture (server date 2026-11-02, cakes 3). */
fun fixtureAvailability(): Availability = ApiJson.decodeFromString(ContractFixtures.read("availability-ok.json"))

/** Catalog with the districts and slots the order tests choose from. */
fun orderCatalog(productCount: Int = 4): Catalog = TestCatalogs.catalog(productCount).copy(
    districts = listOf(
        District("district-1", "District One", 20_000L),
        District("district-2", "District Two", 35_000L),
    ),
    slots = listOf(Slot("slot-1", "08:00", "10:00"), Slot("slot-2", "10:00", "12:00")),
)

/** Answers with scripted outcomes (an [Availability] or a [Throwable]); the last one repeats. */
class FakeAvailabilityApi(private vararg val outcomes: Any) : AvailabilityApi {
    val requestedCakes = mutableListOf<Int>()

    override suspend fun fetchAvailability(cakes: Int): Availability {
        requestedCakes += cakes
        return when (val outcome = outcomes[minOf(requestedCakes.size, outcomes.size) - 1]) {
            is Availability -> outcome
            is ApiException -> throw outcome
            else -> error("Unsupported scripted outcome $outcome")
        }
    }
}

class InMemoryDraftStore(var draft: OrderDraft? = null) : DraftStore {
    val writes = mutableListOf<OrderDraft>()
    var cleared = 0
        private set

    override suspend fun read(): OrderDraft? = draft

    override suspend fun write(draft: OrderDraft) {
        writes += draft
        this.draft = draft
    }

    override suspend fun clear() {
        cleared++
        draft = null
    }
}
