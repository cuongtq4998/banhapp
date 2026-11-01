package app.banh.admin.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.banh.admin.R
import app.banh.admin.account.AccountIntent
import app.banh.admin.account.AccountState
import app.banh.admin.ui.AdminTags
import app.banh.core.design.Spacing
import app.banh.core.model.Account

private val OwnerTags = AccountTags(
    AdminTags.SETTINGS_SIGN_OUT_OTHERS,
    AdminTags.SETTINGS_SIGN_OUT_OTHERS_YES,
    AdminTags.SETTINGS_SIGN_OUT,
    AdminTags.SETTINGS_SIGN_OUT_YES,
)

/**
 * The owner's second tab. The five settings areas (S-A6 to S-A12) come with later slices; until then the tab holds the account and
 * the two sign-out buttons, so the owner can leave a phone (FR-2, FR-4).
 */
@Composable
fun SettingsPlaceholder(account: Account, email: String?, state: AccountState, dispatch: (AccountIntent) -> Unit) {
    Column(Modifier.statusBarsPadding().padding(Spacing.screenMargin), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Text(stringResource(R.string.a_settings_title), style = MaterialTheme.typography.headlineMedium, modifier = Modifier.semantics { heading() })
        AccountCard(account, email, AdminTags.ACCOUNT_NAME, AdminTags.ACCOUNT_EMAIL)
        SignOutButtons(state, dispatch, OwnerTags)
    }
}
