package app.banh.admin.cakes

import app.banh.admin.owner.CakeChanges
import app.banh.admin.owner.CakeUpload
import app.banh.admin.owner.Outcome
import app.banh.admin.owner.OwnerApi
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.owner.Validation
import app.banh.admin.owner.attempt
import app.banh.admin.photo.PhotoEncoder
import app.banh.admin.photo.PhotoResult
import app.banh.core.common.MviViewModel
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.Job

/** S-A8 for a new cake ([original] null) and for changing, hiding or removing one. Every success reloads the shared settings. */
class CakeFormViewModel(
    initial: CakeFormState,
    private val api: OwnerApi,
    private val encoder: PhotoEncoder,
    private val store: SettingsViewModel,
) : MviViewModel<CakeFormState, CakeIntent, Nothing>(initial) {
    private var upload: Job? = null

    override fun reduce(state: CakeFormState, intent: CakeIntent) = reduceCake(state, intent)

    override suspend fun handle(intent: CakeIntent) {
        when (intent) {
            is CakeIntent.Pick -> pick(intent.source)
            CakeIntent.Save -> if (current.busy == CakeBusy.SAVING) save()
            CakeIntent.CancelUpload -> upload?.cancel()
            CakeIntent.RemoveYes -> remove()
            else -> Unit
        }
    }

    private suspend fun pick(source: String) {
        when (val result = encoder.prepare(source)) {
            is PhotoResult.Ready -> dispatch(CakeIntent.PhotoReady(Photo(result.jpeg, result.size)))
            is PhotoResult.Rejected -> dispatch(CakeIntent.PhotoRejected(result.problem))
        }
    }

    private suspend fun save() {
        upload = coroutineContext[Job]
        val state = current
        val original = state.original
        val price = checkNotNull(Validation.parseNumber(state.price))
        val outcome = if (original == null) {
            attempt { api.addCake(CakeUpload(state.name.trim(), state.description.trim(), price, checkNotNull(state.photo).jpeg)) { dispatch(CakeIntent.Progress(it)) } }
        } else {
            attempt { api.changeCake(original.cakeId, changesOf(state, original, price)) }
        }
        finish(outcome, if (original == null) CakeDone.ADDED else CakeDone.SAVED, if (original == null) OwnerToast.CAKE_ADDED else OwnerToast.SAVED)
    }

    private suspend fun remove() {
        val id = checkNotNull(current.original).cakeId
        finish(attempt { api.removeCake(id) }, CakeDone.REMOVED, OwnerToast.CAKE_REMOVED)
    }

    private fun finish(outcome: Outcome<*>, done: CakeDone, toast: OwnerToast) {
        when (outcome) {
            is Outcome.Ok -> {
                store.reload()
                store.show(toast)
                dispatch(CakeIntent.Finished(done))
            }
            is Outcome.Failed -> dispatch(CakeIntent.Failed(outcome.failure))
            Outcome.Ended -> Unit
        }
    }

    private fun changesOf(state: CakeFormState, original: app.banh.core.model.Cake, price: Long) = CakeChanges(
        name = state.name.trim().takeIf { it != original.name },
        description = state.description.trim().takeIf { it != original.description },
        priceVnd = price.takeIf { it != original.priceVnd },
        isActive = state.active.takeIf { it != original.isActive },
    )
}
