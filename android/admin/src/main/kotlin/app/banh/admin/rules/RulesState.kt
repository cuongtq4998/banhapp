package app.banh.admin.rules

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem
import app.banh.admin.owner.Validation
import app.banh.admin.owner.problemsOf
import app.banh.core.model.OrderingRules
import app.banh.core.model.OverLimitDay

const val LIMIT_MAX = 9_999L
const val LEAD_MAX = 14L
const val MIN_MAX = 20L

object RulesField {
    const val LIMIT = "limit"
    const val LEAD = "lead"
    const val MIN = "min"
}

enum class RulesBusy { NONE, CHECKING, SAVING }

enum class RulesBanner { ERROR, OFFLINE }

/** The warning of AC-35: [days] hold more cakes than the new limit. [afterSave] is the list the save itself found (nothing to confirm, only to read). */
data class LimitWarning(val days: List<OverLimitDay>, val afterSave: Boolean)

data class RulesState(
    val stored: OrderingRules,
    val limit: String = stored.dailyLimit.toString(),
    val lead: String = stored.leadDays.toString(),
    val min: String = stored.minQty.toString(),
    val problems: Map<String, Problem> = emptyMap(),
    val busy: RulesBusy = RulesBusy.NONE,
    val banner: RulesBanner? = null,
    val warning: LimitWarning? = null,
    /** The dates the owner already saw and accepted; the save only shows its own list again when it differs. */
    val confirmed: List<OverLimitDay>? = null,
    val discard: Boolean = false,
    val done: Boolean = false,
) {
    val changed: Boolean get() = limit != stored.dailyLimit.toString() || lead != stored.leadDays.toString() || min != stored.minQty.toString()
    val canSave: Boolean get() = changed && busy == RulesBusy.NONE
    val limitValue: Int? get() = Validation.parseNumber(limit)?.toInt()
}

/** The three fields and the pair rule: the minimum may not exceed the daily limit (AC-36). */
fun validateRules(state: RulesState): Map<String, Problem> {
    val limit = Validation.number(state.limit, 1, LIMIT_MAX)
    val min = Validation.number(state.min, 1, MIN_MAX)
    val pair = if (limit == null && min == null && Validation.parseNumber(state.min)!! > Validation.parseNumber(state.limit)!!) Problem.MinAboveLimit else null
    return problemsOf(RulesField.LIMIT to limit, RulesField.LEAD to Validation.number(state.lead, 0, LEAD_MAX), RulesField.MIN to (min ?: pair))
}

/** A lower limit may push some dates over; only then is the server asked which (the preview is advisory, api/07 10.15). */
fun needsPreview(state: RulesState): Boolean = (state.limitValue ?: Int.MAX_VALUE) < state.stored.dailyLimit

sealed interface RulesIntent {
    data class Limit(val value: String) : RulesIntent

    data class Lead(val value: String) : RulesIntent

    data class Min(val value: String) : RulesIntent

    data object Save : RulesIntent

    /** The owner confirmed the warning dialog. */
    data object SaveAnyway : RulesIntent

    data class Warned(val days: List<OverLimitDay>) : RulesIntent

    data class Saved(val found: List<OverLimitDay>) : RulesIntent

    data class Failed(val failure: OwnerFailure) : RulesIntent

    data object Dismiss : RulesIntent

    data object Back : RulesIntent

    data object Closed : RulesIntent
}

private fun String.digits() = filter { it.isDigit() }.take(5)

fun reduceRules(state: RulesState, intent: RulesIntent): RulesState = when (intent) {
    is RulesIntent.Limit -> state.copy(limit = intent.value.digits(), problems = state.problems - RulesField.LIMIT - RulesField.MIN, banner = null)
    is RulesIntent.Lead -> state.copy(lead = intent.value.digits(), problems = state.problems - RulesField.LEAD, banner = null)
    is RulesIntent.Min -> state.copy(min = intent.value.digits(), problems = state.problems - RulesField.MIN, banner = null)
    RulesIntent.Save -> save(state)
    RulesIntent.SaveAnyway -> state.copy(confirmed = state.warning?.days, warning = null, busy = RulesBusy.SAVING)
    is RulesIntent.Warned -> if (intent.days.isEmpty()) state.copy(busy = RulesBusy.SAVING) else state.copy(busy = RulesBusy.NONE, warning = LimitWarning(intent.days, afterSave = false))
    is RulesIntent.Saved -> if (intent.found.isEmpty() || intent.found == state.confirmed) state.copy(busy = RulesBusy.NONE, done = true) else state.copy(busy = RulesBusy.NONE, warning = LimitWarning(intent.found, afterSave = true))
    is RulesIntent.Failed -> failed(state, intent.failure)
    RulesIntent.Dismiss -> if (state.warning?.afterSave == true) state.copy(warning = null, done = true) else state.copy(warning = null, discard = false)
    RulesIntent.Back -> if (state.changed && state.busy == RulesBusy.NONE) state.copy(discard = true) else state
    RulesIntent.Closed -> state.copy(done = true)
}

private fun save(state: RulesState): RulesState {
    if (!state.canSave) return state
    val problems = validateRules(state)
    return when {
        problems.isNotEmpty() -> state.copy(problems = problems)
        needsPreview(state) -> state.copy(busy = RulesBusy.CHECKING, banner = null)
        else -> state.copy(busy = RulesBusy.SAVING, banner = null)
    }
}

private fun failed(state: RulesState, failure: OwnerFailure): RulesState {
    val settled = state.copy(busy = RulesBusy.NONE, warning = null)
    return when {
        failure == OwnerFailure.Offline -> settled.copy(banner = RulesBanner.OFFLINE)
        failure is OwnerFailure.Fields -> settled.copy(problems = failure.issues.associate { issue ->
            when (issue.field) {
                "daily_limit" -> RulesField.LIMIT to Problem.Range(1, LIMIT_MAX)
                "lead_days" -> RulesField.LEAD to Problem.Range(0, LEAD_MAX)
                else -> RulesField.MIN to if (issue.code == "MIN_QTY_OUT_OF_RANGE") Problem.MinAboveLimit else Problem.Range(1, MIN_MAX)
            }
        })
        else -> settled.copy(banner = RulesBanner.ERROR)
    }
}
