package app.banh.customer.lookup

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.banh.customer.data.lookup.OrderLookupApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val TICK_MS = 1_000L

/**
 * Store of S-10 and S-11. Holds the phone in memory for the process only: it takes no preference store, no draft store
 * and no saved-state handle, so the phone cannot reach the device storage.
 */
class LookupViewModel(private val api: OrderLookupApi) : ViewModel() {
    private val mutableState = MutableStateFlow(LookupState())
    val state: StateFlow<LookupState> = mutableState.asStateFlow()
    private var job: Job? = null
    private var countdown: Job? = null

    fun onPhoneChanged(text: String) = mutableState.update { it.copy(phone = text, phoneError = false) }

    /** From the confirmation shortcut: fills the phone and looks up at once. */
    fun startWith(phone: String) {
        mutableState.update { it.copy(phone = phone) }
        submit()
    }

    fun submit() {
        val current = mutableState.value
        if (!current.canSubmit) return
        if (!looksLikePhone(current.phone)) {
            mutableState.update { it.copy(phoneError = true) }
            return
        }
        loadFirstPage()
    }

    /** Pull to refresh: restarts at page 1; loaded pages stay until the answer arrives. */
    fun refresh() {
        val current = mutableState.value
        if (current.canSubmit && current.hasResult) loadFirstPage()
    }

    fun loadMore() {
        val current = mutableState.value
        val cursor = current.nextCursor ?: return
        if (current.loading || current.loadingMore || current.rateLimited) return
        mutableState.update { it.copy(loadingMore = true, problem = null) }
        launchLoad {
            runCatching { api.lookup(current.phone, cursor) }
                .onSuccess { answer -> mutableState.update { it.withNextPage(answer) } }
                .onFailure { onMoreFailed(it.toLookupFailure()) }
        }
    }

    private fun loadFirstPage() {
        val phone = mutableState.value.phone
        mutableState.update { it.copy(loading = true, problem = null, phoneError = false) }
        launchLoad {
            runCatching { api.lookup(phone, null) }
                .onSuccess { answer -> mutableState.update { it.withFirstPage(answer) } }
                .onFailure { failure -> onFirstFailed(failure.toLookupFailure()) }
        }
    }

    private fun onMoreFailed(failure: LookupFailure) {
        if (failure == LookupFailure.CursorInvalid) {
            mutableState.update { it.copy(loadingMore = false) }
            loadFirstPage()
            return
        }
        mutableState.update { it.withMoreFailure(failure) }
        startCountdownIfLimited(failure)
    }

    private fun onFirstFailed(failure: LookupFailure) {
        mutableState.update { it.withFirstPageFailure(failure) }
        startCountdownIfLimited(failure)
    }

    private fun startCountdownIfLimited(failure: LookupFailure) {
        if (failure !is LookupFailure.RateLimited) return
        countdown?.cancel()
        countdown = viewModelScope.launch {
            while (mutableState.value.rateLimited) {
                delay(TICK_MS)
                mutableState.update { it.tickCountdown() }
            }
        }
    }

    private fun launchLoad(block: suspend () -> Unit) {
        job?.cancel()
        job = viewModelScope.launch { block() }
    }

    override fun onCleared() {
        mutableState.value = LookupState()
    }
}
