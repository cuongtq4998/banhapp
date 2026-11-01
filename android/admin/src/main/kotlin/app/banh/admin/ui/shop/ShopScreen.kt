package app.banh.admin.ui.shop

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.compose.runtime.LaunchedEffect
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.shop.GREETING_MAX
import app.banh.admin.shop.ShopBanner
import app.banh.admin.shop.ShopField
import app.banh.admin.shop.ShopIntent
import app.banh.admin.shop.ShopState
import app.banh.admin.shop.ShopViewModel
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.DiscardDialog
import app.banh.admin.ui.forms.FormField
import app.banh.admin.ui.forms.FormScreen
import app.banh.admin.ui.forms.GatedPage
import app.banh.core.design.GlassCard
import app.banh.core.design.Spacing

/** S-A11 bound to its view model. */
@Composable
fun ShopRoute(container: AdminContainer, store: SettingsViewModel, onBack: () -> Unit) {
    val shared by store.state.collectAsStateWithLifecycle()
    GatedPage(stringResource(R.string.a_row_shop), onBack, shared.phase, store::reload) {
        val viewModel = viewModel<ShopViewModel>(
            key = "shop",
            factory = viewModelFactory { initializer { ShopViewModel(ShopState(checkNotNull(shared.settings).shop), container.owner, store) } },
        )
        val state by viewModel.state.collectAsStateWithLifecycle()
        LaunchedEffect(state.done) { if (state.done) onBack() }
        ShopScreen(state, viewModel::dispatch, onBack)
    }
}

@Composable
fun ShopScreen(state: ShopState, dispatch: (ShopIntent) -> Unit, onBack: () -> Unit) {
    FormScreen(
        title = stringResource(R.string.a_row_shop),
        onBack = { if (state.changed) dispatch(ShopIntent.Back) else onBack() },
        saveLabel = stringResource(R.string.a_save),
        saveTag = AdminTags.SHOP_SAVE,
        canSave = state.canSave,
        saving = state.saving,
        onSave = { dispatch(ShopIntent.Save) },
        message = when (state.banner) {
            ShopBanner.ERROR -> stringResource(R.string.a_err_generic)
            ShopBanner.OFFLINE -> stringResource(R.string.a_offline_save)
            null -> null
        },
    ) {
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                FormField(stringResource(R.string.a_f_shop_name), state.name, { dispatch(ShopIntent.Name(it)) }, AdminTags.SHOP_NAME, state.problems[ShopField.NAME], AdminTags.shopError(ShopField.NAME))
                FormField(stringResource(R.string.a_f_greeting), state.greeting, { dispatch(ShopIntent.Greeting(it)) }, AdminTags.SHOP_GREETING, state.problems[ShopField.GREETING], AdminTags.shopError(ShopField.GREETING), multiline = true, counterMax = GREETING_MAX)
                FormField(stringResource(R.string.a_f_phone), state.phone, { dispatch(ShopIntent.Phone(it)) }, AdminTags.SHOP_PHONE, state.problems[ShopField.PHONE], AdminTags.shopError(ShopField.PHONE), keyboard = KeyboardType.Phone)
                FormField(stringResource(R.string.a_f_zalo), state.zalo, { dispatch(ShopIntent.Zalo(it)) }, AdminTags.SHOP_ZALO, state.problems[ShopField.ZALO], AdminTags.shopError(ShopField.ZALO))
            }
        }
    }
    if (state.discard) DiscardDialog(onDiscard = onBack, onKeep = { dispatch(ShopIntent.Dismiss) })
}
