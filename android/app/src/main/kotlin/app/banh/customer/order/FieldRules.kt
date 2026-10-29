package app.banh.customer.order

import java.text.Normalizer

/** The text fields with limits (ADR-0009). */
enum class TextInput(val min: Int, val allowsNewline: Boolean) {
    NAME(min = 1, allowsNewline = false),
    ADDRESS(min = 1, allowsNewline = true),
    NOTE(min = 0, allowsNewline = true),
}

/** Result of cleaning what the customer typed or pasted. */
data class CleanedInput(val text: String, val exceededLimit: Boolean)

/**
 * Length and character rules of ADR-0009. Lengths count Unicode code points after NFC normalisation and trimming, so
 * composed and decomposed Vietnamese letters count the same.
 */
object FieldRules {
    const val NAME_MAX = 100
    const val ADDRESS_MAX = 250

    /** The note limit is configuration (`note_max_length`, 200); this is the value before the catalog is known. */
    const val NOTE_MAX = 200

    fun defaultMax(field: TextInput): Int = when (field) {
        TextInput.NAME -> NAME_MAX
        TextInput.ADDRESS -> ADDRESS_MAX
        TextInput.NOTE -> NOTE_MAX
    }

    /** Length as the server counts it. */
    fun lengthOf(text: String): Int {
        val normalized = Normalizer.normalize(text, Normalizer.Form.NFC).trim()
        return normalized.codePointCount(0, normalized.length)
    }

    /** True when [text] has no control character except the newline where the field allows it. */
    fun hasOnlyAllowedCharacters(field: TextInput, text: String): Boolean =
        text.none { isDisallowed(field, it) }

    /** Valid as submitted: within the minimum and [max], and free of control characters. */
    fun isValid(field: TextInput, text: String, max: Int = defaultMax(field)): Boolean =
        hasOnlyAllowedCharacters(field, text) && lengthOf(text) in field.min..max

    /**
     * Applies what an input field must do with each change: control characters are not inserted, and text beyond
     * [max] code points is cut (typed or pasted alike). Leading and trailing blanks stay, because the customer may be
     * in the middle of a word; they are trimmed when the value is checked and sent.
     */
    fun cleanInput(field: TextInput, text: String, max: Int = defaultMax(field)): CleanedInput {
        val allowed = text.filterNot { isDisallowed(field, it) }
        val count = allowed.codePointCount(0, allowed.length)
        if (count <= max) return CleanedInput(allowed, exceededLimit = false)
        val cutAt = allowed.offsetByCodePoints(0, max)
        return CleanedInput(allowed.substring(0, cutAt), exceededLimit = true)
    }

    /** The value sent to the server: NFC and trimmed. */
    fun normalizeForSubmit(text: String): String = Normalizer.normalize(text, Normalizer.Form.NFC).trim()

    private fun isDisallowed(field: TextInput, char: Char): Boolean =
        Character.isISOControl(char) && !(field.allowsNewline && char == '\n')
}
