package app.banh.customer.data.availability

import app.banh.customer.data.network.ApiException

/** Edge to the availability endpoint; the order flow and its tests depend on this, not on OkHttp. */
interface AvailabilityApi {
    /**
     * Dates of the booking horizon with their state for an order of [cakes] cakes in total.
     * @throws ApiException on every failure.
     */
    suspend fun fetchAvailability(cakes: Int): Availability
}
