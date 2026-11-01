package app.banh.admin.orders

import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Told by the detail screen after a status change, so the list (and the badge number) reload without reopening the app (FR-13). */
class OrderChanges {
    private val mutableVersion = MutableStateFlow(0)
    val version: StateFlow<Int> = mutableVersion.asStateFlow()

    fun notifyChanged() {
        mutableVersion.value += 1
    }
}

/** The shop date of the latest list or sign-in answer. The detail answer has none, but its due mark needs one (TQ-D8). */
class ServerDateHolder {
    private val value = AtomicReference<String?>(null)

    fun update(date: String) = value.set(date)

    fun get(): String? = value.get()
}
