package app.banh.customer.ui.common

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.data.flatMap
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

private const val SUBSCRIPTION_GRACE_MILLIS = 5_000L

/**
 * A screen that shows one slice of the catalog. Subclasses only say which slice ([select]); loading,
 * cache and failure states come from the repository, and [retry] reloads only that data.
 */
abstract class CatalogViewModel<T>(
    private val repository: CatalogRepository,
    select: (Catalog) -> Load<T>,
) : ViewModel() {
    val uiState: StateFlow<Load<T>> = repository.catalog
        .map { it.flatMap(select) }
        // The grace period keeps the state alive across a rotation without a new load.
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(SUBSCRIPTION_GRACE_MILLIS), repository.catalog.value.flatMap(select))

    fun retry() {
        viewModelScope.launch { repository.refresh() }
    }
}
