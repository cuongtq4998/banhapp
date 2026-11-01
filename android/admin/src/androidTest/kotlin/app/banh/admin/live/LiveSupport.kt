package app.banh.admin.live

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.admin.AdminApplication
import app.banh.admin.BuildConfig
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.Properties
import java.util.UUID
import kotlinx.coroutines.runBlocking
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import org.junit.Assume

/** Answer of a helper request: status code and body text (the helper never throws on a 4xx, the test wants to see it). */
data class Answer(val status: Int, val body: String) {
    fun json() = JSONObject(body)
}

/**
 * Support of the live operating flow (docs/engineering/dev-guide.md, "Live operating flow"): the real backend of the build
 * (`-PadminApiBaseUrl=...`, never the stub), the shop's console mail log read over HTTP, screenshots, and the helper requests the UI
 * cannot do (the system photo picker cannot be driven, so the cake photo goes up by a multipart POST with the owner's token).
 */
object LiveSupport {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val arguments get() = InstrumentationRegistry.getArguments()
    private val http = OkHttpClient.Builder().callTimeout(java.time.Duration.ofSeconds(20)).build()
    private val jsonType = "application/json".toMediaType()
    private val codeLine = Regex("""Mã đăng nhập của bạn là (\d{6})""")

    fun assumeLive() = Assume.assumeTrue("e2eLive=true is needed", arguments.getString("e2eLive") == "true")

    fun arg(name: String, default: String) = arguments.getString(name) ?: default

    private val base get() = BuildConfig.API_BASE_URL.trimEnd('/')

    /** The token of the signed-in app session (the test runs in the app's process), renewed by the app's own session manager. */
    fun appToken(): String {
        val container = (instrumentation.targetContext.applicationContext as AdminApplication).container
        // The app's client reads the body where the coroutine runs, so run it on a thread of its own (StrictMode forbids the main thread).
        return offMain { runBlocking { container.session.authorized { it } } }
    }

    private fun <T> offMain(block: () -> T): T = java.util.concurrent.Executors.newSingleThreadExecutor().let { pool ->
        try { pool.submit<T> { block() }.get() } catch (e: java.util.concurrent.ExecutionException) { throw e.cause ?: e } finally { pool.shutdown() }
    }

    fun call(method: String, path: String, token: String? = null, json: String? = null, body: RequestBody? = null, headers: Map<String, String> = emptyMap()): Answer {
        val builder = Request.Builder().url(base + path).header("X-Platform", "android").header("X-App-Version", "0.1.0")
        token?.let { builder.header("Authorization", "Bearer $it") }
        headers.forEach { (k, v) -> builder.header(k, v) }
        val payload = body ?: json?.toRequestBody(jsonType) ?: if (method == "GET") null else "".toRequestBody()
        return offMain { http.newCall(builder.method(method, payload).build()).execute().use { Answer(it.code, it.body.string()) } }
    }

    // ---- sign-in codes from the console mail log (a loopback log server on the host, reached by the emulator's alias) ----

    fun logText(): String = offMain { http.newCall(Request.Builder().url("http://10.0.2.2:8090/backend-and.log").build()).execute().use { it.body.string() } }

    fun codeCount() = codeLine.findAll(logText()).count()

    /** Waits up to 10 s for a code line after [before] lines and returns the last code. */
    fun codeAfter(before: Int): String {
        val until = System.currentTimeMillis() + 10_000
        while (System.currentTimeMillis() < until) {
            val codes = codeLine.findAll(logText()).map { it.groupValues[1] }.toList()
            if (codes.size > before) return codes.last()
            Thread.sleep(500)
        }
        error("no new sign-in code in the log within 10 s")
    }

    /** A second sign-in of [email] by HTTP, from another installation (so the phone's own session is not replaced). Returns the access token. */
    fun signInByHttp(email: String): Pair<String, String> {
        val before = codeCount()
        val request = call("POST", "/v1/auth/code-requests", json = """{"email":"$email"}""")
        check(request.status == 202) { "code request: ${request.status} ${request.body}" }
        val code = codeAfter(before)
        val session = call("POST", "/v1/auth/sessions", json = """{"email":"$email","code":"$code","installation_id":"${UUID.randomUUID()}","device_name":"E2E helper"}""")
        check(session.status == 201) { "sign-in: ${session.status} ${session.body}" }
        return session.json().getString("access_token") to session.json().getString("refresh_token")
    }

    /** A 600 x 400 JPEG made in code (a flat colour with a lighter block); the shop checks the signature and the size, not the picture. */
    fun jpeg(): ByteArray {
        val bitmap = Bitmap.createBitmap(600, 400, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).apply { drawColor(Color.rgb(240, 150, 60)); drawRect(100f, 80f, 500f, 320f, android.graphics.Paint().apply { color = Color.rgb(255, 220, 160) }) }
        return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }.toByteArray()
    }

    fun createCake(token: String, name: String, price: Int): Answer {
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("name", name).addFormDataPart("description", "Bánh thử nghiệm vận hành").addFormDataPart("price_vnd", price.toString())
            .addFormDataPart("image", "cake.jpg", jpeg().toRequestBody("image/jpeg".toMediaType())).build()
        return call("POST", "/v1/owner/cakes", token, body = body)
    }

    // ---- state shared with the shell driver, and screenshots ----

    private val directory get() = File(instrumentation.targetContext.getExternalFilesDir(null), "e2e").apply { mkdirs() }

    fun saveState(values: Map<String, String>) {
        val file = File(directory, "state.properties")
        val properties = Properties().apply { if (file.exists()) file.inputStream().use(::load) }
        values.forEach { (key, value) -> properties.setProperty(key, value) }
        FileOutputStream(file).use { properties.store(it, null) }
    }

    fun state(key: String): String = arg(key, "").ifEmpty {
        Properties().also { p -> File(directory, "state.properties").takeIf { it.exists() }?.inputStream()?.use(p::load) }.getProperty(key) ?: error("no state $key")
    }

    /** The code of the order the customer run recorded, handed over as an instrumentation argument by the driver. */
    fun note(name: String, text: String) = File(File(directory, "shots").apply { mkdirs() }, "$name.txt").writeText(text)

    fun shot(name: String) {
        val bitmap = instrumentation.uiAutomation.takeScreenshot() ?: return
        val dir = File(directory, "shots").apply { mkdirs() }
        FileOutputStream(File(dir, "$name.png")).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
