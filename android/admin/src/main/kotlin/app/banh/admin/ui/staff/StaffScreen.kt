package app.banh.admin.ui.staff

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.owner.LoadPhase
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.staff.StaffIntent
import app.banh.admin.staff.StaffViewModel
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.GatedPage
import app.banh.admin.ui.forms.OwnerToastHost
import app.banh.core.design.BackControl
import app.banh.core.design.BadgeTone
import app.banh.core.design.BanhInlineTopBar
import app.banh.core.design.BanhScreen
import app.banh.core.design.GlassCard
import app.banh.core.design.InfoMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.Spacing
import app.banh.core.design.StatusBadge
import app.banh.core.model.Role
import app.banh.core.model.StaffAccount

/** S-A12: the owner first, then staff by name; add button (off at 30); a row opens the detail sheet. */
@Composable
fun StaffRoute(container: AdminContainer, store: SettingsViewModel, onBack: () -> Unit) {
    val shared by store.state.collectAsStateWithLifecycle()
    // The list loads with the settings; when only the staff call failed the list is null and the screen offers a retry.
    val phase = if (shared.phase == LoadPhase.READY && shared.staff == null) LoadPhase.ERROR else shared.phase
    GatedPage(stringResource(R.string.a_row_staff), onBack, phase, store::reload) {
        val model = viewModel<StaffViewModel>(key = "staff", factory = viewModelFactory { initializer { StaffViewModel(container.owner, store) } })
        val state by model.state.collectAsStateWithLifecycle()
        val accounts = checkNotNull(shared.staff)
        val max = checkNotNull(shared.settings).staffCountMax
        val active = checkNotNull(shared.activeStaff)
        val full = active >= max
        BanhScreen(
            topBar = {
                BanhInlineTopBar(
                    title = stringResource(R.string.a_row_staff),
                    back = BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK),
                    onBack = onBack,
                )
            },
        ) { padding ->
            LazyColumn(
                contentPadding = PaddingValues(start = Spacing.screenMargin, end = Spacing.screenMargin, top = padding.calculateTopPadding() + Spacing.sm, bottom = Spacing.xxl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                item { Text(stringResource(R.string.a_staff_count, active), style = MaterialTheme.typography.labelLarge, modifier = Modifier.testTag(AdminTags.STAFF_COUNT)) }
                item { PrimaryButton(stringResource(R.string.a_add_staff), { model.dispatch(StaffIntent.OpenAdd) }, Modifier.testTag(AdminTags.STAFF_ADD), enabled = !full) }
                if (full) item { InfoMessageView(stringResource(R.string.a_staff_full), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.STAFF_FULL)) }
                items(accounts.sortedBy { it.role != Role.OWNER }, key = { it.accountId }) { account ->
                    AccountRow(account) { if (account.role == Role.STAFF) model.dispatch(StaffIntent.OpenDetail(account.accountId)) }
                }
                if (accounts.none { it.role == Role.STAFF }) item { InfoMessageView(stringResource(R.string.a_staff_none), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.STAFF_NONE)) }
            }
        }
        StaffSheets(state, accounts, model::dispatch)
        OwnerToastHost(shared.toast, store::toastShown)
    }
}

@Composable
private fun AccountRow(account: StaffAccount, onClick: () -> Unit) {
    val owner = account.role == Role.OWNER
    GlassCard(onClick = if (owner) null else onClick, modifier = Modifier.fillMaxWidth().testTag(AdminTags.staffRow(account.accountId))) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(account.name, style = MaterialTheme.typography.titleMedium)
            Text(account.email, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(end = Spacing.sm))
            if (owner) StatusBadge(stringResource(R.string.a_role_owner), BadgeTone.NEW)
            else StatusBadge(stringResource(if (account.isActive) R.string.a_acct_active else R.string.a_acct_off), if (account.isActive) BadgeTone.CONFIRMED else BadgeTone.COMPLETED)
        }
    }
}
