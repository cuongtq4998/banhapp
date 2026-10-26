package app.banh.customer.ui.products

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.Product
import app.banh.customer.ui.common.CatalogViewModel

/** S-3: every active cake. An empty list is a failed load; any other count is shown as it is. */
class ProductsViewModel(repository: CatalogRepository) :
    CatalogViewModel<List<Product>>(repository, ::selectProducts)

internal fun selectProducts(catalog: Catalog): Load<List<Product>> =
    if (catalog.products.isNotEmpty()) Load.Ready(catalog.products) else Load.Failed(LoadFailure.OTHER)
