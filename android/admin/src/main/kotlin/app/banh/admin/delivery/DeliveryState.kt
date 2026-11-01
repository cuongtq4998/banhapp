package app.banh.admin.delivery

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem
import app.banh.admin.owner.Validation
import app.banh.admin.owner.problemsOf
import app.banh.core.model.District
import app.banh.core.model.DeliverySlot

const val DISTRICT_NAME_MAX = 100
const val FEE_MAX = 10_000_000L
val NEW_SLOT_START = "12:00"
val NEW_SLOT_END = "14:00"

enum class SheetKind { DISTRICT, SLOT }

object DeliveryField {
    const val NAME = "name"
    const val FEE = "fee"
    const val TIME = "time"
}

enum class DeliveryBanner { ERROR, OFFLINE }

/** One edit sheet (district or slot, add or change); the values are text until Save. */
data class DeliverySheet(
    val kind: SheetKind,
    val id: String? = null,
    val name: String = "",
    val fee: String = "",
    val start: String = NEW_SLOT_START,
    val end: String = NEW_SLOT_END,
    val stored: Pair<String, String>? = null,
    val problems: Map<String, Problem> = emptyMap(),
    val saving: Boolean = false,
    val banner: DeliveryBanner? = null,
) {
    private val values: Pair<String, String> get() = if (kind == SheetKind.DISTRICT) name to fee else start to end
    val canSave: Boolean get() = !saving && if (kind == SheetKind.DISTRICT) name.isNotBlank() && fee.isNotBlank() && values != stored else values != stored
}

/** `LastDistrict` and `LastSlot` are the refusals of AC-37 and AC-38: the switch stays on and a toast says why. */
enum class DeliveryToast { LAST_DISTRICT, LAST_SLOT, ERROR, OFFLINE }

data class DeliveryState(
    val sheet: DeliverySheet? = null,
    /** Ids whose switch is being saved (dimmed, not tappable). */
    val pending: Set<String> = emptySet(),
    val toast: DeliveryToast? = null,
)

sealed interface DeliveryIntent {
    data class OpenDistrict(val district: District?) : DeliveryIntent

    data class OpenSlot(val slot: DeliverySlot?) : DeliveryIntent

    data object CloseSheet : DeliveryIntent

    data class Name(val value: String) : DeliveryIntent

    data class Fee(val value: String) : DeliveryIntent

    data class Start(val value: String) : DeliveryIntent

    data class End(val value: String) : DeliveryIntent

    data object SaveSheet : DeliveryIntent

    data class SheetFailed(val failure: OwnerFailure) : DeliveryIntent

    data class Toggle(val kind: SheetKind, val id: String, val active: Boolean) : DeliveryIntent

    data class ToggleDone(val id: String, val failure: OwnerFailure?) : DeliveryIntent

    data object ToastShown : DeliveryIntent
}

fun validateSheet(sheet: DeliverySheet): Map<String, Problem> = when (sheet.kind) {
    SheetKind.DISTRICT -> problemsOf(DeliveryField.NAME to Validation.text(sheet.name, DISTRICT_NAME_MAX), DeliveryField.FEE to Validation.number(sheet.fee, 1, FEE_MAX))
    SheetKind.SLOT -> problemsOf(DeliveryField.TIME to if (sheet.start >= sheet.end) Problem.SlotOrder else null)
}

fun reduceDelivery(state: DeliveryState, intent: DeliveryIntent): DeliveryState = when (intent) {
    is DeliveryIntent.OpenDistrict -> state.copy(
        sheet = intent.district?.let { DeliverySheet(SheetKind.DISTRICT, it.districtId, it.name, it.deliveryFeeVnd.toString(), stored = it.name to it.deliveryFeeVnd.toString()) } ?: DeliverySheet(SheetKind.DISTRICT),
    )
    is DeliveryIntent.OpenSlot -> state.copy(
        sheet = intent.slot?.let { DeliverySheet(SheetKind.SLOT, it.slotId, start = it.start, end = it.end, stored = it.start to it.end) } ?: DeliverySheet(SheetKind.SLOT),
    )
    DeliveryIntent.CloseSheet -> state.copy(sheet = null)
    is DeliveryIntent.Name -> state.edit { copy(name = intent.value.take(DISTRICT_NAME_MAX), problems = problems - DeliveryField.NAME, banner = null) }
    is DeliveryIntent.Fee -> state.edit { copy(fee = intent.value.filter { it.isDigit() || it == '.' || it == ',' }.take(FEE_DIGITS), problems = problems - DeliveryField.FEE, banner = null) }
    is DeliveryIntent.Start -> state.edit { copy(start = intent.value, problems = emptyMap(), banner = null) }
    is DeliveryIntent.End -> state.edit { copy(end = intent.value, problems = emptyMap(), banner = null) }
    DeliveryIntent.SaveSheet -> state.edit { if (!canSave) this else validateSheet(this).let { if (it.isEmpty()) copy(saving = true, banner = null) else copy(problems = it) } }
    is DeliveryIntent.SheetFailed -> state.edit { sheetFailed(this, intent.failure) }
    is DeliveryIntent.Toggle -> if (intent.id in state.pending) state else state.copy(pending = state.pending + intent.id)
    is DeliveryIntent.ToggleDone -> state.copy(pending = state.pending - intent.id, toast = intent.failure?.let(::toastOf) ?: state.toast)
    DeliveryIntent.ToastShown -> state.copy(toast = null)
}

private fun DeliveryState.edit(change: DeliverySheet.() -> DeliverySheet): DeliveryState = sheet?.let { copy(sheet = it.change()) } ?: this

private fun toastOf(failure: OwnerFailure): DeliveryToast = when {
    failure == OwnerFailure.Offline -> DeliveryToast.OFFLINE
    failure is OwnerFailure.Code && failure.code == "LAST_ACTIVE_DISTRICT" -> DeliveryToast.LAST_DISTRICT
    failure is OwnerFailure.Code && failure.code == "LAST_ACTIVE_SLOT" -> DeliveryToast.LAST_SLOT
    else -> DeliveryToast.ERROR
}


private fun sheetFailed(sheet: DeliverySheet, failure: OwnerFailure): DeliverySheet {
    val settled = sheet.copy(saving = false)
    return when {
        failure == OwnerFailure.Offline -> settled.copy(banner = DeliveryBanner.OFFLINE)
        failure is OwnerFailure.Code && failure.code == "SLOT_DUPLICATE" -> settled.copy(problems = mapOf(DeliveryField.TIME to Problem.SlotDuplicate))
        failure is OwnerFailure.Fields -> settled.copy(problems = failure.issues.associate { issue ->
            when (issue.field) {
                "name" -> DeliveryField.NAME to if (issue.code.endsWith("_TAKEN")) Problem.Taken else Problem.Required
                "delivery_fee_vnd" -> DeliveryField.FEE to Problem.Range(1, FEE_MAX)
                else -> DeliveryField.TIME to Problem.SlotOrder
            }
        })
        else -> settled.copy(banner = DeliveryBanner.ERROR)
    }
}

private const val FEE_DIGITS = 9
