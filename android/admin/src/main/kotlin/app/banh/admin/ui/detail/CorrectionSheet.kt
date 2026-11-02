package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.DetailSheet
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.orderdetail.SheetError
import app.banh.admin.orderdetail.feeOf
import app.banh.admin.orderdetail.feePreviewOf
import app.banh.admin.orderdetail.sheetError
import app.banh.admin.ui.AdminOrderTags
import app.banh.core.common.formatVnd

/**
 * Correct the real fee at the delivery step: shows the current fee, refuses an equal value.
 * The history list stays on the detail below the cakes card; a lost race closes the sheet and the screen shows the new fee.
 */
@Composable
fun CorrectionSheet(state: OrderDetailState, dispatch: (OrderDetailIntent) -> Unit) {
    val sheet = state.sheet as? DetailSheet.FeeCorrection ?: return
    val detail = state.detail ?: return
    val previous = detail.deliveryFeeFinalVnd
    val spec = SheetSpec(
        title = stringResource(R.string.a_fee_correct_title, state.orderCode),
        sheetTag = AdminOrderTags.FEE_FIX_SHEET,
        saveText = stringResource(R.string.a_fee_correct_save),
        saveTag = AdminOrderTags.FEE_FIX_SAVE,
        backTag = AdminOrderTags.FEE_FIX_BACK,
        saveEnabled = state.canSaveFeeCorrection,
        busy = BusyAction.CORRECT_FEE,
    )
    SheetFrame(state, spec, dispatch) {
        if (previous != null) {
            SummaryRow(stringResource(R.string.a_fee_previous), formatVnd(previous), Modifier.testTag(AdminOrderTags.FEE_FIX_PREVIOUS))
        }
        val typed = feeOf(sheet.text)
        val typedError = when {
            sheet.text.isEmpty() -> null
            typed == null -> SheetError.FEE_INVALID
            typed == previous -> SheetError.FEE_UNCHANGED
            else -> null
        }
        FeeField(sheet.text, sheet.error?.sheetError() ?: typedError, AdminOrderTags.FEE_FIX_FIELD, AdminOrderTags.FEE_FIX_ERROR) { dispatch(OrderDetailIntent.EditFee(it)) }
        FeeSummary(detail.itemsSubtotalVnd, feePreviewOf(detail.itemsSubtotalVnd, sheet.text), AdminOrderTags.FEE_FIX_TOTAL)
    }
}
