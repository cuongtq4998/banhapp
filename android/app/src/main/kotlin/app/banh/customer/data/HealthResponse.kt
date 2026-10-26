package app.banh.customer.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Body of `GET /healthz` (docs/system/api.md 4.4); mirrors `HealthResponse` in contracts/swift. */
@Serializable
data class HealthResponse(val status: Status) {
    @Serializable
    enum class Status {
        @SerialName("ok")
        OK,

        @SerialName("degraded")
        DEGRADED,
    }
}
