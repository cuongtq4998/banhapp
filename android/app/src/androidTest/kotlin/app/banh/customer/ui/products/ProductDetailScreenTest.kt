package app.banh.customer.ui.products

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Product
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.DEFAULT_FONT_SCALE
import app.banh.customer.testing.FakeCatalogRepository
import app.banh.customer.testing.FakeImageLoader
import app.banh.customer.testing.LARGEST_FONT_SCALE
import app.banh.customer.testing.WithFontScale
import app.banh.customer.testing.assertTextNotClipped
import app.banh.customer.testing.setBanhContent
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-4 states (UI document 5.4, section 9.1). */
class ProductDetailScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val product: Product = ContractAssets.catalog().products[1]

    private fun showScreen(
        state: Load<ProductDetail>,
        imageLoader: FakeImageLoader = FakeImageLoader(),
        onBack: () -> Unit = {},
        onRetry: () -> Unit = {},
        onOrder: () -> Unit = {},
        fontScale: Float = DEFAULT_FONT_SCALE,
    ) {
        rule.setBanhContent(imageLoader) {
            WithFontScale(fontScale) { ProductDetailScreen(state, onBack, onRetry, onOrder) }
        }
    }

    // TC-108, TC-208, AC-5: Default shows the cake and an enabled order button that starts the flow.
    @Test
    fun defaultShowsTheCakeAndStartsTheOrder() {
        var started = 0
        showScreen(Load.Ready(ProductDetail(product, available = true)), onOrder = { started++ })

        rule.onNodeWithTag(TestTags.DETAIL_NAME).assertTextEquals(product.name)
        rule.onNodeWithTag(TestTags.DETAIL_DESCRIPTION).assertTextEquals(product.description)
        rule.onNodeWithTag(TestTags.DETAIL_PRICE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.DETAIL_GONE_NOTICE).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.DETAIL_GONE_ACTION).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).assertIsEnabled().performClick()

        assertEquals(1, started)
    }

    // AC-33 area, UI 5.4 Gone: the cake stays in view, the notice and the way back show, the order button is gone.
    @Test
    fun goneShowsNoticeAndWayBackInsteadOfTheOrderButton() {
        var wentBack = 0
        showScreen(Load.Ready(ProductDetail(product, available = false)), onBack = { wentBack++ })

        rule.onNodeWithTag(TestTags.DETAIL_GONE_NOTICE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.DETAIL_NAME).assertTextEquals(product.name)
        rule.onNodeWithTag(TestTags.DETAIL_DESCRIPTION).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.DETAIL_GONE_ACTION).assertIsDisplayed().performClick()

        assertEquals(1, wentBack)
    }

    // UI 5.4 Gone through the real view model: the shop hides the cake while the screen is open.
    @Test
    fun cakeHiddenWhileOpenTurnsTheScreenToGone() {
        val repository = FakeCatalogRepository(Load.Ready(ContractAssets.catalog()))
        rule.setBanhContent {
            ProductDetailRoute(ProductDetailViewModel(repository, product.id), onBack = {}, onOrder = {})
        }
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).assertIsEnabled()

        repository.emit(Load.Ready(ContractAssets.catalogWithCakes(1)))

        rule.onNodeWithTag(TestTags.DETAIL_GONE_NOTICE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).assertDoesNotExist()
    }

    // UI 5.4: the tap on the order button rechecks the active list first, so a hidden cake never starts an order.
    @Test
    fun orderTapOnACakeHiddenSinceTheLastRefreshShowsGoneAndStartsNothing() {
        val repository = FakeCatalogRepository(Load.Ready(ContractAssets.catalog()))
        var shopHidesTheCake = false
        repository.onRefresh = { if (shopHidesTheCake) repository.emit(Load.Ready(ContractAssets.catalogWithCakes(1))) }
        var started = 0
        rule.setBanhContent {
            ProductDetailRoute(ProductDetailViewModel(repository, product.id), onBack = {}, onOrder = { started++ })
        }

        shopHidesTheCake = true
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).performClick()

        rule.onNodeWithTag(TestTags.DETAIL_GONE_NOTICE).assertIsDisplayed()
        assertEquals(0, started)
    }

    // TC-134, TC-234: a picture that cannot be loaded shows the placeholder and the order button stays enabled.
    @Test
    fun failedPictureShowsPlaceholderAndKeepsOrderEnabled() {
        showScreen(
            Load.Ready(ProductDetail(product, available = true)),
            imageLoader = FakeImageLoader(failingPaths = setOf(product.imageUrl)),
        )

        rule.onNodeWithTag(TestTags.DETAIL_IMAGE_FAILED).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).assertIsEnabled()
    }

    // TC-134, TC-234: the cake is not known yet (or not in the list at all): order is off and retry is offered.
    @Test
    fun failedLoadShowsErrorWithRetryAndDisablesOrder() {
        var retries = 0
        showScreen(Load.Failed(LoadFailure.OTHER), onRetry = { retries++ })

        rule.onNodeWithTag(TestTags.ERROR_STATE).assertIsDisplayed()
        rule.onNodeWithTag(TestTags.DETAIL_ORDER).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.STATE_RETRY).performClick()

        assertEquals(1, retries)
    }

    // TC-125 (large text): with the largest system font the cake text and the button label are not cut off.
    @Test
    fun largeFontScaleDoesNotClipTheCakeText() {
        showScreen(Load.Ready(ProductDetail(product, available = true)), fontScale = LARGEST_FONT_SCALE)

        listOf(TestTags.DETAIL_NAME, TestTags.DETAIL_DESCRIPTION, TestTags.DETAIL_PRICE, TestTags.DETAIL_ORDER).forEach {
            rule.onNodeWithTag(it).assertIsDisplayed()
            rule.assertTextNotClipped(it)
        }
    }
}
