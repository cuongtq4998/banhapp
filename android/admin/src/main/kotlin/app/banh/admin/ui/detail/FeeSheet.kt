package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.DetailSheet
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.orderdetail.SheetError
import app.banh.admin.orderdetail.feePreviewOf
import app.banh.admin.orderdetail.sheetError
import app.banh.admin.ui.AdminOrderTags
import app.banh.core.common.formatVnd

/** Start delivery: the real fee is typed (0 allowed, no prefill) and the sheet is the only confirmation. */
@Composable
fun FeeSheet(state: OrderDetailState, dispatch: (OrderDetailIntent) -> Unit) {
    val sheet = state.sheet as? DetailSheet.Fee ?: return
    val detail = state.detail ?: return
    val spec = SheetSpec(
        title = stringResource(R.string.a_fee_title, state.orderCode),
        sheetTag = AdminOrderTags.FEE_SHEET,
        saveText = stringResource(R.string.a_start_delivery_confirm, state.orderCode),
        saveTag = AdminOrderTags.FEE_CONFIRM,
        backTag = AdminOrderTags.FEE_BACK,
        saveEnabled = state.canSaveFee,
        busy = BusyAction.START_DELIVERY,
    )
    SheetFrame(state, spec, dispatch) {
        Text(stringResource(R.string.a_fee_body), style = MaterialTheme.typography.bodyLarge)
        val typedError = if (sheet.text.isNotEmpty() && !state.canSaveFee) SheetError.FEE_INVALID else null
        FeeField(sheet.text, sheet.error?.sheetError() ?: typedError, AdminOrderTags.FEE_FIELD, AdminOrderTags.FEE_ERROR) { dispatch(OrderDetailIntent.EditFee(it)) }
        detail.deliveryFeeEstimateVnd?.let {
            Text(stringResource(R.string.a_fee_estimate_line, formatVnd(it)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        FeeSummary(detail.itemsSubtotalVnd, feePreviewOf(detail.itemsSubtotalVnd, sheet.text), AdminOrderTags.FEE_TOTAL)
    }
}
