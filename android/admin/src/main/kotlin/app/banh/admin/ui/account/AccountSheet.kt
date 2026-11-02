package app.banh.admin.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.account.AccountIntent
import app.banh.admin.account.AccountState
import app.banh.admin.ui.AdminTags
import app.banh.core.design.Spacing
import app.banh.core.model.Account

private val StaffTags = AccountTags(
    AdminTags.ACCOUNT_SIGN_OUT_OTHERS,
    AdminTags.ACCOUNT_SIGN_OUT_OTHERS_YES,
    AdminTags.ACCOUNT_SIGN_OUT,
    AdminTags.ACCOUNT_SIGN_OUT_YES,
)

/** S-A13: the staff member's account sheet (opened from the round button on S-A3). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSheet(account: Account, email: String?, state: AccountState, dispatch: (AccountIntent) -> Unit, onClose: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onClose) {
        Column(
            modifier = Modifier.navigationBarsPadding().padding(horizontal = Spacing.screenMargin).padding(bottom = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(stringResource(R.string.a_account_title), style = MaterialTheme.typography.titleLarge)
            AccountCard(account, email, AdminTags.ACCOUNT_NAME, AdminTags.ACCOUNT_EMAIL)
            SignOutButtons(state, dispatch, StaffTags)
        }
    }
}
