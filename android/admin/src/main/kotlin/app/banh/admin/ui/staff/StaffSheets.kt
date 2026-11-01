package app.banh.admin.ui.staff

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import app.banh.admin.R
import app.banh.admin.staff.AddStaffSheet
import app.banh.admin.staff.StaffBanner
import app.banh.admin.staff.StaffField
import app.banh.admin.staff.StaffIntent
import app.banh.admin.staff.StaffState
import app.banh.admin.staff.StaffToast
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.FormField
import app.banh.core.design.BadgeTone
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.GlassCard
import app.banh.core.design.InfoMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing
import app.banh.core.design.StatusBadge
import app.banh.core.model.StaffAccount

/** The add sheet and the detail sheet of S-A12, and the deactivation dialog. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StaffSheets(state: StaffState, accounts: List<StaffAccount>, dispatch: (StaffIntent) -> Unit) {
    val detail = accounts.firstOrNull { it.accountId == state.detailId }
    if (state.add != null) {
        ModalBottomSheet(onDismissRequest = { dispatch(StaffIntent.Close) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) { AddForm(state.add, dispatch) }
    } else if (detail != null) {
        ModalBottomSheet(onDismissRequest = { dispatch(StaffIntent.Close) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) { Detail(detail, state.busy, state.toast, dispatch) }
    }
    if (state.confirmDeactivate && detail != null) {
        AlertDialog(
            onDismissRequest = { dispatch(StaffIntent.Dismiss) },
            title = { Text(stringResource(R.string.a_deactivate_title, detail.name)) },
            text = { Text(stringResource(R.string.a_deactivate_body, detail.name)) },
            confirmButton = { TextButton(onClick = { dispatch(StaffIntent.SetActive(false)) }, modifier = Modifier.testTag(AdminTags.STAFF_DEACTIVATE_YES)) { Text(stringResource(R.string.a_deactivate), color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { dispatch(StaffIntent.Dismiss) }) { Text(stringResource(R.string.a_back)) } },
        )
    }
}

@Composable
private fun AddForm(sheet: AddStaffSheet, dispatch: (StaffIntent) -> Unit) {
    Column(
        Modifier.fillMaxWidth().imePadding().navigationBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.screenMargin).padding(bottom = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(stringResource(R.string.a_add_staff), style = MaterialTheme.typography.titleLarge)
        FormField(stringResource(R.string.a_f_staff_name), sheet.name, { dispatch(StaffIntent.Name(it)) }, AdminTags.STAFF_ADD_NAME, sheet.problems[StaffField.NAME], AdminTags.staffAddError(StaffField.NAME))
        FormField(stringResource(R.string.a_email_label), sheet.email, { dispatch(StaffIntent.Email(it)) }, AdminTags.STAFF_ADD_EMAIL, sheet.problems[StaffField.EMAIL], AdminTags.staffAddError(StaffField.EMAIL), keyboard = KeyboardType.Email)
        InfoMessageView(stringResource(R.string.a_staff_add_help), painterResource(R.drawable.ic_error))
        val banner = when (sheet.banner) {
            StaffBanner.ERROR -> R.string.a_err_generic
            StaffBanner.OFFLINE -> R.string.a_offline_save
            StaffBanner.FULL -> R.string.a_err_staff_full
            null -> null
        }
        if (banner != null) ErrorMessageView(stringResource(banner), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.staffAddError("banner")))
        PrimaryButton(stringResource(R.string.a_add_staff_save), { dispatch(StaffIntent.SaveAdd) }, Modifier.testTag(AdminTags.STAFF_ADD_SAVE), enabled = sheet.canSave, loading = sheet.saving)
    }
}

@Composable
private fun Detail(account: StaffAccount, busy: Boolean, failure: StaffToast?, dispatch: (StaffIntent) -> Unit) {
    Column(
        Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = Spacing.screenMargin).padding(bottom = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        GlassCard(Modifier.fillMaxWidth()) {
            Text(account.name, style = MaterialTheme.typography.titleMedium)
            SelectionContainer { Text(account.email, style = MaterialTheme.typography.bodyLarge) }
            Text(stringResource(R.string.a_role_staff), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            StatusBadge(stringResource(if (account.isActive) R.string.a_acct_active else R.string.a_acct_off), if (account.isActive) BadgeTone.CONFIRMED else BadgeTone.COMPLETED)
        }
        // A sheet covers the toast layer, so a refusal (the limit of 30, a lost connection) is written inside the sheet.
        val text = when (failure) {
            StaffToast.FULL -> R.string.a_err_staff_full
            StaffToast.ERROR -> R.string.a_err_generic
            StaffToast.OFFLINE -> R.string.a_offline_save
            null -> null
        }
        if (text != null) ErrorMessageView(stringResource(text), painterResource(R.drawable.ic_error), Modifier.testTag("admin.staff.error"))
        if (account.isActive) {
            SecondaryButton(stringResource(R.string.a_deactivate), { dispatch(StaffIntent.AskDeactivate) }, Modifier.testTag(AdminTags.STAFF_DEACTIVATE), enabled = !busy, destructive = true)
        } else {
            PrimaryButton(stringResource(R.string.a_reactivate), { dispatch(StaffIntent.SetActive(true)) }, Modifier.testTag(AdminTags.STAFF_REACTIVATE), enabled = !busy, loading = busy)
        }
    }
}
