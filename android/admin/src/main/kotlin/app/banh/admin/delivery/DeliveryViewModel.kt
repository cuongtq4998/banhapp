package app.banh.admin.delivery

import app.banh.admin.owner.DistrictChanges
import app.banh.admin.owner.Outcome
import app.banh.admin.owner.OwnerApi
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.owner.SlotChanges
import app.banh.admin.owner.Validation
import app.banh.admin.owner.attempt
import app.banh.core.common.MviViewModel

/** S-A10: districts and slots on one screen; a switch saves at once, a sheet saves on its button. Every success reloads the shared settings. */
class DeliveryViewModel(private val api: OwnerApi, private val store: SettingsViewModel) : MviViewModel<DeliveryState, DeliveryIntent, Nothing>(DeliveryState()) {
    override fun reduce(state: DeliveryState, intent: DeliveryIntent) = reduceDelivery(state, intent)

    override suspend fun handle(intent: DeliveryIntent) {
        when (intent) {
            DeliveryIntent.SaveSheet -> current.sheet?.takeIf { it.saving }?.let { saveSheet(it) }
            is DeliveryIntent.Toggle -> toggle(intent)
            else -> Unit
        }
    }

    private suspend fun saveSheet(sheet: DeliverySheet) {
        val outcome = when (sheet.kind) {
            SheetKind.DISTRICT -> {
                val fee = checkNotNull(Validation.parseNumber(sheet.fee))
                attempt { if (sheet.id == null) api.addDistrict(sheet.name.trim(), fee) else api.changeDistrict(sheet.id, DistrictChanges(sheet.name.trim(), fee)) }
            }
            SheetKind.SLOT -> attempt { if (sheet.id == null) api.addSlot(sheet.start, sheet.end) else api.changeSlot(sheet.id, SlotChanges(sheet.start, sheet.end)) }
        }
        when (outcome) {
            is Outcome.Ok -> {
                store.reload()
                store.show(OwnerToast.SAVED)
                dispatch(DeliveryIntent.CloseSheet)
            }
            is Outcome.Failed -> dispatch(DeliveryIntent.SheetFailed(outcome.failure))
            Outcome.Ended -> Unit
        }
    }

    private suspend fun toggle(intent: DeliveryIntent.Toggle) {
        val outcome = when (intent.kind) {
            SheetKind.DISTRICT -> attempt { api.changeDistrict(intent.id, DistrictChanges(isActive = intent.active)) }
            SheetKind.SLOT -> attempt { api.changeSlot(intent.id, SlotChanges(isActive = intent.active)) }
        }
        when (outcome) {
            is Outcome.Ok -> {
                store.reload()
                dispatch(DeliveryIntent.ToggleDone(intent.id, null))
            }
            is Outcome.Failed -> dispatch(DeliveryIntent.ToggleDone(intent.id, outcome.failure))
            Outcome.Ended -> Unit
        }
    }
}
