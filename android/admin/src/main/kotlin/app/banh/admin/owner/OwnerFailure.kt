package app.banh.admin.owner

import app.banh.admin.auth.SessionEndedException
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import app.banh.core.network.FieldIssue
import kotlinx.coroutines.CancellationException

private const val UNPROCESSABLE = 422
private const val NOT_FOUND = 404

/** Why an owner call failed, in the terms the screens react to (api/07 and api/08 error codes). */
sealed interface OwnerFailure {
    data object Offline : OwnerFailure

    data object Generic : OwnerFailure

    data object Forbidden : OwnerFailure

    /** 404: the item is gone (removed on another phone). */
    data object Gone : OwnerFailure

    /** 422 `VALIDATION_FAILED`: every field problem the server found. */
    data class Fields(val issues: List<FieldIssue>) : OwnerFailure

    /** Any other named refusal: `LAST_ACTIVE_CAKE`, `SLOT_DUPLICATE`, `EMAIL_TAKEN`, ... */
    data class Code(val code: String) : OwnerFailure
}

fun ApiException.toFailure(): OwnerFailure = when {
    isOffline -> OwnerFailure.Offline
    this !is ApiException.Http -> OwnerFailure.Generic
    status == NOT_FOUND -> OwnerFailure.Gone
    status == 403 -> OwnerFailure.Forbidden
    status == UNPROCESSABLE && code == ErrorCodes.VALIDATION_FAILED && fields.isNotEmpty() -> OwnerFailure.Fields(fields)
    status in CLIENT_ERRORS || status == 409 || status == 413 -> OwnerFailure.Code(code)
    else -> OwnerFailure.Generic
}

private val CLIENT_ERRORS = 400..499

/** The result of one call, so view models branch without try blocks; [Ended] means the session ended and S-A1 already shows. */
sealed interface Outcome<out T> {
    data class Ok<T>(val value: T) : Outcome<T>

    data class Failed(val failure: OwnerFailure) : Outcome<Nothing>

    data object Ended : Outcome<Nothing>
}

suspend fun <T> attempt(block: suspend () -> T): Outcome<T> = try {
    Outcome.Ok(block())
} catch (e: CancellationException) {
    throw e
} catch (_: SessionEndedException) {
    Outcome.Ended
} catch (e: ApiException) {
    Outcome.Failed(e.toFailure())
}
