package app.banh.customer.testing

import app.banh.customer.data.availability.Availability
import app.banh.customer.data.availability.AvailabilityApi
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.District
import app.banh.customer.data.catalog.Slot
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.ApiJson
import app.banh.customer.data.network.parseApiError
import app.banh.customer.data.orders.OrderApi
import app.banh.customer.data.orders.OrderReceipt
import app.banh.customer.data.orders.OrderRequest
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
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

/** The receipt of `order-created.json`. */
fun fixtureReceipt(): OrderReceipt = ApiJson.decodeFromString(
    OrderReceipt.serializer(),
    ApiJson.parseToJsonElement(ContractFixtures.read("order-created.json")).jsonObject.getValue("body").toString(),
)

/** The request body of `order-request.json`. */
fun fixtureOrderRequest(): OrderRequest = ApiJson.decodeFromString(OrderRequest.serializer(), ContractFixtures.read("order-request.json"))

private val ORDER_ERROR_STATUS = mapOf(
    "DATE_CAPACITY" to 409, "PRICE_CHANGED" to 409, "PRODUCT_UNAVAILABLE" to 409, "SLOT_UNAVAILABLE" to 409,
    "IDEMPOTENCY_KEY_REQUIRED" to 400, "HEADER_INVALID" to 400, "PAYLOAD_TOO_LARGE" to 413,
    "VALIDATION_FAILED" to 422, "MIN_QTY" to 422, "DATE_LEAD" to 422, "DATE_HORIZON" to 422,
    "DISTRICT_UNSERVED" to 422, "IDEMPOTENCY_KEY_REUSED" to 422, "RATE_LIMITED" to 429,
    "INTERNAL_ERROR" to 500, "ORDERING_PAUSED" to 503, "SERVICE_UNAVAILABLE" to 503,
)

/** The error of `order-error-<name>.json` ("price-changed", ...) as the client parses it, with the status api.md gives the code. */
fun orderFixtureError(name: String, retryAfterHeader: String? = null): ApiException {
    val body = ContractFixtures.read("order-error-$name.json")
    val code = ApiJson.parseToJsonElement(body).jsonObject.getValue("error").jsonObject.getValue("code").jsonPrimitive.content
    return parseApiError(checkNotNull(ORDER_ERROR_STATUS[code]) { "no status for $code" }, body, retryAfterHeader, ApiJson)
}

/**
 * Answers with scripted outcomes (an [OrderReceipt] or an [ApiException]); the last one repeats. While [gate] is set
 * a call waits for it, so a test can look at the state in the middle of a send.
 */
class FakeOrderApi(private vararg val outcomes: Any) : OrderApi {
    val calls = mutableListOf<Pair<OrderRequest, String>>()
    var gate: CompletableDeferred<Unit>? = null

    val keys: List<String> get() = calls.map { it.second }

    override suspend fun submit(request: OrderRequest, idempotencyKey: String): OrderReceipt {
        calls += request to idempotencyKey
        gate?.await()
        return when (val outcome = outcomes[minOf(calls.size, outcomes.size) - 1]) {
            is OrderReceipt -> outcome
            is ApiException -> throw outcome
            else -> error("Unsupported scripted outcome $outcome")
        }
    }
}
