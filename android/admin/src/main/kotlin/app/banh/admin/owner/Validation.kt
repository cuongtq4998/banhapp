package app.banh.admin.owner

/** The phone's own checks, run when Save is tapped, all fields at once (form rules, AC-40). The server repeats them (BR-11). */
object Validation {
    fun text(value: String, max: Int): Problem? = when {
        value.isBlank() -> Problem.Required
        value.trim().length > max -> Problem.TooLong(max)
        else -> null
    }

    /** A whole number; dots, commas and spaces are thousand separators. */
    fun number(value: String, min: Long, max: Long): Problem? {
        if (value.isBlank()) return Problem.Required
        val parsed = parseNumber(value) ?: return Problem.Range(min, max)
        return if (parsed in min..max) null else Problem.Range(min, max)
    }

    fun parseNumber(value: String): Long? = value.filterNot { it == '.' || it == ',' || it == ' ' }.takeIf { it.isNotEmpty() && it.all(Char::isDigit) && it.length <= MAX_DIGITS }?.toLongOrNull()

    /** Vietnamese numbers may be typed as 09xx or +849xx; the API takes E.164 (api/07 10.14). */
    fun phone(value: String): Problem? = if (value.isBlank()) Problem.Required else if (normalisePhone(value) == null) Problem.Phone else null

    fun normalisePhone(value: String): String? {
        val digits = value.filterNot { it in " .-()" }
        val e164 = when {
            digits.startsWith("+") -> digits
            digits.startsWith("0") -> "+84" + digits.drop(1)
            digits.startsWith("84") -> "+$digits"
            else -> return null
        }
        return e164.takeIf { PHONE.matches(it) }
    }

    fun email(value: String): Problem? = if (value.isBlank()) Problem.Required else if (EMAIL.matches(value.trim())) null else Problem.EmailInvalid

    private val PHONE = Regex("""^\+[1-9]\d{7,14}$""")
    private val EMAIL = Regex("""^[^@\s]+@[^@\s]+\.[^@\s]+$""")
    private const val MAX_DIGITS = 12
}

/** Collects the problems of several fields, leaving out the fields that are fine. */
fun problemsOf(vararg checks: Pair<String, Problem?>): Map<String, Problem> = checks.mapNotNull { (field, problem) -> problem?.let { field to it } }.toMap()
