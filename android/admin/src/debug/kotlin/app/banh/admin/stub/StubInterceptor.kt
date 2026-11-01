package app.banh.admin.stub

import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer

/** Answers every request from [backend] and never touches the network (debug builds only). */
class StubInterceptor(private val backend: StubBackend) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val body = request.body?.let { Buffer().also { buffer -> it.writeTo(buffer) }.readUtf8() }
        val query = request.url.queryParameterNames.associateWith { request.url.queryParameter(it).orEmpty() }
        val stubbed = backend.handle(
            StubRequest(request.method, request.url.encodedPath.trimStart('/'), query, body, request.header("Authorization")?.removePrefix("Bearer ")),
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

class StubRequest(val method: String, val path: String, val query: Map<String, String>, val body: String?, val accessToken: String?)

class StubResponse(val status: Int, val body: String = "", val headers: Map<String, String> = emptyMap())
