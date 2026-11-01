package app.banh.admin.owner

import okhttp3.MediaType
import okhttp3.RequestBody
import okio.Buffer
import okio.BufferedSink
import okio.ForwardingSink
import okio.buffer

private const val PERCENT = 100L

/** Reports how much of [delegate] has been written, as 0 to 100 (S-A8 `A_UPLOADING`). */
class ProgressBody(private val delegate: RequestBody, private val onProgress: (Int) -> Unit) : RequestBody() {
    override fun contentType(): MediaType? = delegate.contentType()

    override fun contentLength(): Long = delegate.contentLength()

    override fun writeTo(sink: BufferedSink) {
        val total = contentLength().coerceAtLeast(1)
        var written = 0L
        val counting = object : ForwardingSink(sink) {
            override fun write(source: Buffer, byteCount: Long) {
                super.write(source, byteCount)
                written += byteCount
                onProgress((written * PERCENT / total).toInt().coerceIn(0, PERCENT.toInt()))
            }
        }.buffer()
        delegate.writeTo(counting)
        counting.flush()
    }
}
