package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import app.banh.admin.R
import app.banh.admin.orderdetail.FeePreview
import app.banh.admin.orderdetail.SheetError
import app.banh.core.common.formatVnd
import app.banh.core.design.Spacing

/** The fee input: digits only, no prefill, the error beside the field (shown by [errorTag]). */
@Composable
fun FeeField(text: String, error: SheetError?, fieldTag: String, errorTag: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = text,
        onValueChange = onChange,
        label = { Text(stringResource(R.string.a_f_real_fee)) },
        suffix = { Text(" ₫") },
        singleLine = true,
        isError = error != null,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        supportingText = error?.let { { Text(stringResource(it.textRes()), modifier = Modifier.testTag(errorTag)) } },
        modifier = Modifier.fillMaxWidth().testTag(fieldTag),
    )
}

/** Cakes, the typed fee and the total; the block is a polite live region so the sum is announced as it changes. */
@Composable
fun FeeSummary(cakesVnd: Long, preview: FeePreview, totalTag: String) {
    Column(Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite }, verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        SummaryRow(stringResource(R.string.a_cakes_total), formatVnd(cakesVnd))
        val feeText = when (preview.feeVnd) {
            null -> stringResource(R.string.a_fee_dash)
            0L -> stringResource(R.string.a_fee_free)
            else -> formatVnd(preview.feeVnd)
        }
        SummaryRow(stringResource(R.string.a_fee_new), feeText)
        preview.totalVnd?.let { SummaryRow(stringResource(R.string.a_total_collect), formatVnd(it), Modifier.testTag(totalTag), strong = true) }
    }
}

@Composable
fun SummaryRow(label: String, value: String, modifier: Modifier = Modifier, strong: Boolean = false) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = if (strong) FontWeight.Bold else FontWeight.Medium)
    }
}

fun SheetError.textRes(): Int = when (this) {
    SheetError.DATE_PAST -> R.string.a_err_date_past
    SheetError.DATE_TOO_FAR -> R.string.a_err_date_too_far
    SheetError.DATE_UNCHANGED -> R.string.a_err_date_same
    SheetError.FEE_REQUIRED -> R.string.a_err_fee_required
    SheetError.FEE_INVALID -> R.string.a_err_fee_range
    SheetError.FEE_UNCHANGED -> R.string.a_err_fee_same
    SheetError.FEE_NOT_ALLOWED -> R.string.a_err_fee_not_allowed
}
