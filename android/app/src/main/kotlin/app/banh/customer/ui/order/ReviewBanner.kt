package app.banh.customer.ui.order

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.order.NotSentReason
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.SubmitProblem
import app.banh.customer.order.SubmitRule
import app.banh.customer.order.toDisplayText
import app.banh.customer.order.toLocalDateOrNull
import app.banh.customer.ui.common.ErrorMessage
import app.banh.customer.ui.common.InfoMessage

/**
 * The message at the top of S-8 for a failed send (UI document 5.8): a broken rule with the action that opens the step
 * to fix it, a send that did not happen with retry, or the price change as an alert.
 */
@Composable
fun SubmitBanner(problem: SubmitProblem, state: OrderFlowState, onFix: (SubmitRule) -> Unit, onRetry: () -> Unit) {
    when (problem) {
        is SubmitProblem.Rule -> ErrorMessage(
            text = ruleText(problem, state),
            modifier = Modifier.testTag(TestTags.REVIEW_ISSUE),
            actionLabel = stringResource(ruleActionLabel(problem.rule)),
            actionTestTag = TestTags.REVIEW_MESSAGE_ACTION,
            onAction = { onFix(problem.rule) },
        )
        is SubmitProblem.NotSent -> ErrorMessage(
            text = stringResource(notSentText(problem.reason)),
            modifier = Modifier.testTag(TestTags.REVIEW_ISSUE),
            actionLabel = stringResource(R.string.common_retry),
            actionTestTag = TestTags.REVIEW_MESSAGE_ACTION,
            onAction = onRetry,
        )
        SubmitProblem.PriceChanged -> InfoMessage(
            text = stringResource(R.string.msg_price_changed),
            modifier = Modifier.testTag(TestTags.REVIEW_PRICE_CHANGED).semantics { liveRegion = LiveRegionMode.Assertive },
        )
    }
}

private fun notSentText(reason: NotSentReason): Int = when (reason) {
    NotSentReason.OFFLINE -> R.string.err_offline
    NotSentReason.TIMEOUT -> R.string.err_timeout
    NotSentReason.SERVER -> R.string.err_server
    NotSentReason.RATE_LIMITED -> R.string.err_rate_limited
}

private fun ruleActionLabel(rule: SubmitRule): Int = when (rule) {
    SubmitRule.MIN_QTY, SubmitRule.PRODUCT_UNAVAILABLE -> R.string.date_empty_action
    SubmitRule.DATE_CAPACITY, SubmitRule.DATE_LEAD, SubmitRule.DATE_HORIZON -> R.string.action_choose_date
    SubmitRule.SLOT_UNAVAILABLE -> R.string.action_choose_slot
    SubmitRule.DISTRICT_UNSERVED -> R.string.action_choose_district
}

@Composable
private fun ruleText(problem: SubmitProblem.Rule, state: OrderFlowState): String = when (problem.rule) {
    SubmitRule.MIN_QTY -> stringResource(R.string.err_min_qty, problem.number.takeIf { it > 0 } ?: state.minQty)
    SubmitRule.DATE_CAPACITY -> {
        val date = (problem.date ?: state.draft.date)?.toLocalDateOrNull()?.toDisplayText().orEmpty()
        stringResource(R.string.err_date_capacity, date)
    }
    SubmitRule.DATE_LEAD -> stringResource(R.string.err_date_lead, problem.number)
    SubmitRule.DATE_HORIZON -> stringResource(R.string.err_date_horizon, problem.number)
    SubmitRule.DISTRICT_UNSERVED -> stringResource(R.string.err_district_unserved)
    SubmitRule.PRODUCT_UNAVAILABLE -> stringResource(R.string.err_product_unavailable)
    SubmitRule.SLOT_UNAVAILABLE -> stringResource(R.string.err_slot_unavailable)
}
