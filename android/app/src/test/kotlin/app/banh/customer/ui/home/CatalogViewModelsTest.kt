package app.banh.customer.ui.home

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.testing.FakeCatalogRepository
import app.banh.customer.testing.MainDispatcherRule
import app.banh.customer.testing.TestCatalogs
import app.banh.customer.data.catalog.Product
import app.banh.customer.ui.products.ProductDetail
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

        assertEquals(Load.Ready(HomeContent(catalog.shop, hasActiveCakes = true)), viewModel.uiState.value)
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

        assertEquals(listOf(Load.Loading, Load.Ready(HomeContent(catalog.shop, hasActiveCakes = true)), Load.Failed(LoadFailure.NETWORK)), seen)
    }

    @Test
    fun homeKnowsWhenTheShopHasNoActiveCake() {
        val empty = TestCatalogs.catalog(productCount = 0)
        val viewModel = HomeViewModel(FakeCatalogRepository(Load.Ready(empty)))

        assertEquals(Load.Ready(HomeContent(empty.shop, hasActiveCakes = false)), viewModel.uiState.value)
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
    fun noCakeAtAllIsAnEmptyAnswerNotAFailedLoad() {
        val viewModel = ProductsViewModel(FakeCatalogRepository(Load.Ready(TestCatalogs.catalog(productCount = 0))))

        assertEquals(Load.Ready(emptyList<Product>()), viewModel.uiState.value)
    }

    @Test
    fun productsKeepTheNetworkFailureOfTheRepository() {
        val viewModel = ProductsViewModel(FakeCatalogRepository(Load.Failed(LoadFailure.NETWORK)))

        assertEquals(Load.Failed(LoadFailure.NETWORK), viewModel.uiState.value)
    }

    @Test
    fun detailShowsTheRequestedCake() {
        val viewModel = ProductDetailViewModel(FakeCatalogRepository(Load.Ready(catalog)), productId = "product-2")

        assertEquals(Load.Ready(ProductDetail(catalog.products[1], available = true)), viewModel.uiState.value)
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

    @Test
    fun detailTurnsGoneWhenTheShopHidesTheCakeAndKeepsItsData() = runTest {
        val repository = FakeCatalogRepository(Load.Ready(catalog))
        val viewModel = ProductDetailViewModel(repository, productId = "product-2")
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect {} }

        repository.emit(Load.Ready(TestCatalogs.catalog(productCount = 1)))

        assertEquals(Load.Ready(ProductDetail(catalog.products[1], available = false)), viewModel.uiState.value)
    }

    @Test
    fun detailIsAvailableAgainWhenTheCakeComesBack() = runTest {
        val repository = FakeCatalogRepository(Load.Ready(catalog))
        val viewModel = ProductDetailViewModel(repository, productId = "product-2")
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect {} }

        repository.emit(Load.Ready(TestCatalogs.catalog(productCount = 1)))
        repository.emit(Load.Ready(catalog))

        assertEquals(Load.Ready(ProductDetail(catalog.products[1], available = true)), viewModel.uiState.value)
    }

    @Test
    fun orderRechecksTheActiveListAfterARefresh() = runTest {
        val repository = FakeCatalogRepository(Load.Ready(catalog))
        repository.onRefresh = { repository.emit(Load.Ready(TestCatalogs.catalog(productCount = 1))) }
        val viewModel = ProductDetailViewModel(repository, productId = "product-2")

        assertEquals(false, viewModel.isStillOrderable())
        assertEquals(1, repository.refreshCount)
    }

    @Test
    fun orderGoesOnWhenTheCakeIsStillActive() = runTest {
        val viewModel = ProductDetailViewModel(FakeCatalogRepository(Load.Ready(catalog)), productId = "product-2")

        assertEquals(true, viewModel.isStillOrderable())
    }
}
