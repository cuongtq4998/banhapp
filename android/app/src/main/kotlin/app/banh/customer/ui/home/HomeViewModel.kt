package app.banh.customer.ui.home

import app.banh.customer.data.Load
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.Shop
import app.banh.customer.ui.common.CatalogViewModel

/** S-2: shop name, greeting and contacts. */
class HomeViewModel(repository: CatalogRepository) :
    CatalogViewModel<Shop>(repository, { Load.Ready(it.shop) })
