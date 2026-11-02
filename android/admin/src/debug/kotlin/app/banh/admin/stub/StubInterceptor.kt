package app.banh.admin.stub

import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer

/** Answers every request from [backend] and never touches the network (debug builds only). */
class StubInterceptor(private val backend: StubBackend) : Interceptor {
    // Every picture of the stub is the same small PNG; the screens only need something to draw.
    private fun picture(request: okhttp3.Request): Response = Response.Builder()
        .request(request).protocol(Protocol.HTTP_1_1).code(200).message("stub")
        .body(StubPictures.png().toResponseBody("image/png".toMediaType())).build()

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val bytes = request.body?.let { Buffer().also { buffer -> it.writeTo(buffer) }.readByteArray() }
        val body = bytes?.toString(Charsets.UTF_8)
        // "slow" in an upload keeps the answer back, so a test can stop the upload (S-A8 `A_CANCEL_UPLOAD`).
        if (body?.contains("slow", ignoreCase = true) == true && request.url.encodedPath.endsWith("/cakes")) Thread.sleep(SLOW_MILLIS)
        if (request.url.encodedPath.startsWith("/assets/")) return picture(request)
        val query = request.url.queryParameterNames.associateWith { request.url.queryParameter(it).orEmpty() }
        val stubbed = backend.handle(
            StubRequest(request.method, request.url.encodedPath.trimStart('/'), query, body, request.header("Authorization")?.removePrefix("Bearer "), bytes),
        )
        return Response.Builder()
            .request(request)
            .protocol(Protocol.HTTP_1_1)
            .code(stubbed.status)
            .message("stub")
            .apply { stubbed.headers.forEach { (name, value) -> header(name, value) } }
            .body(stubbed.body.toResponseBody("application/json; charset=utf-8".toMediaType()))
            .build()
    }
}

class StubRequest(val method: String, val path: String, val query: Map<String, String>, val body: String?, val accessToken: String?, val bytes: ByteArray? = null)

class StubResponse(val status: Int, val body: String = "", val headers: Map<String, String> = emptyMap())

private const val SLOW_MILLIS = 2_500L
