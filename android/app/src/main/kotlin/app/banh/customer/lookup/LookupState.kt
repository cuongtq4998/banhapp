package app.banh.customer.lookup

import app.banh.customer.data.lookup.LookupAnswer
import app.banh.customer.data.lookup.LookupOrder

/** At most 5 pages of 10 (api/10); page 5 has no cursor, and then the limit line shows. */
const val LOOKUP_MAX_PAGES = 5
private const val PHONE_MIN_DIGITS = 9
private const val PHONE_MAX_DIGITS = 11

/** A problem on the screen; earlier loaded pages stay visible under it. */
sealed interface LookupProblem {
    data object Offline : LookupProblem

    data object Generic : LookupProblem

    /** Page 2 or later failed: the load-more row becomes a retry button. */
    data object MoreFailed : LookupProblem

    /** Submit and refresh are off until [remainingSeconds] reaches 0. */
    data class RateLimited(val remainingSeconds: Int) : LookupProblem
}

/**
 * The state of S-10 and S-11. Lives in the view model only: the phone is never written to the device, and no saved state
 * holds it. [asOf] is the server time of the last answer and is the offline "data as of" line, never the device clock.
 */
data class LookupState(
    val phone: String = "",
    val phoneError: Boolean = false,
    val loading: Boolean = false,
    val loadingMore: Boolean = false,
    val hasResult: Boolean = false,
    val orders: List<LookupOrder> = emptyList(),
    val nextCursor: String? = null,
    val pagesLoaded: Int = 0,
    val asOf: String? = null,
    val problem: LookupProblem? = null,
) {
    /** The same empty screen for a number that never ordered and one whose orders are gone. */
    val isEmpty: Boolean get() = hasResult && orders.isEmpty()
    val showsLimitLine: Boolean get() = hasResult && nextCursor == null && pagesLoaded >= LOOKUP_MAX_PAGES
    val rateLimited: Boolean get() = problem is LookupProblem.RateLimited
    val canSubmit: Boolean get() = !loading && !rateLimited
}

/** Client hint only: 9 to 11 digits after cleaning. The server decides; a number failing the hint is not sent. */
fun looksLikePhone(raw: String): Boolean = raw.count { it.isDigit() } in PHONE_MIN_DIGITS..PHONE_MAX_DIGITS

fun LookupState.withFirstPage(answer: LookupAnswer) = copy(
    loading = false, loadingMore = false, hasResult = true, orders = answer.orders, nextCursor = answer.nextCursor,
    pagesLoaded = 1, asOf = answer.asOf, problem = null, phoneError = false,
)

/** Appends in server order; the app never re-sorts. */
fun LookupState.withNextPage(answer: LookupAnswer) = copy(
    loadingMore = false, orders = orders + answer.orders, nextCursor = answer.nextCursor,
    pagesLoaded = pagesLoaded + 1, asOf = answer.asOf, problem = null,
)

/** A failed first page keeps what was loaded; only a rejected phone or rate limit ends the result. */
fun LookupState.withFirstPageFailure(failure: LookupFailure) = when (failure) {
    is LookupFailure.PhoneRejected -> copy(loading = false, phoneError = true)
    is LookupFailure.RateLimited -> copy(loading = false, problem = LookupProblem.RateLimited(failure.waitSeconds))
    LookupFailure.Offline -> copy(loading = false, problem = LookupProblem.Offline)
    else -> copy(loading = false, problem = LookupProblem.Generic)
}

fun LookupState.withMoreFailure(failure: LookupFailure) = when (failure) {
    is LookupFailure.RateLimited -> copy(loadingMore = false, problem = LookupProblem.RateLimited(failure.waitSeconds))
    LookupFailure.Offline -> copy(loadingMore = false, problem = LookupProblem.Offline)
    else -> copy(loadingMore = false, problem = LookupProblem.MoreFailed)
}

fun LookupState.tickCountdown(): LookupState {
    val problem = problem as? LookupProblem.RateLimited ?: return this
    return copy(problem = if (problem.remainingSeconds <= 1) null else problem.copy(remainingSeconds = problem.remainingSeconds - 1))
}
