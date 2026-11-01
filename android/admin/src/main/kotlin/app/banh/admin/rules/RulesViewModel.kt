package app.banh.admin.rules

import app.banh.admin.owner.Outcome
import app.banh.admin.owner.OwnerApi
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.owner.Validation
import app.banh.admin.owner.attempt
import app.banh.core.common.MviViewModel

/** S-A9: preview of the dates a lower limit would overfill, then the save; the answer of the save lists the dates again (BR-11). */
class RulesViewModel(
    initial: RulesState,
    private val api: OwnerApi,
    private val store: SettingsViewModel,
) : MviViewModel<RulesState, RulesIntent, Nothing>(initial) {
    override fun reduce(state: RulesState, intent: RulesIntent) = reduceRules(state, intent)

    override suspend fun handle(intent: RulesIntent) {
        when (intent) {
            RulesIntent.Save -> when (current.busy) {
                RulesBusy.CHECKING -> preview()
                RulesBusy.SAVING -> save()
                RulesBusy.NONE -> Unit
            }
            RulesIntent.SaveAnyway -> save()
            is RulesIntent.Warned -> if (intent.days.isEmpty()) save()
            else -> Unit
        }
    }

    private suspend fun preview() {
        when (val result = attempt { api.impact(checkNotNull(current.limitValue)) }) {
            is Outcome.Ok -> dispatch(RulesIntent.Warned(result.value.overLimit))
            is Outcome.Failed -> dispatch(RulesIntent.Failed(result.failure))
            Outcome.Ended -> Unit
        }
    }

    private suspend fun save() {
        val state = current
        val result = attempt { api.saveOrdering(checkNotNull(state.limitValue), checkNotNull(Validation.parseNumber(state.lead)).toInt(), checkNotNull(Validation.parseNumber(state.min)).toInt()) }
        when (result) {
            is Outcome.Ok -> {
                store.reload()
                store.show(OwnerToast.SAVED)
                // What the save found is shown unless the owner already accepted exactly that list: orders may have arrived since the preview.
                dispatch(RulesIntent.Saved(result.value.overLimit))
            }
            is Outcome.Failed -> dispatch(RulesIntent.Failed(result.failure))
            Outcome.Ended -> Unit
        }
    }
}
