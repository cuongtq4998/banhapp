package app.banh.customer.design

import kotlin.math.pow
import org.junit.Assert.assertTrue
import org.junit.Test

// The design system promises 4.5:1 text contrast on its surfaces (principle 2). This guards the
// token values against edits that break that promise.
class ContrastTest {
    private companion object {
        const val MIN_TEXT_CONTRAST = 4.5
        const val CHANNEL_MASK = 0xFFL
        const val SRGB_LINEAR_THRESHOLD = 0.03928
    }

    private fun channel(argb: Long, shift: Int): Double {
        val c = ((argb shr shift) and CHANNEL_MASK) / 255.0
        return if (c <= SRGB_LINEAR_THRESHOLD) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    private fun luminance(argb: Long) =
        0.2126 * channel(argb, 16) + 0.7152 * channel(argb, 8) + 0.0722 * channel(argb, 0)

    private fun contrast(a: Long, b: Long): Double {
        val (hi, lo) = luminance(a).coerceAtLeast(luminance(b)) to luminance(a).coerceAtMost(luminance(b))
        return (hi + 0.05) / (lo + 0.05)
    }

    private fun assertReadable(foreground: Long, background: Long) {
        val ratio = contrast(foreground, background)
        assertTrue("contrast $ratio below $MIN_TEXT_CONTRAST", ratio >= MIN_TEXT_CONTRAST)
    }

    @Test
    fun primaryTextIsReadableOnBackgroundsAndSurface() {
        listOf(ColorTokens.BACKGROUND_TOP, ColorTokens.BACKGROUND_BOTTOM, ColorTokens.SURFACE_SOLID)
            .forEach { assertReadable(ColorTokens.TEXT_PRIMARY, it) }
    }

    @Test
    fun secondaryTextAndErrorAreReadableOnCream() {
        assertReadable(ColorTokens.TEXT_SECONDARY, ColorTokens.BACKGROUND_BOTTOM)
        assertReadable(ColorTokens.ERROR, ColorTokens.BACKGROUND_BOTTOM)
    }

    @Test
    fun buttonAndContainerTextAreReadable() {
        assertReadable(ColorTokens.ON_PRIMARY, ColorTokens.PRIMARY)
        assertReadable(ColorTokens.ON_PRIMARY_CONTAINER, ColorTokens.PRIMARY_CONTAINER)
    }
}
