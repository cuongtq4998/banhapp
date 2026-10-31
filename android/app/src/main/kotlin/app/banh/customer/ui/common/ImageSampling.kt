package app.banh.customer.ui.common

/** Largest power of two that keeps the decoded width at or above [targetWidth]; a picture is never decoded larger than needed. */
internal fun sampleSizeFor(sourceWidth: Int, targetWidth: Int): Int {
    if (sourceWidth <= 0 || targetWidth <= 0) return 1
    var sampleSize = 1
    while (sourceWidth / (sampleSize * 2) >= targetWidth) sampleSize *= 2
    return sampleSize
}
