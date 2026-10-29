package app.banh.customer.testing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import app.banh.customer.data.availability.Availability
import app.banh.customer.data.availability.AvailabilityApi
import app.banh.customer.data.network.ApiException
import app.banh.customer.order.DraftStore
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.reduce

/** Answers every request with the scripted outcome (an [Availability] or an [ApiException]). */
class FakeAvailabilityApi(private val outcome: Any = ContractAssets.availability()) : AvailabilityApi {
    val requestedCakes = mutableListOf<Int>()

    override suspend fun fetchAvailability(cakes: Int): Availability {
        requestedCakes += cakes
        return when (outcome) {
            is Availability -> outcome
            is ApiException -> throw outcome
            else -> error("Unsupported scripted outcome $outcome")
        }
    }
}

class InMemoryDraftStore(var draft: OrderDraft? = null) : DraftStore {
    override suspend fun read(): OrderDraft? = draft

    override suspend fun write(draft: OrderDraft) {
        this.draft = draft
    }

    override suspend fun clear() {
        draft = null
    }
}

/**
 * Holds an [OrderFlowState] for a stateless screen and applies every intent with the real reducer, so a screen test
 * shows what the customer sees after a tap without a view model, a clock or a navigation host. [onIntent] sees each
 * intent too, for effects the reducer does not handle (retry, submit).
 */
@Composable
fun ReducerHost(
    initial: OrderFlowState,
    onIntent: (OrderIntent) -> Unit = {},
    content: @Composable (state: OrderFlowState, send: (OrderIntent) -> Unit) -> Unit,
) {
    var state by remember { mutableStateOf(initial) }
    content(state) { intent ->
        onIntent(intent)
        state = reduce(state, intent)
    }
}
