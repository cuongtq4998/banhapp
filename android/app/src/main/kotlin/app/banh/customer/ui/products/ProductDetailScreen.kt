package app.banh.customer.ui.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Product
import app.banh.customer.design.BanhScreen
import app.banh.customer.design.BottomActionBar
import app.banh.customer.design.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.InlineTopBar
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.Radii
import app.banh.customer.design.SkeletonBlock
import app.banh.customer.design.Spacing
import app.banh.customer.design.bodyStrong
import app.banh.customer.design.loadingSemantics
import app.banh.customer.ui.common.ProductImage
import app.banh.customer.ui.common.catalogLoadFailureText
import app.banh.customer.ui.common.formatMoney
import androidx.compose.foundation.shape.RoundedCornerShape

private const val PICTURE_ASPECT_RATIO = 4f / 3f
private const val SKELETON_TEXT_FRACTION = 0.6f

@Composable
fun ProductDetailRoute(viewModel: ProductDetailViewModel, onBack: () -> Unit, onOrder: () -> Unit) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    ProductDetailScreen(state, onBack = onBack, onRetry = viewModel::retry, onOrder = onOrder)
}

/** S-4: one cake and the button that starts an order with it. The button is off until the cake is shown. */
@Composable
fun ProductDetailScreen(
    state: Load<Product>,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onOrder: () -> Unit,
) {
    val product = (state as? Load.Ready)?.value
    BanhScreen(
        topBar = { InlineTopBar(title = product?.name.orEmpty(), onBack = onBack) },
        bottomBar = {
            BottomActionBar {
                PrimaryButton(
                    stringResource(R.string.detail_btn_order),
                    onClick = onOrder,
                    enabled = product != null,
                    modifier = Modifier.testTag(TestTags.DETAIL_ORDER),
                )
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(innerPadding)
                .padding(horizontal = Spacing.screenMargin, vertical = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            when (state) {
                is Load.Ready -> ProductContent(state.value)
                Load.Loading -> ProductSkeleton()
                is Load.Failed -> ErrorState(stringResource(catalogLoadFailureText(state.failure)), onRetry)
            }
        }
    }
}

@Composable
private fun ProductContent(product: Product) {
    ProductImage(product.imageUrl, product.name, Modifier.fillMaxWidth().aspectRatio(PICTURE_ASPECT_RATIO))
    GlassCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(
                product.name,
                style = MaterialTheme.typography.headlineLarge,
                modifier = Modifier.testTag(TestTags.DETAIL_NAME).semantics { heading() },
            )
            Text(product.description, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag(TestTags.DETAIL_DESCRIPTION))
            Text(
                stringResource(R.string.price_each, formatMoney(product.priceVnd)),
                style = MaterialTheme.typography.bodyStrong,
                modifier = Modifier.testTag(TestTags.DETAIL_PRICE),
            )
        }
    }
}

@Composable
private fun ProductSkeleton() {
    Column(Modifier.loadingSemantics(), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        SkeletonBlock(Modifier.fillMaxWidth().aspectRatio(PICTURE_ASPECT_RATIO), RoundedCornerShape(Radii.image))
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                SkeletonBlock(Modifier.fillMaxWidth(SKELETON_TEXT_FRACTION).height(Spacing.xxl))
                SkeletonBlock(Modifier.fillMaxWidth().height(Spacing.lg))
                SkeletonBlock(Modifier.fillMaxWidth().height(Spacing.lg))
            }
        }
    }
}
