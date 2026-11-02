package app.banh.admin.photo

import app.banh.admin.owner.Problem

/** Limits of the cake picture (ADR-0025, api/07 10.17): at most 5,242,880 bytes, each side 200 to 4096 pixels, JPEG. */
object ImageLimits {
    const val MAX_BYTES = 5_242_880
    const val MIN_SIDE = 200
    const val MAX_SIDE = 4096
    val QUALITIES = listOf(90, 80, 70, 60, 50)
    const val SHRINK = 0.75
}

data class PixelSize(val width: Int, val height: Int) {
    val shortSide: Int get() = minOf(width, height)

    fun scaled(factor: Double) = PixelSize((width * factor).toInt().coerceAtLeast(1), (height * factor).toInt().coerceAtLeast(1))
}

/** The size to decode at: the longest side brought down to 4096 if needed; null when a side would be under 200 (cannot be fixed by the phone). */
fun planSize(source: PixelSize): PixelSize? {
    if (source.shortSide < ImageLimits.MIN_SIDE) return null
    val longest = maxOf(source.width, source.height)
    val fitted = if (longest > ImageLimits.MAX_SIDE) source.scaled(ImageLimits.MAX_SIDE.toDouble() / longest) else source
    return fitted.takeIf { it.shortSide >= ImageLimits.MIN_SIDE }
}

class Encoded(val bytes: ByteArray, val size: PixelSize, val quality: Int)

/**
 * Tries the qualities from best to worst and, when even the worst is too big, a picture 25 percent smaller, until the bytes fit
 * [maxBytes] or a side would drop under 200 pixels. [encode] makes the JPEG for a size and a quality.
 */
fun encodeWithin(start: PixelSize, maxBytes: Int = ImageLimits.MAX_BYTES, encode: (PixelSize, Int) -> ByteArray): Encoded? {
    var size = start
    while (true) {
        for (quality in ImageLimits.QUALITIES) {
            val bytes = encode(size, quality)
            if (bytes.size <= maxBytes) return Encoded(bytes, size, quality)
        }
        size = size.scaled(ImageLimits.SHRINK)
        if (size.shortSide < ImageLimits.MIN_SIDE) return null
    }
}

/** Formats the app accepts from the picker: JPEG, PNG and HEIC (converted to JPEG on the phone, AC-33). */
fun isAcceptedMime(mime: String?): Boolean = mime in setOf("image/jpeg", "image/png", "image/heic", "image/heif")

sealed interface PhotoResult {
    class Ready(val jpeg: ByteArray, val size: PixelSize) : PhotoResult

    data class Rejected(val problem: Problem) : PhotoResult
}

/** Turns what the photo picker returned into a JPEG that the server accepts. [source] is a content or file URI as text. */
fun interface PhotoEncoder {
    suspend fun prepare(source: String): PhotoResult
}
