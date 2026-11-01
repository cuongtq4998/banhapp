package app.banh.admin.photo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import app.banh.admin.owner.Problem
import java.io.ByteArrayOutputStream
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Reads the picked picture, applies its rotation (the JPEG made here has no EXIF), flattens transparency onto white, scales it into the
 * 200 to 4096 pixel range and compresses it within 5,242,880 bytes ([encodeWithin]). Anything else is a [Problem] for the form.
 */
class AndroidPhotoEncoder(private val context: Context) : PhotoEncoder {
    override suspend fun prepare(source: String): PhotoResult = withContext(Dispatchers.Default) {
        try {
            run(Uri.parse(source))
        } catch (_: IOException) {
            PhotoResult.Rejected(Problem.ImageRead)
        } catch (_: OutOfMemoryError) {
            PhotoResult.Rejected(Problem.ImageRead)
        } catch (_: SecurityException) {
            PhotoResult.Rejected(Problem.ImageRead)
        }
    }

    private fun run(uri: Uri): PhotoResult {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(uri).use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outMimeType == null) return PhotoResult.Rejected(Problem.ImageRead)
        if (!isAcceptedMime(bounds.outMimeType)) return PhotoResult.Rejected(Problem.ImageType)
        val rotation = if (bounds.outMimeType == "image/jpeg") rotationOf(uri) else 0
        val swapped = rotation == 90 || rotation == 270
        val upright = if (swapped) PixelSize(bounds.outHeight, bounds.outWidth) else PixelSize(bounds.outWidth, bounds.outHeight)
        val target = planSize(upright) ?: return PhotoResult.Rejected(Problem.ImageRead)

        val decoded = decode(uri, bounds, maxOf(target.width, target.height).toFloat() / maxOf(upright.width, upright.height))
            ?: return PhotoResult.Rejected(Problem.ImageRead)
        // A JPEG without rotation is used as it is; copying a 12 megapixel picture again would double the memory for nothing.
        val base = if (rotation == 0 && !decoded.hasAlpha()) decoded else flatten(decoded, rotation)
        val encoded = encodeWithin(target) { size, quality -> compress(base, size, quality) }
        return if (encoded == null) PhotoResult.Rejected(Problem.ImageSize) else PhotoResult.Ready(encoded.bytes, encoded.size)
    }

    private fun decode(uri: Uri, bounds: BitmapFactory.Options, ratio: Float): Bitmap? {
        var sample = 1
        while (sample * 2 <= 1f / ratio && sample < MAX_SAMPLE) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return open(uri).use { BitmapFactory.decodeStream(it, null, options) }
    }

    /** White background (JPEG has no alpha) and upright orientation, in one draw. */
    private fun flatten(source: Bitmap, rotation: Int): Bitmap {
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        val turned = if (rotation == 0) source else Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        val out = Bitmap.createBitmap(turned.width, turned.height, Bitmap.Config.ARGB_8888)
        Canvas(out).apply { drawColor(Color.WHITE); drawBitmap(turned, 0f, 0f, null) }
        return out
    }

    private fun compress(base: Bitmap, size: PixelSize, quality: Int): ByteArray {
        val bitmap = if (size.width == base.width && size.height == base.height) base else Bitmap.createScaledBitmap(base, size.width, size.height, true)
        return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, quality, it) }.toByteArray()
    }

    @Suppress("DEPRECATION")
    private fun rotationOf(uri: Uri): Int = try {
        open(uri).use {
            when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        }
    } catch (_: IOException) {
        0
    }

    private fun open(uri: Uri) = context.contentResolver.openInputStream(uri) ?: throw IOException("cannot open")

    private companion object {
        const val MAX_SAMPLE = 16
    }
}
