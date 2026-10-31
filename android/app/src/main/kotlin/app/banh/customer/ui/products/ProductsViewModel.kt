package app.banh.customer.ui.products

import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.Product
import app.banh.customer.ui.common.CatalogViewModel

/**
 * S-3: every active cake. An empty list is a successful answer, not a failed load: the screen shows its own
 * zero-cake state for it (BR-13), apart from the failure state of an answer that never came.
 */
class ProductsViewModel(repository: CatalogRepository) :
    CatalogViewModel<List<Product>>(repository, ::selectProducts)

internal fun selectProducts(catalog: Catalog): Load<List<Product>> = Load.Ready(catalog.products)
