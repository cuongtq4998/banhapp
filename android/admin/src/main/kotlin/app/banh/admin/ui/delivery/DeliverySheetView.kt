package app.banh.admin.ui.delivery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import app.banh.admin.R
import app.banh.admin.delivery.DeliveryBanner
import app.banh.admin.delivery.DeliveryField
import app.banh.admin.delivery.DeliveryIntent
import app.banh.admin.delivery.DeliverySheet
import app.banh.admin.delivery.SheetKind
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.FormField
import app.banh.admin.ui.forms.problemText
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.InfoMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing

/** The edit sheet of S-A10 for a district or a slot, adding or changing; it closes when the save succeeded. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeliverySheetView(sheet: DeliverySheet, dispatch: (DeliveryIntent) -> Unit) {
    ModalBottomSheet(onDismissRequest = { dispatch(DeliveryIntent.CloseSheet) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(
            Modifier.fillMaxWidth().imePadding().navigationBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.screenMargin).padding(bottom = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            if (sheet.kind == SheetKind.DISTRICT) DistrictFields(sheet, dispatch) else SlotFields(sheet, dispatch)
            when (sheet.banner) {
                DeliveryBanner.ERROR -> ErrorMessageView(stringResource(R.string.a_err_generic), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.DELIVERY_ERROR))
                DeliveryBanner.OFFLINE -> ErrorMessageView(stringResource(R.string.a_offline_save), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.DELIVERY_ERROR))
                null -> Unit
            }
            PrimaryButton(
                stringResource(R.string.a_save),
                { dispatch(DeliveryIntent.SaveSheet) },
                Modifier.testTag(if (sheet.kind == SheetKind.DISTRICT) AdminTags.DISTRICT_SAVE else AdminTags.SLOT_SAVE),
                enabled = sheet.canSave,
                loading = sheet.saving,
            )
        }
    }
}

@Composable
private fun DistrictFields(sheet: DeliverySheet, dispatch: (DeliveryIntent) -> Unit) {
    Text(if (sheet.id == null) stringResource(R.string.a_add_district) else sheet.stored?.first.orEmpty(), style = MaterialTheme.typography.titleLarge)
    FormField(stringResource(R.string.a_f_district), sheet.name, { dispatch(DeliveryIntent.Name(it)) }, AdminTags.DISTRICT_NAME, sheet.problems[DeliveryField.NAME], AdminTags.DISTRICT_NAME_ERROR)
    FormField(stringResource(R.string.a_f_fee), sheet.fee, { dispatch(DeliveryIntent.Fee(it)) }, AdminTags.DISTRICT_FEE, sheet.problems[DeliveryField.FEE], AdminTags.DISTRICT_FEE_ERROR, keyboard = KeyboardType.Number, suffix = "đ")
    InfoMessageView(stringResource(R.string.a_fee_effect), painterResource(R.drawable.ic_error))
}

@Composable
private fun SlotFields(sheet: DeliverySheet, dispatch: (DeliveryIntent) -> Unit) {
    Text(stringResource(if (sheet.id == null) R.string.a_slot_add_title else R.string.a_slot_edit_title), style = MaterialTheme.typography.titleLarge)
    TimeField(stringResource(R.string.a_f_start), sheet.start, AdminTags.SLOT_START) { dispatch(DeliveryIntent.Start(it)) }
    TimeField(stringResource(R.string.a_f_end), sheet.end, AdminTags.SLOT_END) { dispatch(DeliveryIntent.End(it)) }
    sheet.problems[DeliveryField.TIME]?.let { Text(problemText("", it), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(AdminTags.DELIVERY_ERROR)) }
}

/** A time shown as a button that opens the native 24-hour picker (design part 7). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimeField(label: String, value: String, tag: String, onChange: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Text(label, style = MaterialTheme.typography.labelLarge)
        SecondaryButton(value, { open = true }, Modifier.testTag(tag))
    }
    if (open) {
        val state = rememberTimePickerState(value.substringBefore(':').toInt(), value.substringAfter(':').toInt(), is24Hour = true)
        AlertDialog(
            onDismissRequest = { open = false },
            title = { Text(label) },
            text = { TimePicker(state) },
            confirmButton = { TextButton(onClick = { open = false; onChange("%02d:%02d".format(state.hour, state.minute)) }, modifier = Modifier.testTag("$tag.ok")) { Text(stringResource(R.string.a_date_pick_ok)) } },
            dismissButton = { TextButton(onClick = { open = false }) { Text(stringResource(R.string.a_back)) } },
        )
    }
}
