package app.banh.customer.data.availability

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Body of `GET /v1/availability?cakes=N` (docs/system/api.md 4.2). */
@Serializable
data class Availability(
    /** Today in shop time; the calendar starts here, never at the device date (A-1). */
    @SerialName("server_date") val serverDate: String,
    /** One entry for each date from [serverDate] to the end of the booking horizon, inclusive. */
    val dates: List<AvailableDate>,
)

@Serializable
data class AvailableDate(
    /** ISO date `yyyy-MM-dd`. */
    val date: String,
    val available: Boolean,
    /** `TOO_SOON`, `TOO_FAR`, `FULL`, or null when [available]. Read through [unavailableReason]. */
    val reason: String? = null,
) {
    val unavailableReason: UnavailableReason?
        get() = if (available) null else UnavailableReason.fromWire(reason)
}

/** Why a date cannot be chosen (api.md 4.2). The remaining amount itself is never sent (UI document 5.6). */
enum class UnavailableReason {
    TOO_SOON,
    TOO_FAR,
    FULL,
    ;

    companion object {
        /** A reason added by a later server is treated as full: the date stays unselectable, which is the safe side. */
        fun fromWire(reason: String?): UnavailableReason = entries.firstOrNull { it.name == reason } ?: FULL
    }
}
