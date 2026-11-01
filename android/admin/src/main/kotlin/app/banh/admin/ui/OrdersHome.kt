package app.banh.admin.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.material3.BadgedBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.account.AccountViewModel
import app.banh.admin.auth.SessionState
import app.banh.admin.orderlist.OrderListViewModel
import app.banh.admin.ui.account.AccountSheet
import app.banh.admin.ui.account.SettingsPlaceholder
import app.banh.admin.ui.orders.OrderListScreen
import app.banh.core.common.badgeText
import app.banh.core.design.BanhScreen
import app.banh.core.design.CountBadge
import app.banh.core.model.Role

/**
 * S-A3 for both roles. Staff see the list alone with the account button in the header (S-A13 sheet); the owner has two tabs, Orders
 * (with the red number) and Settings (a placeholder holding the sign-out buttons until the settings slices exist).
 */
@Composable
fun OrdersHome(container: AdminContainer, signedIn: SessionState.SignedIn, onOpenOrder: (String) -> Unit) {
    val listModel = viewModel<OrderListViewModel>(factory = viewModelFactory { initializer { OrderListViewModel(container.orders, container.orderChanges, container.serverDate) } })
    val accountModel = viewModel<AccountViewModel>(factory = viewModelFactory { initializer { AccountViewModel(container.session) } })
    val list by listModel.state.collectAsStateWithLifecycle()
    val account by accountModel.state.collectAsStateWithLifecycle()
    var showAccount by rememberSaveable { mutableStateOf(false) }
    var settingsTab by rememberSaveable { mutableStateOf(false) }
    val isOwner = signedIn.account.role == Role.OWNER

    SecureWindow()
    BanhScreen(bottomBar = { if (isOwner) TabBar(settingsTab, list.unfinishedCount) { settingsTab = it } }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            if (isOwner && settingsTab) {
                SettingsPlaceholder(signedIn.account, signedIn.email, account, accountModel::dispatch)
            } else {
                OrderListScreen(list, listModel::dispatch, onOpenOrder, staffControls = !isOwner, onAccount = { showAccount = true })
            }
        }
    }
    if (showAccount && !isOwner) {
        AccountSheet(signedIn.account, signedIn.email, account, accountModel::dispatch, onClose = { showAccount = false })
    }
}

@Composable
private fun TabBar(settingsSelected: Boolean, unfinished: Int, onSelect: (Boolean) -> Unit) {
    NavigationBar {
        NavigationBarItem(
            selected = !settingsSelected,
            onClick = { onSelect(false) },
            icon = {
                val description = stringResource(R.string.a_tab_badge_a11y, unfinished)
                BadgedBox(
                    badge = { if (unfinished > 0) CountBadge(badgeText(unfinished), Modifier.testTag(AdminTags.TAB_ORDERS_BADGE).semantics { contentDescription = description }) },
                ) { Icon(painterResource(R.drawable.ic_list), contentDescription = null) }
            },
            label = { Text(stringResource(R.string.a_orders_title)) },
            modifier = Modifier.testTag(AdminTags.TAB_ORDERS),
        )
        NavigationBarItem(
            selected = settingsSelected,
            onClick = { onSelect(true) },
            icon = { Icon(painterResource(R.drawable.ic_settings), contentDescription = null) },
            label = { Text(stringResource(R.string.a_settings_title)) },
            modifier = Modifier.testTag(AdminTags.TAB_SETTINGS),
        )
    }
}
