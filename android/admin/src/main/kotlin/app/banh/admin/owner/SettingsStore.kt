package app.banh.admin.owner

import app.banh.core.common.MviViewModel
import app.banh.core.model.OwnerSettings
import app.banh.core.model.Role
import app.banh.core.model.StaffAccount

enum class LoadPhase { LOADING, READY, ERROR, OFFLINE }

/** Short messages that outlive the screen that caused them: a form closes first, then the list underneath shows the toast. */
enum class OwnerToast { SAVED, CAKE_ADDED, CAKE_REMOVED, STAFF_ADDED, ERR_GENERIC, OFFLINE_SAVE }

/** What the owner screens read: the whole settings answer and the staff list, reloaded after every successful write. */
data class SettingsState(
    val phase: LoadPhase = LoadPhase.LOADING,
    val settings: OwnerSettings? = null,
    val staff: List<StaffAccount>? = null,
    val toast: OwnerToast? = null,
) {
    /** Active staff, the owner not counted (the limit of 30 is for staff, BR-6). */
    val activeStaff: Int? get() = staff?.count { it.role == Role.STAFF && it.isActive }
}

sealed interface SettingsIntent {
    data object Load : SettingsIntent

    data class Loaded(val settings: OwnerSettings, val staff: List<StaffAccount>?) : SettingsIntent

    data class LoadFailed(val phase: LoadPhase) : SettingsIntent

    data class Show(val toast: OwnerToast) : SettingsIntent

    data object ToastShown : SettingsIntent
}

fun reduceSettings(state: SettingsState, intent: SettingsIntent): SettingsState = when (intent) {
    // A reload with data on screen is silent: the old values stay until the new ones arrive.
    SettingsIntent.Load -> if (state.settings == null) state.copy(phase = LoadPhase.LOADING) else state
    is SettingsIntent.Loaded -> state.copy(phase = LoadPhase.READY, settings = intent.settings, staff = intent.staff)
    is SettingsIntent.LoadFailed -> if (state.settings == null) state.copy(phase = intent.phase) else state
    is SettingsIntent.Show -> state.copy(toast = intent.toast)
    SettingsIntent.ToastShown -> state.copy(toast = null)
}

/** Lives as long as the sign-in period, so nothing of the shop's data outlives sign-out. S-A6 shows it; every form calls [reload] after a save. */
class SettingsViewModel(private val api: OwnerApi) : MviViewModel<SettingsState, SettingsIntent, Nothing>(SettingsState()) {
    init {
        dispatch(SettingsIntent.Load)
    }

    override fun reduce(state: SettingsState, intent: SettingsIntent) = reduceSettings(state, intent)

    override suspend fun handle(intent: SettingsIntent) {
        if (intent != SettingsIntent.Load) return
        when (val settings = attempt { api.settings() }) {
            is Outcome.Ok -> {
                val staff = (attempt { api.staff() } as? Outcome.Ok)?.value
                dispatch(SettingsIntent.Loaded(settings.value, staff))
            }
            is Outcome.Failed -> dispatch(SettingsIntent.LoadFailed(if (settings.failure == OwnerFailure.Offline) LoadPhase.OFFLINE else LoadPhase.ERROR))
            Outcome.Ended -> Unit
        }
    }

    fun reload() = dispatch(SettingsIntent.Load)

    fun show(toast: OwnerToast) = dispatch(SettingsIntent.Show(toast))

    fun toastShown() = dispatch(SettingsIntent.ToastShown)
}
