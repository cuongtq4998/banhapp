package app.banh.admin.photo

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.ExifInterface
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.owner.Problem
import java.io.File
import java.util.Random
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The re-encode of ADR-0025 on a real device: JPEG, at most 5,242,880 bytes, each side 200 to 4096 pixels. */
class PhotoEncoderTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val encoder = AndroidPhotoEncoder(context)

    private fun file(name: String) = File(context.cacheDir, name)

    private fun save(name: String, bitmap: Bitmap, format: Bitmap.CompressFormat, quality: Int = 100): String {
        file(name).outputStream().use { bitmap.compress(format, quality, it) }
        return "file://${file(name).absolutePath}"
    }

    private fun solid(width: Int, height: Int, color: Int, alpha: Boolean = false) =
        Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply { setHasAlpha(alpha); eraseColor(color) }

    private fun noise(width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val random = Random(1)
        val row = IntArray(width)
        for (y in 0 until height) {
            for (x in 0 until width) row[x] = Color.rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256))
            bitmap.setPixels(row, 0, width, 0, y, width, 1)
        }
        return bitmap
    }

    private fun ready(result: PhotoResult): PhotoResult.Ready = result as? PhotoResult.Ready ?: error("expected a picture, got $result")

    private fun bounds(bytes: ByteArray) = BitmapFactory.Options().apply { inJustDecodeBounds = true }.also { BitmapFactory.decodeByteArray(bytes, 0, bytes.size, it) }

    @Test
    fun aHugeNoisyPhotoIsShrunkUnderTheByteLimitAndTheSideLimit() = runBlocking {
        val uri = save("huge.jpg", noise(4800, 3200), Bitmap.CompressFormat.JPEG)
        assertTrue("the source is bigger than the limit", file("huge.jpg").length() > 5_242_880)
        val result = ready(encoder.prepare(uri))
        val o = bounds(result.jpeg)
        assertTrue(result.jpeg.size <= 5_242_880)
        assertEquals("image/jpeg", o.outMimeType)
        assertTrue(o.outWidth in 200..4096 && o.outHeight in 200..4096)
    }

    @Test
    fun aPngWithTransparencyBecomesAJpegOnWhite() = runBlocking {
        val uri = save("alpha.png", solid(800, 600, Color.TRANSPARENT, alpha = true), Bitmap.CompressFormat.PNG)
        val result = ready(encoder.prepare(uri))
        val o = bounds(result.jpeg)
        assertEquals("image/jpeg", o.outMimeType)
        assertEquals(800, o.outWidth)
        val pixel = BitmapFactory.decodeByteArray(result.jpeg, 0, result.jpeg.size).getPixel(10, 10)
        assertTrue(Color.red(pixel) > 240 && Color.green(pixel) > 240 && Color.blue(pixel) > 240)
    }

    @Test
    fun aPictureTurnedByExifIsStoredUpright() = runBlocking {
        val uri = save("turned.jpg", solid(800, 400, Color.GRAY), Bitmap.CompressFormat.JPEG)
        @Suppress("DEPRECATION")
        ExifInterface(file("turned.jpg").absolutePath).apply { setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_ROTATE_90.toString()); saveAttributes() }
        val o = bounds(ready(encoder.prepare(uri)).jpeg)
        assertEquals(400, o.outWidth)
        assertEquals(800, o.outHeight)
    }

    @Test
    fun aSideUnder200PixelsIsRejectedAsUnreadable() = runBlocking {
        val uri = save("small.png", solid(150, 300, Color.RED), Bitmap.CompressFormat.PNG)
        assertEquals(PhotoResult.Rejected(Problem.ImageRead), encoder.prepare(uri))
    }

    @Test
    fun aFormatOtherThanJpegPngOrHeicIsRejectedAsTheWrongType() = runBlocking {
        val uri = save("pic.webp", solid(400, 400, Color.BLUE), Bitmap.CompressFormat.WEBP_LOSSY, 90)
        assertEquals(PhotoResult.Rejected(Problem.ImageType), encoder.prepare(uri))
    }

    @Test
    fun aTextFileIsRejectedAsUnreadable() = runBlocking {
        file("fake.jpg").writeText("this is not a picture")
        assertEquals(PhotoResult.Rejected(Problem.ImageRead), encoder.prepare("file://${file("fake.jpg").absolutePath}"))
    }
}
