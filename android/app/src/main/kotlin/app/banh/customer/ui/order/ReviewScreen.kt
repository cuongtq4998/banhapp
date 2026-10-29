package app.banh.customer.ui.order

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.design.ErrorMessage
import app.banh.customer.design.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.Spacing
import app.banh.customer.order.FieldRules
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.OrderSummary
import app.banh.customer.order.toDisplayText
import app.banh.customer.order.toLocalDateOrNull
import app.banh.customer.ui.common.catalogLoadFailureText

/** Where each Edit control and issue action leads; the host maps them to routes (ADR-0007). */
class ReviewActions(
    val onBack: () -> Unit,
    val onEditCakes: () -> Unit,
    val onEditDelivery: () -> Unit,
    val onEditRecipient: () -> Unit,
    val onConfirm: () -> Unit = {},
)

@Composable
fun ReviewRoute(flow: OrderFlowViewModel, actions: ReviewActions) {
    val state by flow.state.collectAsStateWithLifecycle()
    ReviewScreen(state, actions, onRetryCatalog = { flow.onIntent(OrderIntent.RetryCatalog) })
}

/**
 * S-8, step 4: the whole order before it is sent (FR-9). Slice 2 stops here: sending is slice 3, so the confirm button
 * is off unless [confirmEnabled] is set, which the order creation work will do.
 */
@Composable
fun ReviewScreen(
    state: OrderFlowState,
    actions: ReviewActions,
    onRetryCatalog: () -> Unit = {},
    confirmEnabled: Boolean = false,
) {
    val summary = state.summary
    // A rule that the client can already see broken blocks the button and names the step to fix (FR-10, AC-13).
    val quantityIssue = summary != null && summary.totalQuantity < state.minQty
    OrderStepScaffold(
        step = 4,
        onBack = actions.onBack,
        bottomBar = {
            PrimaryButton(
                text = stringResource(R.string.btn_confirm),
                onClick = actions.onConfirm,
                modifier = Modifier.testTag(TestTags.REVIEW_CONFIRM),
                enabled = confirmEnabled && !quantityIssue,
            )
        },
    ) {
        when (val catalog = state.catalog) {
            Load.Loading -> Text(stringResource(R.string.common_loading), style = MaterialTheme.typography.bodyLarge)
            is Load.Failed -> ErrorState(stringResource(catalogLoadFailureText(catalog.failure)), onRetryCatalog)
            is Load.Ready -> {
                if (summary != null) ReviewContent(state, catalog.value, summary, quantityIssue, actions)
            }
        }
    }
}

@Composable
private fun ReviewContent(state: OrderFlowState, catalog: Catalog, summary: OrderSummary, quantityIssue: Boolean, actions: ReviewActions) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        if (quantityIssue) {
            ErrorMessage(
                text = stringResource(R.string.err_min_qty, state.minQty),
                modifier = Modifier.testTag(TestTags.REVIEW_ISSUE),
                actionLabel = stringResource(R.string.date_empty_action),
                onAction = actions.onEditCakes,
            )
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                ReviewSectionHeader(stringResource(R.string.review_sec_cakes), TestTags.REVIEW_EDIT_CAKES, actions.onEditCakes)
                summary.lines.forEach { CakeSummaryRow(it.product.name, it.quantity, it.lineTotalVnd, TestTags.reviewItem(it.product.id)) }
            }
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                MoneySummaryRow(stringResource(R.string.review_fee), summary.deliveryFeeVnd, TestTags.REVIEW_FEE)
                MoneySummaryRow(stringResource(R.string.review_total), summary.totalVnd, TestTags.REVIEW_TOTAL, emphasized = true)
            }
        }
        DeliveryCard(state, catalog, summary, actions)
        Text(
            stringResource(R.string.review_privacy),
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.testTag(TestTags.REVIEW_PRIVACY),
        )
    }
}

@Composable
private fun DeliveryCard(state: OrderFlowState, catalog: Catalog, summary: OrderSummary, actions: ReviewActions) {
    val draft = state.draft
    val slot = catalog.slots.firstOrNull { it.id == draft.slotId }
    val address = listOfNotNull(FieldRules.normalizeForSubmit(draft.address).ifBlank { null }, summary.district?.name).joinToString(", ")
    GlassCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ReviewSectionHeader(stringResource(R.string.step2), TestTags.REVIEW_EDIT_DELIVERY, actions.onEditDelivery)
            TextSummaryRow(stringResource(R.string.review_date), draft.date?.toLocalDateOrNull()?.toDisplayText().orEmpty(), TestTags.REVIEW_DATE)
            TextSummaryRow(stringResource(R.string.review_time), slot?.let { slotLabel(it) }.orEmpty(), TestTags.REVIEW_TIME)
            ReviewSectionHeader(stringResource(R.string.step3), TestTags.REVIEW_EDIT_RECIPIENT, actions.onEditRecipient)
            TextSummaryRow(stringResource(R.string.review_name), FieldRules.normalizeForSubmit(draft.name), TestTags.REVIEW_NAME)
            TextSummaryRow(stringResource(R.string.review_phone), draft.phone.trim(), TestTags.REVIEW_PHONE)
            TextSummaryRow(stringResource(R.string.review_address), address, TestTags.REVIEW_ADDRESS)
            // The note row exists only when a note was entered (UI document 5.8).
            if (draft.note.isNotBlank()) {
                TextSummaryRow(stringResource(R.string.review_note), FieldRules.normalizeForSubmit(draft.note), TestTags.REVIEW_NOTE)
            }
        }
    }
}
