package app.banh.customer.order

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.availability.Availability
import app.banh.customer.data.network.ApiException
import java.util.UUID
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * The order flow store (ADR-0007), scoped to the order navigation graph so S-5 to S-8 share one draft (FR-15). It
 * applies intents with [reduce], saves the draft after every change (ADR-0011), loads availability for S-6, and
 * turns the check on S-7 into an effect.
 */
class OrderFlowViewModel(
    private val dependencies: OrderDependencies,
    private val newKey: () -> String = { UUID.randomUUID().toString() },
) : ViewModel() {
    private val mutableState = MutableStateFlow(OrderFlowState(draft = OrderDraft.blank(newKey())))
    val state: StateFlow<OrderFlowState> = mutableState.asStateFlow()

    private val effectChannel = Channel<OrderEffect>(Channel.BUFFERED)
    val effects: Flow<OrderEffect> = effectChannel.receiveAsFlow()

    private var availabilityJob: Job? = null

    // The draft as it is on disk, so a change that only the catalog caused (a hidden cake) is saved too, and a draft that
    // was just read is not written back unchanged.
    private var persistedDraft: OrderDraft? = null
    private val restoreJob: Job = viewModelScope.launch { restoreDraft() }

    init {
        viewModelScope.launch {
            dependencies.catalog.catalog.collect { onIntent(OrderIntent.CatalogChanged(it, newKey())) }
        }
        viewModelScope.launch { saveEveryChange() }
    }

    fun onIntent(intent: OrderIntent) {
        mutableState.update { withKeyRule(it, reduce(it, intent), intent, newKey) }
        when (intent) {
            OrderIntent.LoadAvailability -> loadAvailability()
            OrderIntent.RetryCatalog -> viewModelScope.launch { dependencies.catalog.refresh() }
            OrderIntent.SubmitRecipient -> announceRecipientCheck()
            else -> Unit
        }
    }

    /**
     * Called when the flow opens. From a cake detail ([productId] given) a new draft starts with that cake at 1; from
     * the home screen the saved draft stays as restored (UI document 5.5, ADR-0011).
     */
    fun start(productId: String?) {
        if (productId == null) return
        viewModelScope.launch {
            restoreJob.join()
            onIntent(OrderIntent.StartNew(productId, newKey()))
        }
    }

    private suspend fun restoreDraft() {
        val saved = dependencies.drafts.read()
        val fresh = saved?.takeIf { it.isFresh(dependencies.clock.instant()) }
        if (saved != null && fresh == null) dependencies.drafts.clear()
        persistedDraft = fresh ?: mutableState.value.draft
        onIntent(OrderIntent.DraftRestored(fresh, newKey()))
    }

    private suspend fun saveEveryChange() {
        mutableState
            .filter { it.draftLoaded }
            .map { it.draft }
            .distinctUntilChanged()
            .collect { draft ->
                if (draft == persistedDraft) return@collect
                persistedDraft = draft
                dependencies.drafts.write(draft.copy(savedAtEpochMillis = dependencies.clock.millis()))
            }
    }

    private fun loadAvailability() {
        availabilityJob?.cancel()
        val cakes = mutableState.value.summary?.totalQuantity?.takeIf { it > 0 } ?: return
        availabilityJob = viewModelScope.launch {
            val result: Load<Availability> = try {
                Load.Ready(dependencies.availability.fetchAvailability(cakes))
            } catch (e: ApiException) {
                Load.Failed(if (e is ApiException.NetworkUnavailable) LoadFailure.NETWORK else LoadFailure.OTHER)
            }
            onIntent(OrderIntent.AvailabilityLoaded(cakes, result))
        }
    }

    private fun announceRecipientCheck() {
        val firstError = mutableState.value.recipientErrors.keys.firstOrNull()
        effectChannel.trySend(if (firstError == null) OrderEffect.GoToReview else OrderEffect.FocusField(firstError))
    }
}
