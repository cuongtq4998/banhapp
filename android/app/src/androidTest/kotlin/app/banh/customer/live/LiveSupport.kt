package app.banh.customer.live

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import app.banh.customer.BuildConfig
import java.io.File
import java.io.FileOutputStream
import java.util.Properties
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import org.junit.Assume

/**
 * Support for the live operating-flow test (docs/engineering/dev-guide.md, "Live operating flow"): the test talks to a real backend
 * (the build's `API_BASE_URL`, set with `-PapiBaseUrl=...`), never to a stub, and runs only with the instrumentation argument `e2eLive=true`.
 */
object LiveSupport {
    private val arguments get() = InstrumentationRegistry.getArguments()
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val http = OkHttpClient()

    fun assumeLive() = Assume.assumeTrue("e2eLive=true is needed", arguments.getString("e2eLive") == "true")

    fun arg(name: String, default: String): String = arguments.getString(name) ?: default

    /** Customer phone of this run; each run needs its own because the shop allows 5 orders per phone in 24 hours. */
    val phone get() = arg("e2ePhone", "0900001234")

    fun get(path: String): String {
        val url = BuildConfig.API_BASE_URL.trimEnd('/') + path
        // Off the main thread: StrictMode forbids network there.
        val pool = java.util.concurrent.Executors.newSingleThreadExecutor()
        try { return pool.submit<String> { http.newCall(Request.Builder().url(url).build()).execute().use { it.body.string() } }.get() } finally { pool.shutdown() }
    }

    fun getJson(path: String) = JSONObject(get(path))

    fun firstAvailableDate(cakes: Int): String {
        val dates = getJson("/v1/availability?cakes=$cakes").getJSONArray("dates")
        return (0 until dates.length()).map { dates.getJSONObject(it) }.first { it.getBoolean("available") }.getString("date")
    }

    private val directory get() = File(context.getExternalFilesDir(null), "e2e").apply { mkdirs() }

    /** Small key=value file the shell driver reads (`adb shell cat`) to hand the order codes to the admin run. */
    fun saveState(values: Map<String, String>) {
        val file = File(directory, "state.properties")
        val properties = Properties().apply { if (file.exists()) file.inputStream().use(::load) }
        values.forEach { (key, value) -> properties.setProperty(key, value) }
        FileOutputStream(file).use { properties.store(it, null) }
    }

    fun state(key: String): String = Properties().also { p -> File(directory, "state.properties").inputStream().use(p::load) }.getProperty(key) ?: error("no state $key")

    /** Screenshot of the whole screen to `<external files>/e2e/shots/<name>.png`; the driver pulls it. */
    fun shot(name: String) {
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot() ?: return
        val dir = File(directory, "shots").apply { mkdirs() }
        FileOutputStream(File(dir, "$name.png")).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
