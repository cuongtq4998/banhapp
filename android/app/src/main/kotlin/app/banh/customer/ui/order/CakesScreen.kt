package app.banh.customer.ui.order

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Product
import app.banh.customer.design.EmptyState
import app.banh.customer.design.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.InfoMessage
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.Radii
import app.banh.customer.design.Sizes
import app.banh.customer.design.SkeletonBlock
import app.banh.customer.design.Spacing
import app.banh.customer.design.bodyStrong
import app.banh.customer.design.loadingSemantics
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.OrderSummary
import app.banh.customer.ui.common.ProductImage
import app.banh.customer.ui.common.RefreshWhenResumed
import app.banh.customer.ui.common.catalogLoadFailureText
import app.banh.customer.ui.common.formatMoney

private const val SKELETON_ROWS = 2

@Composable
fun CakesRoute(flow: OrderFlowViewModel, onBack: () -> Unit, onNext: () -> Unit) {
    val state by flow.state.collectAsStateWithLifecycle()
    // A cake the shop hid or made active again reaches an open step on return (BR-13, AC-33).
    RefreshWhenResumed(onRefresh = { flow.onIntent(OrderIntent.RetryCatalog) })
    // The "cake removed" message lasts until the customer changes a quantity or leaves the step (UI document 5.5).
    DisposableEffect(flow) { onDispose { flow.onIntent(OrderIntent.DismissRemovedNotice) } }
    CakesScreen(state, flow::onIntent, onBack, onNext)
}

/** S-5, step 1: a quantity for each active cake (FR-5). */
@Composable
fun CakesScreen(state: OrderFlowState, onIntent: (OrderIntent) -> Unit, onBack: () -> Unit, onNext: () -> Unit) {
    val summary = state.summary
    val canProceed = summary != null && summary.totalQuantity >= state.minQty
    OrderStepScaffold(
        step = 1,
        onBack = onBack,
        bottomBar = {
            PrimaryButton(
                text = stringResource(R.string.common_next),
                onClick = onNext,
                modifier = Modifier.testTag(TestTags.ORDER_NEXT),
                enabled = canProceed,
            )
        },
    ) {
        when (val catalog = state.catalog) {
            Load.Loading -> CakesSkeleton()
            is Load.Failed -> ErrorState(stringResource(catalogLoadFailureText(catalog.failure)), onRetry = { onIntent(OrderIntent.RetryCatalog) })
            is Load.Ready ->
                if (catalog.value.products.isEmpty()) {
                    EmptyState(stringResource(R.string.products_empty), onRetry = { onIntent(OrderIntent.RetryCatalog) })
                } else {
                    CakesContent(state, catalog.value.products, summary, onIntent)
                }
        }
    }
}

@Composable
private fun CakesContent(state: OrderFlowState, products: List<Product>, summary: OrderSummary?, onIntent: (OrderIntent) -> Unit) {
    val total = summary?.totalQuantity ?: 0
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        if (state.removedCakeNames.isNotEmpty()) {
            val unknownName = stringResource(R.string.order_cake_removed_unknown_name)
            val names = state.removedCakeNames.joinToString(", ") { it.ifBlank { unknownName } }
            InfoMessage(
                text = stringResource(R.string.order_cake_removed, names),
                modifier = Modifier
                    .testTag(TestTags.ORDER_CAKE_REMOVED_NOTICE)
                    .semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                products.forEach { product ->
                    CakeRow(
                        product = product,
                        quantity = state.draft.quantityOf(product.id),
                        max = state.maxQtyPerCake,
                        onQuantityChange = { onIntent(OrderIntent.SetQuantity(product.id, it)) },
                    )
                }
            }
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Text(
                stringResource(R.string.qty_total, total),
                style = MaterialTheme.typography.bodyStrong,
                modifier = Modifier.testTag(TestTags.ORDER_QTY_TOTAL),
            )
            Text(
                stringResource(R.string.qty_subtotal, formatMoney(summary?.cakesSubtotalVnd ?: 0L)),
                style = MaterialTheme.typography.bodyStrong,
                modifier = Modifier.testTag(TestTags.ORDER_QTY_SUBTOTAL),
            )
        }
        if (total < state.minQty) {
            InfoMessage(stringResource(R.string.qty_min_hint, state.minQty), Modifier.testTag(TestTags.ORDER_QTY_MIN_HINT))
        }
    }
}

@Composable
private fun CakeRow(product: Product, quantity: Int, max: Int, onQuantityChange: (Int) -> Unit) {
    // The stepper sits under the name, so a large font or a long name never squeezes it (UI document 9).
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ProductImage(product.imageUrl, product.name, Modifier.size(Sizes.thumb))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text(product.name, style = MaterialTheme.typography.titleLarge)
                Text(stringResource(R.string.price_each, formatMoney(product.priceVnd)), style = MaterialTheme.typography.bodyStrong)
            }
        }
        QuantityStepper(
            productId = product.id,
            productName = product.name,
            quantity = quantity,
            max = max,
            onQuantityChange = onQuantityChange,
            modifier = Modifier.align(Alignment.End),
        )
    }
}

@Composable
private fun CakesSkeleton() {
    GlassCard(Modifier.fillMaxWidth().loadingSemantics()) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
            repeat(SKELETON_ROWS) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    SkeletonBlock(Modifier.size(Sizes.thumb), RoundedCornerShape(Radii.image))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        SkeletonBlock(Modifier.fillMaxWidth().height(Spacing.xl))
                        SkeletonBlock(Modifier.fillMaxWidth().height(Spacing.lg))
                    }
                }
            }
        }
    }
}
