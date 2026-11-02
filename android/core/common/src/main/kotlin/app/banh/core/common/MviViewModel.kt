package app.banh.core.common

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * One screen store (ADR-0007): the screen sends [Intent]s, [reduce] (a pure function, tested alone) makes the next [State],
 * and [handle] runs the work that needs the network or the clock and sends its result back as another intent.
 * One-shot events (a toast, a haptic) leave through [effects] so that a rotation does not repeat them.
 */
abstract class MviViewModel<State, Intent, Effect>(initial: State) : ViewModel() {
    private val mutableState = MutableStateFlow(initial)
    val state: StateFlow<State> = mutableState.asStateFlow()

    private val mutableEffects = MutableSharedFlow<Effect>(extraBufferCapacity = EFFECT_BUFFER)
    val effects: SharedFlow<Effect> = mutableEffects.asSharedFlow()

    protected abstract fun reduce(state: State, intent: Intent): State

    /** Side work for [intent], called after the state has been reduced. Runs in the view model scope. */
    protected open suspend fun handle(intent: Intent) = Unit

    fun dispatch(intent: Intent) {
        mutableState.update { reduce(it, intent) }
        viewModelScope.launch { handle(intent) }
    }

    protected fun emit(effect: Effect) {
        mutableEffects.tryEmit(effect)
    }

    protected val current: State get() = mutableState.value

    protected val scope: CoroutineScope get() = viewModelScope

    private companion object {
        const val EFFECT_BUFFER = 8
    }
}
