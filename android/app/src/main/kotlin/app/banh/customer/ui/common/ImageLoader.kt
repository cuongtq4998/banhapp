package app.banh.customer.ui.common

import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import app.banh.customer.data.network.await
import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/** Edge for product pictures, so screens do not depend on the HTTP stack. */
interface ImageLoader {
    /** Loads the picture at [path] (a path on the API host) scaled to about [maxWidthPx]; null when it cannot be shown. */
    suspend fun load(path: String, maxWidthPx: Int): ImageBitmap?
}

class OkHttpImageLoader(
    private val client: OkHttpClient,
    private val baseUrl: HttpUrl,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val decodeDispatcher: CoroutineDispatcher = Dispatchers.Default,
) : ImageLoader {
    override suspend fun load(path: String, maxWidthPx: Int): ImageBitmap? {
        val url = baseUrl.resolve(path) ?: return null
        val bytes = fetchBytes(url) ?: return null
        return withContext(decodeDispatcher) { decodeScaled(bytes, maxWidthPx) }
    }

    private suspend fun fetchBytes(url: HttpUrl): ByteArray? = try {
        val response = client.newCall(Request.Builder().url(url).build()).await()
        withContext(ioDispatcher) { response.use { if (it.isSuccessful) it.body.bytes() else null } }
    } catch (e: IOException) {
        null
    }

    private fun decodeScaled(bytes: ByteArray, maxWidthPx: Int): ImageBitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val options = BitmapFactory.Options().apply { inSampleSize = sampleSizeFor(bounds.outWidth, maxWidthPx) }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)?.asImageBitmap()
    }
}
