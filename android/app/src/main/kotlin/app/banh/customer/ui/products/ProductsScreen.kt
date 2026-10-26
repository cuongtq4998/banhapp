package app.banh.customer.ui.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Product
import app.banh.customer.design.BanhScreen
import app.banh.customer.design.EmptyState
import app.banh.customer.design.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.LargeTitleTopBar
import app.banh.customer.design.Radii
import app.banh.customer.design.Sizes
import app.banh.customer.design.SkeletonBlock
import app.banh.customer.design.Spacing
import app.banh.customer.design.bodyStrong
import app.banh.customer.design.loadingSemantics
import app.banh.customer.ui.common.ProductImage
import app.banh.customer.ui.common.RefreshWhenResumed
import app.banh.customer.ui.common.catalogLoadFailureText
import app.banh.customer.ui.common.formatMoney

private const val DESCRIPTION_MAX_LINES = 2

// Skeleton cards while loading with no cache; four is the usual catalogue size.
private const val PRODUCT_SKELETON_COUNT = 4

@Composable
fun ProductsRoute(viewModel: ProductsViewModel, onBack: () -> Unit, onOpenProduct: (productId: String) -> Unit) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    RefreshWhenResumed(onRefresh = viewModel::retry)
    ProductsScreen(state, onBack = onBack, onRetry = viewModel::retry, onOpenProduct = onOpenProduct)
}

/** S-3: the cakes. There is no bottom bar; ordering starts from a cake (UI document 5.3). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductsScreen(
    state: Load<List<Product>>,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onOpenProduct: (productId: String) -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
    BanhScreen(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = { LargeTitleTopBar(stringResource(R.string.products_title), onBack, scrollBehavior) },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.testTag(TestTags.PRODUCTS_LIST),
            contentPadding = PaddingValues(
                start = Spacing.screenMargin,
                end = Spacing.screenMargin,
                top = innerPadding.calculateTopPadding() + Spacing.sm,
                bottom = innerPadding.calculateBottomPadding() + Spacing.lg,
            ),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            when (state) {
                is Load.Ready -> if (state.value.isEmpty()) {
                    item { EmptyState(stringResource(R.string.products_empty), onRetry) }
                } else {
                    items(state.value, key = { it.id }) { product ->
                        ProductCard(product, onClick = { onOpenProduct(product.id) })
                    }
                }
                Load.Loading -> items(PRODUCT_SKELETON_COUNT) { index -> ProductCardSkeleton(index) }
                is Load.Failed -> item {
                    ErrorState(stringResource(catalogLoadFailureText(state.failure)), onRetry)
                }
            }
        }
    }
}

@Composable
private fun ProductCard(product: Product, onClick: () -> Unit) {
    GlassCard(Modifier.fillMaxWidth().testTag(TestTags.productCard(product.id)), onClick = onClick) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ProductImage(product.imageUrl, product.name, Modifier.size(Sizes.thumb))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text(product.name, style = MaterialTheme.typography.titleLarge)
                Text(
                    product.description,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = DESCRIPTION_MAX_LINES,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    stringResource(R.string.price_each, formatMoney(product.priceVnd)),
                    style = MaterialTheme.typography.bodyStrong,
                )
            }
        }
    }
}

@Composable
private fun ProductCardSkeleton(index: Int) {
    GlassCard(Modifier.fillMaxWidth().testTag(TestTags.productCardSkeleton(index)).loadingSemantics()) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            SkeletonBlock(Modifier.size(Sizes.thumb), RoundedCornerShape(Radii.image))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                SkeletonBlock(Modifier.fillMaxWidth().height(Spacing.xl))
                SkeletonBlock(Modifier.fillMaxWidth().height(Spacing.lg))
                SkeletonBlock(Modifier.fillMaxWidth(PRICE_SKELETON_FRACTION).height(Spacing.lg))
            }
        }
    }
}

private const val PRICE_SKELETON_FRACTION = 0.4f
