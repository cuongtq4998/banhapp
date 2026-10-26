package app.banh.customer.ui.common

private const val THOUSANDS_SEPARATOR = "."
private const val DIGITS_PER_GROUP = 3

/** Whole dong with a dot as thousands separator and no decimals (design system principle 4): 125000 becomes "125.000". */
fun groupThousands(amountVnd: Long): String {
    require(amountVnd >= 0) { "A price is never negative" }
    return amountVnd.toString().reversed().chunked(DIGITS_PER_GROUP).joinToString(THOUSANDS_SEPARATOR).reversed()
}
