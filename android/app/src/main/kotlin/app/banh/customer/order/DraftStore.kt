package app.banh.customer.order

import java.time.Duration
import java.time.Instant

/** Local copy of the draft. Reading never throws: a missing or damaged copy is simply absent. */
interface DraftStore {
    suspend fun read(): OrderDraft?

    /** Best effort: losing a write only loses convenience, so a failure is not an error. */
    suspend fun write(draft: OrderDraft)

    suspend fun clear()
}

/** A draft that nobody touched for this long is discarded (ADR-0011). */
val DRAFT_MAX_AGE: Duration = Duration.ofHours(24)

fun OrderDraft.isFresh(now: Instant): Boolean {
    val age = Duration.between(Instant.ofEpochMilli(savedAtEpochMillis), now)
    return age <= DRAFT_MAX_AGE
}
