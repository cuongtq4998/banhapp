package app.banh.admin.staff

import app.banh.admin.owner.Outcome
import app.banh.admin.owner.OwnerApi
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.owner.attempt
import app.banh.core.common.MviViewModel

/** S-A12: add a staff account, switch one off or on. The list itself is the shared store's, reloaded after every success. */
class StaffViewModel(private val api: OwnerApi, private val store: SettingsViewModel) : MviViewModel<StaffState, StaffIntent, Nothing>(StaffState()) {
    override fun reduce(state: StaffState, intent: StaffIntent) = reduceStaff(state, intent)

    override suspend fun handle(intent: StaffIntent) {
        when (intent) {
            StaffIntent.SaveAdd -> current.add?.takeIf { it.saving }?.let { add(it) }
            is StaffIntent.SetActive -> setActive(intent.active)
            else -> Unit
        }
    }

    private suspend fun add(sheet: AddStaffSheet) {
        when (val result = attempt { api.addStaff(sheet.name.trim(), sheet.email.trim()) }) {
            is Outcome.Ok -> {
                store.reload()
                store.show(OwnerToast.STAFF_ADDED)
                dispatch(StaffIntent.Close)
            }
            is Outcome.Failed -> dispatch(StaffIntent.AddFailed(result.failure))
            Outcome.Ended -> Unit
        }
    }

    private suspend fun setActive(active: Boolean) {
        val id = current.detailId ?: return
        when (val result = attempt { api.setStaffActive(id, active) }) {
            is Outcome.Ok -> {
                store.reload()
                store.show(OwnerToast.SAVED)
                dispatch(StaffIntent.SetDone)
            }
            is Outcome.Failed -> dispatch(StaffIntent.SetFailed(result.failure))
            Outcome.Ended -> Unit
        }
    }
}
