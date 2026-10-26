package app.banh.customer.ui.products

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.Product
import app.banh.customer.ui.common.CatalogViewModel

/** S-4: one cake. A product the catalog does not hold is a failed load. */
class ProductDetailViewModel(repository: CatalogRepository, productId: String) :
    CatalogViewModel<Product>(repository, { selectProduct(it, productId) })

internal fun selectProduct(catalog: Catalog, productId: String): Load<Product> =
    catalog.products.firstOrNull { it.id == productId }?.let { Load.Ready(it) } ?: Load.Failed(LoadFailure.OTHER)
