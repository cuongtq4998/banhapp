package app.banh.admin.cakes

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem

sealed interface CakeIntent {
    data class Name(val value: String) : CakeIntent

    data class Description(val value: String) : CakeIntent

    data class Price(val value: String) : CakeIntent

    data class Active(val value: Boolean) : CakeIntent

    /** The photo picker returned [source] (a URI as text). */
    data class Pick(val source: String) : CakeIntent

    data class PhotoReady(val photo: Photo) : CakeIntent

    data class PhotoRejected(val problem: Problem) : CakeIntent

    data object RemovePhoto : CakeIntent

    data object Save : CakeIntent

    data class Progress(val percent: Int) : CakeIntent

    data object CancelUpload : CakeIntent

    data class Failed(val failure: OwnerFailure) : CakeIntent

    data class Finished(val done: CakeDone) : CakeIntent

    data object AskRemove : CakeIntent

    data object RemoveYes : CakeIntent

    /** Back was pressed: leaves at once, or asks first when something was typed or picked. */
    data object Back : CakeIntent

    data object Dismiss : CakeIntent

    data object ToastShown : CakeIntent
}

fun reduceCake(state: CakeFormState, intent: CakeIntent): CakeFormState = when (intent) {
    is CakeIntent.Name -> state.copy(name = intent.value.take(NAME_MAX), problems = state.problems - CakeField.NAME, banner = null)
    is CakeIntent.Description -> state.copy(description = intent.value.take(DESC_MAX), problems = state.problems - CakeField.DESC, banner = null)
    is CakeIntent.Price -> state.copy(price = intent.value.filter { it.isDigit() || it == '.' || it == ',' }.take(PRICE_DIGITS), problems = state.problems - CakeField.PRICE, banner = null)
    // The only cake on sale cannot be hidden: the switch stays on and says why (AC-32).
    is CakeIntent.Active -> if (!intent.value && state.onlyActive) state.copy(toast = CakeToast.LAST_CAKE) else state.copy(active = intent.value, banner = null)
    is CakeIntent.Pick -> state.copy(busy = CakeBusy.ENCODING, photoProblem = null, problems = state.problems - CakeField.IMAGE)
    is CakeIntent.PhotoReady -> state.copy(busy = CakeBusy.NONE, photo = intent.photo, photoProblem = null)
    is CakeIntent.PhotoRejected -> state.copy(busy = CakeBusy.NONE, photo = null, photoProblem = intent.problem)
    CakeIntent.RemovePhoto -> state.copy(photo = null, photoProblem = null)
    CakeIntent.Save -> saveRequested(state)
    is CakeIntent.Progress -> state.copy(progress = intent.percent)
    CakeIntent.CancelUpload -> state.copy(busy = CakeBusy.NONE, progress = 0)
    is CakeIntent.Failed -> state.failed(intent.failure)
    is CakeIntent.Finished -> state.copy(busy = CakeBusy.NONE, done = intent.done)
    CakeIntent.AskRemove -> if (state.onlyActive) state.copy(toast = CakeToast.LAST_CAKE) else if (state.busy == CakeBusy.NONE) state.copy(dialog = CakeDialog.REMOVE) else state
    CakeIntent.RemoveYes -> state.copy(dialog = CakeDialog.NONE, busy = CakeBusy.REMOVING, banner = null)
    CakeIntent.Back -> if (state.changed && state.busy == CakeBusy.NONE) state.copy(dialog = CakeDialog.DISCARD) else state
    CakeIntent.Dismiss -> state.copy(dialog = CakeDialog.NONE)
    CakeIntent.ToastShown -> state.copy(toast = null)
}

private fun saveRequested(state: CakeFormState): CakeFormState {
    if (state.busy != CakeBusy.NONE) return state
    val problems = validateCake(state)
    return if (problems.isEmpty()) state.copy(busy = CakeBusy.SAVING, progress = 0, banner = null, problems = emptyMap()) else state.copy(problems = problems)
}

private const val PRICE_DIGITS = 12
