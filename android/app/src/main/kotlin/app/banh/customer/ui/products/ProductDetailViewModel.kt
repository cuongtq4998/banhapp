package app.banh.customer.ui.products

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.catalog.Product
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.runningFold
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

private const val SUBSCRIPTION_GRACE_MILLIS = 5_000L

/** One cake on S-4, and whether the shop still sells it. */
data class ProductDetail(val product: Product, val available: Boolean)

/**
 * S-4: one cake. When the shop hides it while the screen is open, the state keeps the cake it showed and turns
 * [ProductDetail.available] off (Gone), so the picture and text stay visible. Own class instead of
 * `CatalogViewModel` because that one selects from each catalog alone, and Gone needs the previous state.
 */
class ProductDetailViewModel(
    private val repository: CatalogRepository,
    private val productId: String,
) : ViewModel() {
    val uiState: StateFlow<Load<ProductDetail>> = run {
        val seed = detailOf(repository.catalog.value, productId, previous = Load.Loading)
        repository.catalog
            .runningFold(seed) { previous, catalog -> detailOf(catalog, productId, previous) }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_GRACE_MILLIS), seed)
    }

    fun retry() {
        viewModelScope.launch { repository.refresh() }
    }

    /**
     * Rechecks the active list before an order starts from this cake (UI document 5.4): the shop may have hidden it
     * since the last refresh. A refresh that fails keeps the last answer, so a customer who is offline can still go on.
     */
    suspend fun isStillOrderable(): Boolean {
        repository.refresh()
        val detail = detailOf(repository.catalog.value, productId, uiState.value)
        return (detail as? Load.Ready)?.value?.available == true
    }
}

internal fun detailOf(catalog: Load<Catalog>, productId: String, previous: Load<ProductDetail>): Load<ProductDetail> =
    when (catalog) {
        Load.Loading -> Load.Loading
        is Load.Failed -> catalog
        is Load.Ready -> {
            val current = catalog.value.products.firstOrNull { it.id == productId }
            val lastShown = (previous as? Load.Ready)?.value?.product
            when {
                current != null -> Load.Ready(ProductDetail(current, available = true))
                lastShown != null -> Load.Ready(ProductDetail(lastShown, available = false))
                // Nothing was ever shown for this id, so there is nothing to dim.
                else -> Load.Failed(LoadFailure.OTHER)
            }
        }
    }
