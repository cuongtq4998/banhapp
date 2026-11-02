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
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.DetailSheet
import app.banh.core.model.OrderAction
import app.banh.admin.orderdetail.DetailBanner
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.textRes
import app.banh.core.design.BottomActionBar
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing
import app.banh.core.design.WarningMessageView

/** New: cancel + confirm. Confirmed: cancel + complete. Final states have no bar (FR-16 to FR-18). */
@Composable
fun DetailActionBar(state: OrderDetailState, dispatch: (OrderDetailIntent) -> Unit) {
    if (!state.hasActions) return
    BottomActionBar {
        DetailBannerView(state.banner)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), modifier = Modifier.fillMaxWidth()) {
            SecondaryButton(
                text = stringResource(R.string.a_cancel_order),
                onClick = { dispatch(OrderDetailIntent.Tap(OrderAction.CANCEL)) },
                enabled = state.busy == null,
                destructive = true,
                modifier = Modifier.weight(1f).testTag(AdminTags.DETAIL_CANCEL),
            )
            if (state.allows(OrderAction.PROCESS)) {
                PrimaryButton(
                    text = stringResource(R.string.a_confirm_order),
                    onClick = { dispatch(OrderDetailIntent.Tap(OrderAction.PROCESS)) },
                    enabled = state.busy == null,
                    loading = state.busy == BusyAction.PROCESS,
                    modifier = Modifier.weight(1f).testTag(AdminTags.DETAIL_CONFIRM),
                )
            } else {
                PrimaryButton(
                    text = stringResource(R.string.a_complete_order),
                    onClick = { dispatch(OrderDetailIntent.Tap(OrderAction.FINISH)) },
                    enabled = state.busy == null,
                    loading = state.busy == BusyAction.FINISH,
                    modifier = Modifier.weight(1f).testTag(AdminTags.DETAIL_COMPLETE),
                )
            }
        }
    }
}

/** The message above the bar: a conflict (Warning, FR-19) or a failed action (Error). Failures of the cancel sheet show inside the sheet. */
@Composable
fun DetailBannerView(banner: DetailBanner?, modifier: Modifier = Modifier) {
    val icon = painterResource(R.drawable.ic_error)
    when (banner) {
        is DetailBanner.Conflict ->
            WarningMessageView(stringResource(R.string.a_conflict, stringResource(banner.status.textRes())), icon, modifier.testTag(AdminTags.DETAIL_CONFLICT))
        is DetailBanner.Rule, DetailBanner.ActionError -> ErrorMessageView(stringResource(R.string.a_err_status), icon, modifier.testTag(AdminTags.DETAIL_ERROR))
        DetailBanner.ActionOffline -> ErrorMessageView(stringResource(R.string.a_offline_save), icon, modifier.testTag(AdminTags.DETAIL_ERROR))
        null -> Unit
    }
}

/** Completing is final, so it asks once and names the order (AC-27). */
@Composable
fun CompleteDialog(code: String, dispatch: (OrderDetailIntent) -> Unit) {
    AlertDialog(
        onDismissRequest = { dispatch(OrderDetailIntent.SheetBack) },
        title = { Text(stringResource(R.string.a_complete_title, code)) },
        text = { Text(stringResource(R.string.a_complete_body)) },
        confirmButton = {
            TextButton(onClick = { dispatch(OrderDetailIntent.FinishYes) }, modifier = Modifier.testTag(AdminTags.DETAIL_COMPLETE_YES)) { Text(stringResource(R.string.a_complete_yes)) }
        },
        dismissButton = {
            TextButton(onClick = { dispatch(OrderDetailIntent.SheetBack) }, modifier = Modifier.testTag(AdminTags.DETAIL_COMPLETE_BACK)) { Text(stringResource(R.string.a_back)) }
        },
    )
}
