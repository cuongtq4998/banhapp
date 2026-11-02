package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.DetailBanner
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing

/** What differs between the three process sheets: title, tags and the save button. */
class SheetSpec(
    val title: String,
    val sheetTag: String,
    val saveText: String,
    val saveTag: String,
    val backTag: String,
    val saveEnabled: Boolean,
    val busy: BusyAction,
)

/**
 * Large sheet like the cancel step: content scrolls above the keyboard, the two buttons stay pinned under it.
 * A failed or offline save shows above the buttons, inside the sheet.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SheetFrame(state: OrderDetailState, spec: SheetSpec, dispatch: (OrderDetailIntent) -> Unit, content: @Composable () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = { dispatch(OrderDetailIntent.SheetBack) },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        modifier = Modifier.testTag(spec.sheetTag),
    ) {
        Column(Modifier.fillMaxHeight().imePadding()) {
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.screenMargin),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text(spec.title, style = MaterialTheme.typography.titleLarge)
                content()
            }
            Column(
                modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = Spacing.screenMargin, vertical = Spacing.sm),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                SheetBannerError(state.banner)
                PrimaryButton(
                    text = spec.saveText,
                    onClick = { dispatch(OrderDetailIntent.Submit) },
                    enabled = spec.saveEnabled && state.busy == null,
                    loading = state.busy == spec.busy,
                    modifier = Modifier.testTag(spec.saveTag),
                )
                SecondaryButton(text = stringResource(R.string.a_back), onClick = { dispatch(OrderDetailIntent.SheetBack) }, enabled = state.busy == null, modifier = Modifier.testTag(spec.backTag))
            }
        }
    }
}

@Composable
private fun SheetBannerError(banner: DetailBanner?) {
    val text = when (banner) {
        DetailBanner.ActionError -> R.string.a_err_status
        DetailBanner.ActionOffline -> R.string.a_offline_save
        else -> return
    }
    ErrorMessageView(stringResource(text), painterResource(R.drawable.ic_error))
}
