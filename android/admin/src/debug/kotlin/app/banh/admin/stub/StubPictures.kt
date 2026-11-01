package app.banh.admin.stub

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import java.io.ByteArrayOutputStream

/** Pictures made in code for the stub and the tests: nothing binary is stored in the repository. */
object StubPictures {
    fun png(): ByteArray = encode(Bitmap.CompressFormat.PNG, SMALL, SMALL, Color.rgb(0xE8, 0xC1, 0x7A))

    /** A JPEG of the given size with a gradient, so it does not compress to nothing. */
    fun jpeg(width: Int, height: Int): ByteArray = encode(Bitmap.CompressFormat.JPEG, width, height, Color.rgb(0x6B, 0x8E, 0x4E))

    fun encode(format: Bitmap.CompressFormat, width: Int, height: Int, color: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(color)
        val paint = Paint().apply { this.color = Color.WHITE }
        for (i in 0 until STRIPES) canvas.drawRect(0f, i * height / STRIPES.toFloat(), width * i / STRIPES.toFloat(), (i + 1) * height / STRIPES.toFloat(), paint)
        return ByteArrayOutputStream().also { bitmap.compress(format, JPEG_QUALITY, it) }.toByteArray()
    }

    private const val SMALL = 120
    private const val STRIPES = 16
    private const val JPEG_QUALITY = 95
}
