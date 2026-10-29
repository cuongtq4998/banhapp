package app.banh.customer.order

private val IGNORED_SEPARATORS = Regex("[\\s.\\-()]")
private val MOBILE_PATTERN = Regex("^0[35789][0-9]{8}$")
private const val COUNTRY_PREFIX_PLUS = "+84"
private const val COUNTRY_PREFIX = "84"
private const val COUNTRY_FORM_LENGTH = 11
private const val NATIONAL_PREFIX = "0"

/** Vietnamese mobile numbers as ADR-0009 defines them; the same rule runs on the server and in the shared fixtures. */
object PhoneNumber {
    /** Drops spaces, dots, hyphens and parentheses and reads a leading `+84`, or `84` of 11 digits, as `0`. */
    fun normalize(raw: String): String {
        val compact = raw.replace(IGNORED_SEPARATORS, "")
        return when {
            compact.startsWith(COUNTRY_PREFIX_PLUS) -> NATIONAL_PREFIX + compact.removePrefix(COUNTRY_PREFIX_PLUS)
            compact.length == COUNTRY_FORM_LENGTH && compact.startsWith(COUNTRY_PREFIX) ->
                NATIONAL_PREFIX + compact.removePrefix(COUNTRY_PREFIX)
            else -> compact
        }
    }

    fun isValid(raw: String): Boolean = MOBILE_PATTERN.matches(normalize(raw))

    /** `+84` plus the nine digits, or null when [raw] is not a valid number. */
    fun toE164(raw: String): String? =
        normalize(raw).takeIf { MOBILE_PATTERN.matches(it) }?.let { COUNTRY_PREFIX_PLUS + it.removePrefix(NATIONAL_PREFIX) }
}
