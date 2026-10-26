package app.banh.customer.ui.home

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.testing.FakeCatalogRepository
import app.banh.customer.testing.MainDispatcherRule
import app.banh.customer.testing.TestCatalogs
import app.banh.customer.ui.products.ProductDetailViewModel
import app.banh.customer.ui.products.ProductsViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** The three catalog screens differ only in which slice they select, so their view models are tested together. */
@OptIn(ExperimentalCoroutinesApi::class)
class CatalogViewModelsTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val catalog = TestCatalogs.catalog()

    @Test
    fun homeShowsTheShopOfTheCatalog() {
        val viewModel = HomeViewModel(FakeCatalogRepository(Load.Ready(catalog)))

        assertEquals(Load.Ready(catalog.shop), viewModel.uiState.value)
    }

    @Test
    fun homeFollowsTheRepositoryThroughLoadingReadyAndFailure() = runTest {
        val repository = FakeCatalogRepository()
        val viewModel = HomeViewModel(repository)
        val seen = mutableListOf<Load<*>>()
        // Unconfined so that no state is conflated away between two emits.
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.toList(seen) }

        repository.emit(Load.Ready(catalog))
        repository.emit(Load.Failed(LoadFailure.NETWORK))

        assertEquals(listOf(Load.Loading, Load.Ready(catalog.shop), Load.Failed(LoadFailure.NETWORK)), seen)
    }

    @Test
    fun retryAsksTheRepositoryToRefresh() {
        val repository = FakeCatalogRepository(Load.Failed(LoadFailure.OTHER))

        HomeViewModel(repository).retry()

        assertEquals(1, repository.refreshCount)
    }

    @Test
    fun productsShowEveryCake() {
        val viewModel = ProductsViewModel(FakeCatalogRepository(Load.Ready(catalog)))

        assertEquals(Load.Ready(catalog.products), viewModel.uiState.value)
    }

    @Test
    fun fewerThanFourCakesAreShownAsTheyAre() {
        val three = TestCatalogs.catalog(productCount = 3)
        val viewModel = ProductsViewModel(FakeCatalogRepository(Load.Ready(three)))

        assertEquals(Load.Ready(three.products), viewModel.uiState.value)
    }

    @Test
    fun noCakeAtAllIsAFailedLoad() {
        val viewModel = ProductsViewModel(FakeCatalogRepository(Load.Ready(TestCatalogs.catalog(productCount = 0))))

        assertEquals(Load.Failed(LoadFailure.OTHER), viewModel.uiState.value)
    }

    @Test
    fun productsKeepTheNetworkFailureOfTheRepository() {
        val viewModel = ProductsViewModel(FakeCatalogRepository(Load.Failed(LoadFailure.NETWORK)))

        assertEquals(Load.Failed(LoadFailure.NETWORK), viewModel.uiState.value)
    }

    @Test
    fun detailShowsTheRequestedCake() {
        val viewModel = ProductDetailViewModel(FakeCatalogRepository(Load.Ready(catalog)), productId = "product-2")

        assertEquals(Load.Ready(catalog.products[1]), viewModel.uiState.value)
    }

    @Test
    fun detailOfAnUnknownCakeIsAFailedLoad() {
        val viewModel = ProductDetailViewModel(FakeCatalogRepository(Load.Ready(catalog)), productId = "missing")

        assertEquals(Load.Failed(LoadFailure.OTHER), viewModel.uiState.value)
    }

    @Test
    fun detailIsLoadingWhileTheCatalogIs() {
        val viewModel = ProductDetailViewModel(FakeCatalogRepository(), productId = "product-1")

        assertEquals(Load.Loading, viewModel.uiState.value)
    }
}
