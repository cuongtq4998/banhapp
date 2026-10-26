package app.banh.customer.ui.home

import app.banh.customer.data.Load
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.ui.common.CatalogViewModel

/** S-2: shop name, greeting, contacts, and whether an order can start. */
class HomeViewModel(repository: CatalogRepository) :
    CatalogViewModel<HomeContent>(repository, { Load.Ready(it.toHomeContent()) })
