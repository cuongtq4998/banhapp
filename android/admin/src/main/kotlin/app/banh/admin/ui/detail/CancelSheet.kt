package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import app.banh.admin.R
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.DetailBanner
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.tag
import app.banh.admin.ui.textRes
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Sizes
import app.banh.core.design.Spacing
import app.banh.core.model.CancelReason
import androidx.compose.ui.res.painterResource

/** S-A5: one required reason and one confirm. This sheet is the whole cancel step (FR-18, BR-8); nothing is preselected (AC-28). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CancelSheet(state: OrderDetailState, dispatch: (OrderDetailIntent) -> Unit) {
    ModalBottomSheet(onDismissRequest = { dispatch(OrderDetailIntent.CancelBack) }) {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(horizontal = Spacing.screenMargin),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(stringResource(R.string.a_cancel_title), style = MaterialTheme.typography.titleLarge)
            Text(stringResource(R.string.a_cancel_body, state.orderCode), style = MaterialTheme.typography.bodyLarge)
            CancelReason.entries.forEach { ReasonRow(it, it == state.reason, state.busy == null) { dispatch(OrderDetailIntent.SelectReason(it)) } }
            Text(stringResource(R.string.a_reason_internal), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SheetError(state.banner)
            PrimaryButton(
                text = stringResource(R.string.a_cancel_confirm, state.orderCode),
                onClick = { dispatch(OrderDetailIntent.CancelConfirm) },
                enabled = state.reason != null && state.busy == null,
                loading = state.busy == BusyAction.CANCEL,
                destructive = true,
                modifier = Modifier.testTag(AdminTags.CANCEL_CONFIRM),
            )
            SecondaryButton(
                text = stringResource(R.string.a_back),
                onClick = { dispatch(OrderDetailIntent.CancelBack) },
                enabled = state.busy == null,
                modifier = Modifier.testTag(AdminTags.CANCEL_BACK),
            )
        }
    }
}

@Composable
private fun SheetError(banner: DetailBanner?) {
    val text = when (banner) {
        DetailBanner.ActionError -> R.string.a_err_status
        DetailBanner.ActionOffline -> R.string.a_offline_save
        else -> return
    }
    ErrorMessageView(stringResource(text), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.CANCEL_ERROR))
}

@Composable
private fun ReasonRow(reason: CancelReason, selected: Boolean, enabled: Boolean, onSelect: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = Sizes.touchTarget + Spacing.sm)
            .selectable(selected = selected, enabled = enabled, role = Role.RadioButton, onClick = onSelect)
            .testTag(reason.tag()),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = null, enabled = enabled)
        Text(stringResource(reason.textRes()), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(start = Spacing.md))
    }
}
