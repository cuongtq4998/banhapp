package app.banh.customer.order

import app.banh.customer.data.availability.AvailabilityApi
import app.banh.customer.data.catalog.CatalogRepository
import java.time.Clock

/** What the order flow needs from outside. The app container builds it; tests pass fakes. */
class OrderDependencies(
    val catalog: CatalogRepository,
    val availability: AvailabilityApi,
    val drafts: DraftStore,
    val clock: Clock,
)
