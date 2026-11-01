package app.banh.admin.photo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ImageFitTest {
    @Test
    fun aPictureInsideTheRangeKeepsItsSize() = assertEquals(PixelSize(1200, 800), planSize(PixelSize(1200, 800)))

    @Test
    fun theLongestSideIsBroughtDownTo4096() = assertEquals(PixelSize(4096, 3072), planSize(PixelSize(8192, 6144)))

    @Test
    fun aSideUnder200CannotBeFixedByThePhone() {
        assertNull(planSize(PixelSize(150, 900)))
        assertNull(planSize(PixelSize(199, 199)))
        // 20000 x 300 would shrink to 4096 x 61: also refused.
        assertNull(planSize(PixelSize(20000, 300)))
    }

    @Test
    fun theFirstQualityThatFitsWins() {
        val encoded = encodeWithin(PixelSize(1000, 1000), maxBytes = 100) { _, quality -> ByteArray(if (quality >= 80) 200 else 90) }
        assertEquals(70, encoded?.quality)
        assertEquals(PixelSize(1000, 1000), encoded?.size)
    }

    @Test
    fun whenEvenTheWorstQualityIsTooBigThePictureShrinksBy25Percent() {
        val seen = mutableListOf<PixelSize>()
        val encoded = encodeWithin(PixelSize(1000, 800), maxBytes = 1000) { size, _ -> seen += size; ByteArray(if (size.width <= 750) 500 else 2000) }
        assertEquals(PixelSize(750, 600), encoded?.size)
        assertEquals(90, encoded?.quality)
        assertEquals(6, seen.size)
    }

    @Test
    fun theResultNeverExceedsTheLimitOrGoesUnder200Pixels() {
        val limit = ImageLimits.MAX_BYTES
        val encoded = encodeWithin(PixelSize(4096, 3000)) { size, quality -> ByteArray((size.width.toLong() * size.height * quality / 800).toInt()) }!!
        assertTrue(encoded.bytes.size <= limit)
        assertTrue(encoded.size.shortSide >= ImageLimits.MIN_SIDE && maxOf(encoded.size.width, encoded.size.height) <= ImageLimits.MAX_SIDE)
    }

    @Test
    fun aPictureThatNeverFitsIsGivenUp() = assertNull(encodeWithin(PixelSize(400, 400), maxBytes = 10) { _, _ -> ByteArray(100) })

    @Test
    fun onlyJpegPngAndHeicAreAccepted() {
        listOf("image/jpeg", "image/png", "image/heic", "image/heif").forEach { assertTrue(it, isAcceptedMime(it)) }
        listOf("image/webp", "image/gif", "text/plain", null).forEach { assertFalse(it.toString(), isAcceptedMime(it)) }
    }
}
