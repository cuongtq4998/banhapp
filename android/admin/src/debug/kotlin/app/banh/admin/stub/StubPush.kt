package app.banh.admin.stub

import android.content.Context
import androidx.compose.runtime.Composable
import app.banh.admin.photo.PhotoChooser
import app.banh.admin.push.TokenProvider
import java.io.File

/** Stands in for Firebase in the stub backend: a fixed token, so the whole push path (permission, registration, forget) can be tested. */
object StubTokenProvider : TokenProvider {
    override val available = true

    @Volatile
    var forgotten = 0

    override suspend fun token(): String = "stub-token-1"

    override suspend fun forget() {
        forgotten += 1
    }
}

/**
 * A "photo picker" that needs no person: it returns the picture named in the file `stub-photo.txt` of the cache folder (a URI as text), or a
 * 600 x 400 JPEG made in code. Tests write that file to try other pictures (a PNG, a huge JPEG, text pretending to be a picture).
 */
class StubPhotoChooser(private val context: Context) : PhotoChooser {
    @Composable
    override fun rememberPicker(onPicked: (String?) -> Unit): () -> Unit = { onPicked(choice()) }

    private fun choice(): String {
        val marker = File(context.cacheDir, MARKER)
        if (marker.exists()) return marker.readText().trim()
        val file = File(context.cacheDir, DEFAULT_PHOTO).also { it.writeBytes(StubPictures.jpeg(600, 400)) }
        return "file://${file.absolutePath}"
    }

    companion object {
        const val MARKER = "stub-photo.txt"
        const val DEFAULT_PHOTO = "stub-photo.jpg"
    }
}
