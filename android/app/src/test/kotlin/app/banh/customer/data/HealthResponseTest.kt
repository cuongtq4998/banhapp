package app.banh.customer.data

import java.io.File
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

/** Decodes the shared contract fixtures, so a drift from the backend contract fails here. */
class HealthResponseTest {
    private fun fixture(name: String): String {
        val dir = checkNotNull(System.getProperty("contracts.fixtures.dir")) {
            "contracts.fixtures.dir is set by app/build.gradle.kts"
        }
        return File(dir, name).readText()
    }

    @Test
    fun decodesHealthyFixture() {
        val body = Json.decodeFromString<HealthResponse>(fixture("healthz-ok.json"))
        assertEquals(HealthResponse.Status.OK, body.status)
    }

    @Test
    fun decodesDegradedFixture() {
        val body = Json.decodeFromString<HealthResponse>(fixture("healthz-degraded.json"))
        assertEquals(HealthResponse.Status.DEGRADED, body.status)
    }
}
