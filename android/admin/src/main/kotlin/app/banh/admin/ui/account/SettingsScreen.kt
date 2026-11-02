package app.banh.admin.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import app.banh.admin.owner.LoadPhase
import app.banh.admin.owner.SettingsState
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.OwnerToastHost
import app.banh.core.design.GlassCard
import app.banh.core.design.InfoMessageView
import app.banh.core.design.Spacing
import app.banh.core.model.Account
import androidx.compose.ui.res.painterResource

private val OwnerTags = AccountTags(
    AdminTags.SETTINGS_SIGN_OUT_OTHERS,
    AdminTags.SETTINGS_SIGN_OUT_OTHERS_YES,
    AdminTags.SETTINGS_SIGN_OUT,
    AdminTags.SETTINGS_SIGN_OUT_YES,
)

/** The five areas of S-A6, in this order. */
enum class OwnerArea { CAKES, RULES, DELIVERY, SHOP, STAFF }

private const val DASH = "–"
private const val PLACEHOLDER = "…"

/** S-A6 (owner, tab 2): five entries with their current values, the "new orders only" note, and the two sign-out buttons (FR-20, AC-48). */
@Composable
fun SettingsScreen(
    settings: SettingsState,
    onToast: () -> Unit,
    onOpen: (OwnerArea) -> Unit,
    account: Account,
    email: String?,
    accountState: AccountState,
    dispatch: (AccountIntent) -> Unit,
) {
    Column(Modifier.statusBarsPadding().verticalScroll(rememberScrollState()).padding(Spacing.screenMargin), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Text(stringResource(R.string.a_settings_title), style = MaterialTheme.typography.headlineMedium, modifier = Modifier.semantics { heading() })
        GlassCard(Modifier.fillMaxWidth()) {
            val values = rowValues(settings)
            SettingsRow(stringResource(R.string.a_row_cakes), values.cakes, AdminTags.SETTINGS_ROW_CAKES, true) { onOpen(OwnerArea.CAKES) }
            SettingsRow(stringResource(R.string.a_row_rules), values.rules, AdminTags.SETTINGS_ROW_RULES, true) { onOpen(OwnerArea.RULES) }
            SettingsRow(stringResource(R.string.a_row_delivery_set), values.delivery, AdminTags.SETTINGS_ROW_DELIVERY, true) { onOpen(OwnerArea.DELIVERY) }
            SettingsRow(stringResource(R.string.a_row_shop), values.shop, AdminTags.SETTINGS_ROW_SHOP, true) { onOpen(OwnerArea.SHOP) }
            SettingsRow(stringResource(R.string.a_row_staff), values.staff, AdminTags.SETTINGS_ROW_STAFF, false) { onOpen(OwnerArea.STAFF) }
        }
        InfoMessageView(stringResource(R.string.a_new_orders_only), painterResource(R.drawable.ic_error))
        AccountCard(account, email, AdminTags.ACCOUNT_NAME, AdminTags.ACCOUNT_EMAIL)
        SignOutButtons(accountState, dispatch, OwnerTags)
    }
    OwnerToastHost(settings.toast, onToast)
}

private class RowValues(val cakes: String, val rules: String, val delivery: String, val shop: String, val staff: String)

@Composable
private fun rowValues(state: SettingsState): RowValues {
    val data = state.settings
    if (data == null) {
        val text = if (state.phase == LoadPhase.LOADING) PLACEHOLDER else DASH
        return RowValues(text, text, text, text, text)
    }
    return RowValues(
        cakes = "${data.cakes.size}/${data.cakeCountMax}",
        rules = stringResource(R.string.a_row_rules_value, data.ordering.dailyLimit),
        delivery = stringResource(R.string.a_row_delivery_value, data.districts.count { it.isActive }, data.slots.count { it.isActive }),
        shop = data.shop.name,
        staff = state.activeStaff?.let { "$it/${data.staffCountMax}" } ?: DASH,
    )
}
