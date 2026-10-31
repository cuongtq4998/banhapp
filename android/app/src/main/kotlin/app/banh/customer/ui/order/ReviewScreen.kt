package app.banh.customer.ui.order

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.ui.common.ErrorMessage
import app.banh.customer.ui.common.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.Spacing
import app.banh.customer.order.FieldRules
import app.banh.customer.order.FixStep
import app.banh.customer.order.OrderEffect
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.SubmitRule
import app.banh.customer.order.SubmitState
import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.OrderSummary
import app.banh.customer.order.toDisplayText
import app.banh.customer.order.toLocalDateOrNull
import app.banh.customer.ui.common.catalogLoadFailureText
import app.banh.customer.ui.privacy.ReviewPrivacyNotice

/** Where each Edit control and issue action leads; the host maps them to routes (ADR-0007). */
class ReviewActions(
    val onBack: () -> Unit,
    val onEditCakes: () -> Unit,
    val onEditDelivery: () -> Unit,
    val onEditRecipient: () -> Unit,
    val onConfirm: () -> Unit = {},
    /** The order was received: open S-9. */
    val onConfirmed: () -> Unit = {},
)

@Composable
fun ReviewRoute(flow: OrderFlowViewModel, actions: ReviewActions) {
    val state by flow.state.collectAsStateWithLifecycle()
    val currentActions by rememberUpdatedState(actions)
    val orderCode = (state.submit as? SubmitState.Confirmed)?.orderCode
    // State-driven, so the screen opens S-9 even if the answer arrives while the app was in the background.
    LaunchedEffect(orderCode) { if (orderCode != null) currentActions.onConfirmed() }
    LaunchedEffect(flow) {
        flow.effects.collect { if (it == OrderEffect.GoToRecipient) currentActions.onEditRecipient() }
    }
    // Leaving the review dismisses a shown problem; while sending, nothing leaves (UI document 5.8).
    fun leaving(go: () -> Unit): () -> Unit = {
        if (state.submit !is SubmitState.Sending) {
            flow.onIntent(OrderIntent.LeaveReview)
            go()
        }
    }
    val guarded = ReviewActions(
        onBack = leaving(actions.onBack),
        onEditCakes = leaving(actions.onEditCakes),
        onEditDelivery = leaving(actions.onEditDelivery),
        onEditRecipient = leaving(actions.onEditRecipient),
        onConfirm = { flow.onIntent(OrderIntent.Confirm) },
        onConfirmed = actions.onConfirmed,
    )
    ReviewScreen(state, guarded, onRetryCatalog = { flow.onIntent(OrderIntent.RetryCatalog) })
}

/**
 * S-8, step 4: the whole order before it is sent (FR-9) and the send itself (FR-11). Confirm is on when
 * [OrderFlowState.canConfirm]; while [sending] it shows the spinner and the Edit controls are off.
 */
@Composable
fun ReviewScreen(
    state: OrderFlowState,
    actions: ReviewActions,
    onRetryCatalog: () -> Unit = {},
    sending: Boolean = state.submit is SubmitState.Sending,
) {
    val summary = state.summary
    // A rule that the client can already see broken blocks the button and names the step to fix (FR-10, AC-13).
    val quantityIssue = summary != null && summary.totalQuantity < state.minQty
    // The system back button is swallowed while the request is out, so the result cannot be lost (TC-266).
    BackHandler(enabled = sending) {}
    OrderStepScaffold(
        step = 4,
        onBack = { if (!sending) actions.onBack() },
        bottomBar = {
            PrimaryButton(
                text = stringResource(if (sending) R.string.btn_sending else R.string.btn_confirm),
                onClick = actions.onConfirm,
                modifier = Modifier.testTag(TestTags.REVIEW_CONFIRM),
                enabled = state.canConfirm && !sending,
                loading = sending,
            )
        },
    ) {
        when (val catalog = state.catalog) {
            Load.Loading -> Text(stringResource(R.string.common_loading), style = MaterialTheme.typography.bodyLarge)
            is Load.Failed -> ErrorState(stringResource(catalogLoadFailureText(catalog.failure)), onRetryCatalog)
            is Load.Ready -> {
                if (summary != null) ReviewContent(state, catalog.value, summary, quantityIssue, actions, sending)
            }
        }
    }
}

@Composable
private fun ReviewContent(state: OrderFlowState, catalog: Catalog, summary: OrderSummary, quantityIssue: Boolean, actions: ReviewActions, sending: Boolean) {
    val problem = (state.submit as? SubmitState.Failed)?.problem
    val update = state.priceUpdate
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        if (problem != null) {
            SubmitBanner(problem, state, onFix = { actions.fixAction(it)() }, onRetry = actions.onConfirm)
        } else if (quantityIssue) {
            ErrorMessage(
                text = stringResource(R.string.err_min_qty, state.minQty),
                modifier = Modifier.testTag(TestTags.REVIEW_ISSUE),
                actionLabel = stringResource(R.string.date_empty_action),
                actionTestTag = TestTags.REVIEW_MESSAGE_ACTION,
                onAction = actions.onEditCakes,
            )
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                ReviewSectionHeader(stringResource(R.string.review_sec_cakes), TestTags.REVIEW_EDIT_CAKES, actions.onEditCakes, enabled = !sending)
                summary.lines.forEach {
                    val changed = update != null && it.product.id in update.changedProductIds
                    CakeSummaryRow(it.product.name, it.quantity, it.lineTotalVnd, TestTags.reviewItem(it.product.id), highlighted = changed)
                }
            }
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                MoneySummaryRow(stringResource(R.string.review_fee), summary.deliveryFeeVnd, TestTags.REVIEW_FEE, highlighted = update?.feeChanged == true)
                MoneySummaryRow(stringResource(R.string.review_total), summary.totalVnd, TestTags.REVIEW_TOTAL, emphasized = true, highlighted = update?.totalChanged == true)
            }
        }
        DeliveryCard(state, catalog, summary, actions, sending)
        ReviewPrivacyNotice(sending = sending)
    }
}

private fun ReviewActions.fixAction(rule: SubmitRule): () -> Unit = when (rule.fixStep) {
    FixStep.CAKES -> onEditCakes
    FixStep.DATE -> onEditDelivery
    FixStep.RECIPIENT -> onEditRecipient
}

@Composable
private fun DeliveryCard(state: OrderFlowState, catalog: Catalog, summary: OrderSummary, actions: ReviewActions, sending: Boolean) {
    val draft = state.draft
    val slot = catalog.slots.firstOrNull { it.id == draft.slotId }
    val address = listOfNotNull(FieldRules.normalizeForSubmit(draft.address).ifBlank { null }, summary.district?.name).joinToString(", ")
    GlassCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ReviewSectionHeader(stringResource(R.string.step2), TestTags.REVIEW_EDIT_DELIVERY, actions.onEditDelivery, enabled = !sending)
            TextSummaryRow(stringResource(R.string.review_date), draft.date?.toLocalDateOrNull()?.toDisplayText().orEmpty(), TestTags.REVIEW_DATE)
            TextSummaryRow(stringResource(R.string.review_time), slot?.let { slotLabel(it) }.orEmpty(), TestTags.REVIEW_TIME)
            ReviewSectionHeader(stringResource(R.string.step3), TestTags.REVIEW_EDIT_RECIPIENT, actions.onEditRecipient, enabled = !sending)
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
