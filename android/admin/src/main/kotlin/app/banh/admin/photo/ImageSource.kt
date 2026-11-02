package app.banh.admin.photo

import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/** Loads a cake picture by its API path (`image_url`); null when it cannot be shown (the screen then shows the placeholder). */
fun interface ImageSource {
    suspend fun load(path: String, maxPx: Int): ImageBitmap?
}

class HttpImageSource(private val http: OkHttpClient, private val baseUrl: HttpUrl) : ImageSource {
    override suspend fun load(path: String, maxPx: Int): ImageBitmap? = withContext(Dispatchers.IO) {
        val url = baseUrl.resolve(path) ?: return@withContext null
        try {
            http.newCall(Request.Builder().url(url).build()).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                val bytes = response.body.bytes()
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                var sample = 1
                while (bounds.outWidth / (sample * 2) >= maxPx) sample *= 2
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })?.asImageBitmap()
            }
        } catch (_: IOException) {
            null
        }
    }
}
