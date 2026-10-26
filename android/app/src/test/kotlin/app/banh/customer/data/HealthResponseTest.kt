package app.banh.customer.data

import app.banh.customer.testing.ContractFixtures
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

/** Decodes the shared contract fixtures, so a drift from the backend contract fails here. */
class HealthResponseTest {
    @Test
    fun decodesHealthyFixture() {
        val body = Json.decodeFromString<HealthResponse>(ContractFixtures.read("healthz-ok.json"))
        assertEquals(HealthResponse.Status.OK, body.status)
    }

    @Test
    fun decodesDegradedFixture() {
        val body = Json.decodeFromString<HealthResponse>(ContractFixtures.read("healthz-degraded.json"))
        assertEquals(HealthResponse.Status.DEGRADED, body.status)
    }
}
