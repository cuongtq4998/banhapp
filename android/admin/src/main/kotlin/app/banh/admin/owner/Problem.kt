package app.banh.admin.owner

import app.banh.core.network.FieldIssue

/** A problem with one form field, from the phone's check or from the server's answer; the screen turns it into the `A_ERR_*` text naming the field. */
sealed interface Problem {
    data object Required : Problem

    data class TooLong(val max: Int) : Problem

    data class Range(val min: Long, val max: Long) : Problem

    data object Phone : Problem

    data object MinAboveLimit : Problem

    /** The name is used already (cake, district) or the e-mail is. */
    data object Taken : Problem

    data object EmailInvalid : Problem

    /** A time slot must start before it ends / the same pair exists already. */
    data object SlotOrder : Problem

    data object SlotDuplicate : Problem

    data object ImageRequired : Problem

    data object ImageType : Problem

    data object ImageSize : Problem

    data object ImageRead : Problem
}

/** Limits of one field, used to word a server code (`..._OUT_OF_RANGE`, `..._TOO_LONG`) the same way as the phone's own check. */
class Limits(val min: Long = 0, val max: Long = 0)

/** Server field codes end in `_REQUIRED`, `_INVALID`, `_TOO_LONG`, `_OUT_OF_RANGE`, `_TAKEN` or are image codes (api/07 10.17). */
fun FieldIssue.toProblem(limits: Limits): Problem = when {
    code == "MIN_QTY_OUT_OF_RANGE" -> Problem.MinAboveLimit
    code == "IMAGE_REQUIRED" -> Problem.ImageRequired
    code == "IMAGE_TYPE_UNSUPPORTED" -> Problem.ImageType
    code.startsWith("IMAGE_") -> Problem.ImageRead
    code.endsWith("_REQUIRED") -> Problem.Required
    code.endsWith("_TOO_LONG") -> Problem.TooLong(limits.max.toInt())
    code.endsWith("_TAKEN") -> Problem.Taken
    field == "phone_contact" -> Problem.Phone
    field == "email" -> Problem.EmailInvalid
    else -> Problem.Range(limits.min, limits.max)
}

/** Field problems of a 422, keyed by the field name of the API; [limits] gives the numbers for each field. */
fun OwnerFailure.Fields.problems(limits: Map<String, Limits>): Map<String, Problem> =
    issues.associate { it.field to it.toProblem(limits[it.field] ?: Limits()) }
