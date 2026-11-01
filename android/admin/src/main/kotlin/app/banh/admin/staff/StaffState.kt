package app.banh.admin.staff

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem
import app.banh.admin.owner.Validation
import app.banh.admin.owner.problemsOf

const val STAFF_NAME_MAX = 100

object StaffField {
    const val NAME = "name"
    const val EMAIL = "email"
}

enum class StaffBanner { ERROR, OFFLINE, FULL }

data class AddStaffSheet(
    val name: String = "",
    val email: String = "",
    val problems: Map<String, Problem> = emptyMap(),
    val saving: Boolean = false,
    val banner: StaffBanner? = null,
) {
    val canSave: Boolean get() = name.isNotBlank() && email.isNotBlank() && !saving
}

enum class StaffToast { FULL, ERROR, OFFLINE }

data class StaffState(
    val add: AddStaffSheet? = null,
    /** The account whose detail sheet is open. */
    val detailId: String? = null,
    val confirmDeactivate: Boolean = false,
    val busy: Boolean = false,
    val toast: StaffToast? = null,
)

sealed interface StaffIntent {
    data object OpenAdd : StaffIntent

    data class Name(val value: String) : StaffIntent

    data class Email(val value: String) : StaffIntent

    data object SaveAdd : StaffIntent

    data class AddFailed(val failure: OwnerFailure) : StaffIntent

    data class OpenDetail(val id: String) : StaffIntent

    data object Close : StaffIntent

    data object AskDeactivate : StaffIntent

    data object Dismiss : StaffIntent

    /** Switch the open account off ([active] false, after the dialog) or on again. */
    data class SetActive(val active: Boolean) : StaffIntent

    data class SetFailed(val failure: OwnerFailure) : StaffIntent

    data object SetDone : StaffIntent

    data object ToastShown : StaffIntent
}

fun reduceStaff(state: StaffState, intent: StaffIntent): StaffState = when (intent) {
    StaffIntent.OpenAdd -> state.copy(add = AddStaffSheet())
    is StaffIntent.Name -> state.editAdd { copy(name = intent.value.take(STAFF_NAME_MAX), problems = problems - StaffField.NAME, banner = null) }
    is StaffIntent.Email -> state.editAdd { copy(email = intent.value.take(EMAIL_MAX), problems = problems - StaffField.EMAIL, banner = null) }
    StaffIntent.SaveAdd -> state.editAdd {
        if (!canSave) this else problemsOf(StaffField.NAME to Validation.text(name, STAFF_NAME_MAX), StaffField.EMAIL to Validation.email(email))
            .let { if (it.isEmpty()) copy(saving = true, banner = null) else copy(problems = it) }
    }
    is StaffIntent.AddFailed -> state.editAdd { addFailed(this, intent.failure) }
    is StaffIntent.OpenDetail -> state.copy(detailId = intent.id, confirmDeactivate = false)
    StaffIntent.Close -> state.copy(add = null, detailId = null, confirmDeactivate = false)
    StaffIntent.AskDeactivate -> if (state.busy) state else state.copy(confirmDeactivate = true)
    StaffIntent.Dismiss -> state.copy(confirmDeactivate = false)
    is StaffIntent.SetActive -> if (state.busy) state else state.copy(busy = true, confirmDeactivate = false)
    is StaffIntent.SetFailed -> state.copy(busy = false, toast = toastOf(intent.failure))
    StaffIntent.SetDone -> state.copy(busy = false, toast = null, detailId = null)
    StaffIntent.ToastShown -> state.copy(toast = null)
}

private fun StaffState.editAdd(change: AddStaffSheet.() -> AddStaffSheet): StaffState = add?.let { copy(add = it.change()) } ?: this

private fun toastOf(failure: OwnerFailure): StaffToast = when {
    failure == OwnerFailure.Offline -> StaffToast.OFFLINE
    failure is OwnerFailure.Code && failure.code == "STAFF_LIMIT_REACHED" -> StaffToast.FULL
    else -> StaffToast.ERROR
}

private fun addFailed(sheet: AddStaffSheet, failure: OwnerFailure): AddStaffSheet {
    val settled = sheet.copy(saving = false)
    return when {
        failure == OwnerFailure.Offline -> settled.copy(banner = StaffBanner.OFFLINE)
        failure is OwnerFailure.Code && failure.code == "EMAIL_TAKEN" -> settled.copy(problems = mapOf(StaffField.EMAIL to Problem.Taken))
        failure is OwnerFailure.Code && failure.code == "EMAIL_INVALID" -> settled.copy(problems = mapOf(StaffField.EMAIL to Problem.EmailInvalid))
        failure is OwnerFailure.Code && failure.code == "STAFF_LIMIT_REACHED" -> settled.copy(banner = StaffBanner.FULL)
        failure is OwnerFailure.Fields -> settled.copy(problems = failure.issues.associate { (if (it.field == "email") StaffField.EMAIL else StaffField.NAME) to (if (it.field == "email") Problem.EmailInvalid else Problem.Required) })
        else -> settled.copy(banner = StaffBanner.ERROR)
    }
}

private const val EMAIL_MAX = 254
