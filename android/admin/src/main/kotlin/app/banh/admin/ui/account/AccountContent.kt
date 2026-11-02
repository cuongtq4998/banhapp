package app.banh.admin.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.account.AccountDialog
import app.banh.admin.account.AccountIntent
import app.banh.admin.account.AccountMessage
import app.banh.admin.account.AccountState
import app.banh.admin.ui.AdminToast
import app.banh.core.design.GlassCard
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing
import app.banh.core.model.Account
import app.banh.core.model.Role

/** Tags of the two sign-out buttons and their confirm buttons; the staff sheet (S-A13) and the owner's settings (S-A6) use different ids. */
class AccountTags(val signOutOthers: String, val signOutOthersYes: String, val signOut: String, val signOutYes: String)

/** Name, e-mail when known, role: the person's own data (S-A13). The server sends no e-mail, so it shows only for the sign-in of this run. */
@Composable
fun AccountCard(account: Account, email: String?, nameTag: String, emailTag: String) {
    GlassCard(Modifier.fillMaxWidth()) {
        Text(account.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag(nameTag))
        if (email != null) Text(email, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag(emailTag))
        Text(
            stringResource(if (account.role == Role.OWNER) R.string.a_role_owner else R.string.a_role_staff),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** The two sign-out buttons with their confirm dialogs and the result toast, shared by S-A13 and S-A6 (FR-2, FR-4). */
@Composable
fun SignOutButtons(state: AccountState, dispatch: (AccountIntent) -> Unit, tags: AccountTags) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        SecondaryButton(stringResource(R.string.a_signout_others), { dispatch(AccountIntent.Ask(AccountDialog.SIGN_OUT_OTHERS)) }, Modifier.testTag(tags.signOutOthers), enabled = !state.busy)
        SecondaryButton(stringResource(R.string.a_sign_out), { dispatch(AccountIntent.Ask(AccountDialog.SIGN_OUT)) }, Modifier.testTag(tags.signOut), enabled = !state.busy, destructive = true)
    }
    when (state.dialog) {
        AccountDialog.SIGN_OUT_OTHERS -> Confirm(R.string.a_signout_others_title, R.string.a_signout_others_body, R.string.a_signout_others, tags.signOutOthersYes, dispatch, AccountIntent.SignOutOthersYes)
        AccountDialog.SIGN_OUT -> Confirm(R.string.a_signout_title, R.string.a_signout_body, R.string.a_sign_out, tags.signOutYes, dispatch, AccountIntent.SignOutYes)
        AccountDialog.NONE -> Unit
    }
    val message = when (state.message) {
        AccountMessage.OTHERS_DONE -> R.string.a_signout_others_done
        AccountMessage.FAILED -> R.string.a_err_generic
        AccountMessage.OFFLINE -> R.string.a_offline_save
        AccountMessage.NONE -> null
    }
    AdminToast(message?.let { stringResource(it) }, onShown = { dispatch(AccountIntent.MessageShown) }, haptic = if (state.message == AccountMessage.OTHERS_DONE) HapticFeedbackType.Confirm else HapticFeedbackType.Reject)
}

@Composable
private fun Confirm(title: Int, body: Int, yes: Int, yesTag: String, dispatch: (AccountIntent) -> Unit, accept: AccountIntent) {
    AlertDialog(
        onDismissRequest = { dispatch(AccountIntent.Dismiss) },
        title = { Text(stringResource(title)) },
        text = { Text(stringResource(body)) },
        confirmButton = { TextButton(onClick = { dispatch(accept) }, modifier = Modifier.testTag(yesTag)) { Text(stringResource(yes)) } },
        dismissButton = { TextButton(onClick = { dispatch(AccountIntent.Dismiss) }) { Text(stringResource(R.string.a_back)) } },
    )
}
