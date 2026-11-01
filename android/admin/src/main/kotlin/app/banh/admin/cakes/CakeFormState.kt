package app.banh.admin.cakes

import app.banh.admin.owner.Limits
import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem
import app.banh.admin.owner.Validation
import app.banh.admin.owner.problems
import app.banh.admin.owner.problemsOf
import app.banh.admin.photo.PixelSize
import app.banh.core.model.Cake

const val NAME_MAX = 100
const val DESC_MAX = 300
const val PRICE_MAX = 100_000_000L

/** Form field keys, also the tail of the test ids `admin.cakeForm.error.<field>`. */
object CakeField {
    const val NAME = "name"
    const val DESC = "desc"
    const val PRICE = "price"
    const val IMAGE = "image"
}

private val SERVER_FIELDS = mapOf("name" to CakeField.NAME, "description" to CakeField.DESC, "price_vnd" to CakeField.PRICE, "image" to CakeField.IMAGE)
private val LIMITS = mapOf("name" to Limits(1, NAME_MAX.toLong()), "description" to Limits(1, DESC_MAX.toLong()), "price_vnd" to Limits(1, PRICE_MAX))

/** A picture that is ready to upload (already a JPEG within the limits). Not a data class: comparing megabytes of bytes is never wanted. */
class Photo(val jpeg: ByteArray, val size: PixelSize)

enum class CakeBusy { NONE, ENCODING, SAVING, REMOVING }

enum class CakeBanner { UPLOAD_FAILED, ERROR, OFFLINE, CAKES_FULL }

enum class CakeToast { LAST_CAKE, ERROR }

enum class CakeDialog { NONE, REMOVE, DISCARD }

enum class CakeDone { NONE, ADDED, SAVED, REMOVED }

data class CakeFormState(
    /** The stored cake in edit mode; null when adding. */
    val original: Cake? = null,
    /** Editing the only cake that is on sale: it can neither be hidden nor removed (AC-32). */
    val onlyActive: Boolean = false,
    val name: String = original?.name.orEmpty(),
    val description: String = original?.description.orEmpty(),
    val price: String = original?.priceVnd?.toString().orEmpty(),
    val active: Boolean = original?.isActive ?: true,
    val photo: Photo? = null,
    val photoProblem: Problem? = null,
    val problems: Map<String, Problem> = emptyMap(),
    val busy: CakeBusy = CakeBusy.NONE,
    val progress: Int = 0,
    val banner: CakeBanner? = null,
    val toast: CakeToast? = null,
    val dialog: CakeDialog = CakeDialog.NONE,
    val gone: Boolean = false,
    val done: CakeDone = CakeDone.NONE,
) {
    val isAdd: Boolean get() = original == null

    val changed: Boolean
        get() = if (original == null) name.isNotBlank() || description.isNotBlank() || price.isNotBlank() || photo != null
        else name != original.name || description != original.description || price != original.priceVnd.toString() || active != original.isActive

    /** Save is on once something differs from the stored cake (or, adding, from the empty form); tapping it then lists every missing field at once (AC-40). */
    val canSave: Boolean get() = busy == CakeBusy.NONE && changed
}

/** All problems of the form at once, each naming its field (AC-40); empty when the form may go to the server. */
fun validateCake(state: CakeFormState): Map<String, Problem> = problemsOf(
    CakeField.NAME to Validation.text(state.name, NAME_MAX),
    CakeField.DESC to Validation.text(state.description, DESC_MAX),
    CakeField.PRICE to Validation.number(state.price, 1, PRICE_MAX),
    CakeField.IMAGE to if (state.isAdd && state.photo == null) Problem.ImageRequired else null,
)

/** The state after a failed save, remove or upload (screens: S-A8 states Error, Offline; errors LAST_ACTIVE_CAKE, NAME_TAKEN, CAKE_LIMIT_REACHED). */
fun CakeFormState.failed(failure: OwnerFailure): CakeFormState {
    val settled = copy(busy = CakeBusy.NONE, progress = 0, dialog = CakeDialog.NONE)
    return when {
        failure == OwnerFailure.Offline -> settled.copy(banner = CakeBanner.OFFLINE)
        failure == OwnerFailure.Gone -> settled.copy(gone = true)
        failure is OwnerFailure.Fields -> {
            val mapped = failure.problems(LIMITS).mapKeys { SERVER_FIELDS[it.key] ?: it.key }
            settled.copy(problems = mapped.filterKeys { it != CakeField.IMAGE }, photoProblem = mapped[CakeField.IMAGE], photo = if (CakeField.IMAGE in mapped) null else photo)
        }
        failure is OwnerFailure.Code && failure.code == "CAKE_LIMIT_REACHED" -> settled.copy(banner = CakeBanner.CAKES_FULL)
        failure is OwnerFailure.Code && failure.code == "IMAGE_TOO_LARGE" -> settled.copy(photo = null, photoProblem = Problem.ImageSize)
        failure is OwnerFailure.Code && failure.code == "LAST_ACTIVE_CAKE" -> settled.copy(active = true, toast = CakeToast.LAST_CAKE)
        else -> settled.copy(banner = if (isAdd) CakeBanner.UPLOAD_FAILED else CakeBanner.ERROR)
    }
}
