package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.core.common.formatVnd
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.barActionsOf
import app.banh.admin.orderdetail.cancelBlocked
import app.banh.core.model.OrderAction
import app.banh.admin.orderdetail.DetailBanner
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.ui.AdminOrderTags
import app.banh.admin.ui.textRes
import app.banh.core.design.BottomActionBar
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.InfoMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing
import app.banh.core.design.WarningMessageView

/** Buttons come from the server's allowed actions only; a missing button is never greyed (design 12, 5.12). */
@Composable
fun DetailActionBar(state: OrderDetailState, dispatch: (OrderDetailIntent) -> Unit) {
    if (!state.hasActions && !state.cancelBlocked()) return
    val bar = barActionsOf(state.detail?.allowedActions.orEmpty())
    BottomActionBar {
        DetailBannerView(state.banner)
        if (state.cancelBlocked()) {
            InfoMessageView(stringResource(R.string.a_cancel_blocked), painterResource(R.drawable.ic_error), Modifier.testTag(AdminOrderTags.ORDER_CANCEL_BLOCKED))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), modifier = Modifier.fillMaxWidth()) {
            bar.left?.let { action ->
                SecondaryButton(
                    text = stringResource(action.labelRes()),
                    onClick = { dispatch(OrderDetailIntent.Tap(action)) },
                    enabled = state.busy == null,
                    destructive = action == OrderAction.CANCEL,
                    modifier = Modifier.weight(1f).testTag(action.tag()),
                )
            }
            bar.right?.let { action ->
                PrimaryButton(
                    text = stringResource(action.labelRes()),
                    onClick = { dispatch(OrderDetailIntent.Tap(action)) },
                    enabled = state.busy == null,
                    loading = state.busy == action.busy(),
                    modifier = Modifier.weight(1f).testTag(action.tag()),
                )
            }
        }
    }
}

fun OrderAction.labelRes(): Int = when (this) {
    OrderAction.CANCEL -> R.string.a_cancel_order
    OrderAction.PROCESS -> R.string.a_process_order
    OrderAction.SCHEDULE_DELIVERY -> R.string.a_schedule_date
    OrderAction.START_DELIVERY -> R.string.a_start_delivery
    OrderAction.FINISH -> R.string.a_finish_order
    OrderAction.CHANGE_DATE -> R.string.a_change_date
    OrderAction.CORRECT_FEE -> R.string.a_fee_correct
}

fun OrderAction.tag(): String = when (this) {
    OrderAction.CANCEL -> AdminOrderTags.DETAIL_CANCEL
    OrderAction.PROCESS -> AdminOrderTags.ORDER_PROCESS
    OrderAction.SCHEDULE_DELIVERY -> AdminOrderTags.ORDER_SCHEDULE
    OrderAction.START_DELIVERY -> AdminOrderTags.ORDER_START_DELIVERY
    OrderAction.FINISH -> AdminOrderTags.ORDER_FINISH
    OrderAction.CHANGE_DATE -> AdminOrderTags.ORDER_CHANGE_DATE
    OrderAction.CORRECT_FEE -> AdminOrderTags.ORDER_FEE_CORRECT
}

private fun OrderAction.busy(): BusyAction = when (this) {
    OrderAction.CANCEL -> BusyAction.CANCEL
    OrderAction.PROCESS -> BusyAction.PROCESS
    OrderAction.SCHEDULE_DELIVERY -> BusyAction.SCHEDULE
    OrderAction.START_DELIVERY -> BusyAction.START_DELIVERY
    OrderAction.FINISH -> BusyAction.FINISH
    OrderAction.CHANGE_DATE -> BusyAction.CHANGE_DATE
    OrderAction.CORRECT_FEE -> BusyAction.CORRECT_FEE
}

/** The message above the bar: a conflict (Warning, FR-19) or a failed action (Error). Failures of the cancel sheet show inside the sheet. */
@Composable
fun DetailBannerView(banner: DetailBanner?, modifier: Modifier = Modifier) {
    val icon = painterResource(R.drawable.ic_error)
    when (banner) {
        is DetailBanner.Conflict ->
            WarningMessageView(stringResource(R.string.a_conflict, stringResource(banner.status.textRes())), icon, modifier.testTag(AdminOrderTags.DETAIL_CONFLICT))
        is DetailBanner.FeeConflict ->
            WarningMessageView(stringResource(R.string.a_fee_conflict, formatVnd(banner.feeVnd)), icon, modifier.testTag(AdminOrderTags.ORDER_FEE_CONFLICT))
        is DetailBanner.Rule, DetailBanner.ActionError -> ErrorMessageView(stringResource(R.string.a_err_status), icon, modifier.testTag(AdminOrderTags.DETAIL_ERROR))
        DetailBanner.ActionOffline -> ErrorMessageView(stringResource(R.string.a_offline_save), icon, modifier.testTag(AdminOrderTags.DETAIL_ERROR))
        null -> Unit
    }
}

/** Completing is final, so it asks once and names the order (AC-27). */
@Composable
fun CompleteDialog(code: String, dispatch: (OrderDetailIntent) -> Unit) {
    AlertDialog(
        onDismissRequest = { dispatch(OrderDetailIntent.SheetBack) },
        title = { Text(stringResource(R.string.a_finish_title, code)) },
        text = { Text(stringResource(R.string.a_finish_body)) },
        confirmButton = {
            TextButton(onClick = { dispatch(OrderDetailIntent.FinishYes) }, modifier = Modifier.testTag(AdminOrderTags.DETAIL_COMPLETE_YES)) { Text(stringResource(R.string.a_finish_yes)) }
        },
        dismissButton = {
            TextButton(onClick = { dispatch(OrderDetailIntent.SheetBack) }, modifier = Modifier.testTag(AdminOrderTags.DETAIL_COMPLETE_BACK)) { Text(stringResource(R.string.a_back)) }
        },
    )
}
