package app.banh.customer.ui.home

import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.Shop

/** What S-2 shows once the catalog is known. */
data class HomeContent(
    val shop: Shop,
    /** False when the shop has no active cake, so ordering cannot start (BR-13, AC-33). */
    val hasActiveCakes: Boolean,
)

fun Catalog.toHomeContent() = HomeContent(shop = shop, hasActiveCakes = products.isNotEmpty())
