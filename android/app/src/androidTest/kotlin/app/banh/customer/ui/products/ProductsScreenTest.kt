package app.banh.customer.ui.products

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Product
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.FakeCatalogRepository
import app.banh.customer.testing.FakeImageLoader
import app.banh.customer.testing.hasTestTagPrefix
import app.banh.customer.testing.setBanhContent
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-3 states (UI document 5.3, section 9.1). */
class ProductsScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val products: List<Product> = ContractAssets.catalog().products

    private fun showScreen(
        state: Load<List<Product>>,
        imageLoader: FakeImageLoader = FakeImageLoader(),
        onRetry: () -> Unit = {},
        onOpenProduct: (String) -> Unit = {},
    ) {
        rule.setBanhContent(imageLoader) {
            ProductsScreen(state, onBack = {}, onRetry = onRetry, onOpenProduct = onOpenProduct)
        }
    }

    private fun assertCardCount(expected: Int) {
        rule.onAllNodes(hasTestTagPrefix(TestTags.productCard(""))).assertCountEquals(expected)
    }

    // TC-106, TC-206, AC-4, AC-32: four cakes give four cards.
    @Test
    fun fourCakesShowFourCards() = assertEveryActiveCakeIsListed(count = 4)

    // TC-233, AC-32: three active cakes give three cards, no Error and no placeholder for the hidden one.
    @Test
    fun threeCakesShowThreeCards() = assertEveryActiveCakeIsListed(count = 3)

    // AC-32: two active cakes.
    @Test
    fun twoCakesShowTwoCards() = assertEveryActiveCakeIsListed(count = 2)

    // AC-32: one active cake.
    @Test
    fun oneCakeShowsOneCard() = assertEveryActiveCakeIsListed(count = 1)

    private fun assertEveryActiveCakeIsListed(count: Int) {
        val active = products.take(count)
        showScreen(Load.Ready(active))

        assertCardCount(count)
        active.forEach { rule.onNodeWithTag(TestTags.productCard(it.id)).assertIsDisplayed() }
        rule.onNodeWithTag(TestTags.ERROR_STATE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.EMPTY_STATE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.productCardSkeleton(0)).assertDoesNotExist()
    }

    // TC-206: a tap on a card opens that cake.
    @Test
    fun tappingACardOpensThatCake() {
        var opened: String? = null
        showScreen(Load.Ready(products), onOpenProduct = { opened = it })

        rule.onNodeWithTag(TestTags.productCard(products[1].id)).performClick()

        assertEquals(products[1].id, opened)
    }

    // TC-133, TC-233: Loading without a cache shows skeleton cards and no real card.
    @Test
    fun loadingShowsSkeletonCards() {
        showScreen(Load.Loading)

        rule.onNodeWithTag(TestTags.productCardSkeleton(0)).assertIsDisplayed()
        assertCardCount(0)
    }

    // TC-133, TC-233: a load failure shows the Error state with retry, not the zero-cake state.
    @Test
    fun failedLoadShowsErrorWithRetry() {
        var retries = 0
        showScreen(Load.Failed(LoadFailure.OTHER), onRetry = { retries++ })

        rule.onNodeWithTag(TestTags.ERROR_STATE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.EMPTY_STATE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.STATE_RETRY).performClick()

        assertEquals(1, retries)
    }

    // AC-33, UI 5.3 Empty: zero active cakes show their own state with retry, and no card.
    @Test
    fun zeroCakesShowEmptyStateWithRetryAndNoCard() {
        var retries = 0
        showScreen(Load.Ready(emptyList()), onRetry = { retries++ })

        rule.onNodeWithTag(TestTags.EMPTY_STATE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.STATE_RETRY).assertIsDisplayed().performClick()
        rule.onNodeWithTag(TestTags.ERROR_STATE).assertDoesNotExist()
        assertCardCount(0)
        assertEquals(1, retries)
    }

    // AC-33 through the real view model: after a retry that finds an active cake its card appears, without a restart.
    @Test
    fun retryShowsTheCakeThatBecameActive() {
        val repository = FakeCatalogRepository(Load.Ready(ContractAssets.catalogWithoutCakes()))
        var cakeIsActive = false
        repository.onRefresh = { if (cakeIsActive) repository.emit(Load.Ready(ContractAssets.catalogWithCakes(1))) }
        rule.setBanhContent {
            ProductsRoute(ProductsViewModel(repository), onBack = {}, onOpenProduct = {})
        }
        rule.onNodeWithTag(TestTags.EMPTY_STATE).assertIsDisplayed()

        cakeIsActive = true
        rule.onNodeWithTag(TestTags.STATE_RETRY).performClick()

        rule.onNodeWithTag(TestTags.EMPTY_STATE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.productCard(products.first().id)).assertIsDisplayed()
    }

    // TC-107, TC-207: a picture that cannot be loaded shows the placeholder while the card stays tappable.
    @Test
    fun failedPictureShowsPlaceholderAndKeepsTheCardTappable() {
        var opened: String? = null
        val broken = products.first()
        showScreen(Load.Ready(products), imageLoader = FakeImageLoader(failingPaths = setOf(broken.imageUrl)), onOpenProduct = { opened = it })

        // The card merges its children into one element for the screen reader, so the placeholder is found in the unmerged tree.
        rule.onNodeWithTag(TestTags.DETAIL_IMAGE_FAILED, useUnmergedTree = true).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.productCard(broken.id)).performClick()

        assertEquals(broken.id, opened)
    }
}
